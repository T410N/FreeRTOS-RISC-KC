// ============================================================================
// RV32IM SoC Top - CPU + UART + HDMI + PS/2 Keyboard
// ============================================================================
//
// Memory Map:
//   0x0000_xxxx  Instruction/Data ROM
//   0x1000_xxxx  Data RAM (64KB)
//   0x1001_0000  UART TX Data        (W)
//   0x1001_0004  UART Status         (R)
//   0x1002_0000  VRAM Base           (W, 2400 bytes)
//   0x1002_0960  Cursor Position     (W)
//   0x1003_0000  Keyboard Data       (R)
//   0x1003_0004  Keyboard Status     (R/W, write=ACK)
//
// Clock Domains:
//   sys_clk    (100 MHz PLL out) - CPU, MMIO, UART, VRAM write, PS/2
//   pixel_clk  (25 MHz PLL out)  - VGA, renderer, VRAM read, Font ROM
//   serial_clk (125 MHz PLL out) - rgb2dvi TMDS
//
// ============================================================================

module RV32IM72F8SPSoCTOP #(
    parameter XLEN = 32
)(
    input clk,                          // 100 MHz raw clock (R4)
    input reset_n,                      // Active-low reset (G4)
    input btn_up,                       // Benchmark start button

    output [7:0] led,                   // LEDs
    output uart_tx_in,                  // UART TX pin

    // HDMI TX
    output wire [2:0] hdmi_tx_p,
    output wire [2:0] hdmi_tx_n,
    output wire       hdmi_tx_clk_p,
    output wire       hdmi_tx_clk_n,

    // PS/2 Keyboard (from PIC24 USB HID→PS/2 bridge)
    input  wire       ps2_clk,          // PS/2 clock (W17)
    input  wire       ps2_data          // PS/2 data  (N13)
);
    wire reset = ~reset_n;

    // ========================================================================
    // Unified PLL: 100 MHz → sys(100) + pixel(25) + serial(125)
    // ========================================================================

    wire sys_clk;
    wire pixel_clk;
    wire serial_clk;
    wire pll_locked;
    
    wire timer_interrupt;
    wire clint_we;
    wire [3:0] clint_addr_w;
    wire [3:0] clint_addr_r;
    wire [XLEN-1:0] clint_wdata;
    wire [XLEN-1:0] clint_rdata;
    assign clint_addr_r = MMIO_data_memory_address[3:0];

    clk_wiz_0 master_pll (
        .clk_in1  (clk),
        .clk_out1 (sys_clk),
        .clk_out2 (pixel_clk),
        .clk_out3 (serial_clk),
        .reset    (reset),
        .locked   (pll_locked)
    );

    // ========================================================================
    // Reset synchronizers
    // ========================================================================

    wire internal_reset;
    reg [2:0] reset_sync;
    assign internal_reset = reset_sync[2];

    always @(posedge sys_clk or negedge pll_locked) begin
        if (!pll_locked)
            reset_sync <= 3'b111;
        else
            reset_sync <= {reset_sync[1:0], 1'b0};
    end

    reg [2:0] pixel_reset_sync;
    wire pixel_reset = pixel_reset_sync[2];

    always @(posedge pixel_clk or negedge pll_locked) begin
        if (!pll_locked)
            pixel_reset_sync <= 3'b111;
        else
            pixel_reset_sync <= {pixel_reset_sync[1:0], 1'b0};
    end

    // ========================================================================
    // CPU Clock Enable
    // ========================================================================

    reg cpu_clk_enable;
    wire benchmark_start;

    always @(posedge sys_clk or posedge internal_reset) begin
        if (internal_reset)
            cpu_clk_enable <= 1'b0;
        else if (benchmark_start)
            cpu_clk_enable <= 1'b1;
    end

    // ========================================================================
    // Signal declarations
    // ========================================================================

    // UART
    wire tx_start, tx_busy;
    wire [7:0] tx_data;

    // CPU ↔ MMIO
    wire [XLEN-1:0] MMIO_data_memory_write_data;
    wire [XLEN-1:0] MMIO_data_memory_address;
    wire MMIO_data_memory_write_enable;

    wire [XLEN-1:0] mmio_uart_status;
    wire mmio_uart_status_hit;
    wire [7:0] mmio_uart_tx_data;
    wire mmio_uart_tx_start;

    // VRAM
    wire        vram_we;
    wire [11:0] vram_addr_cpu;
    wire [7:0]  vram_wdata;
    wire [6:0]  cursor_col;
    wire [4:0]  cursor_row;

    // Keyboard
    wire [31:0] kb_data_reg;
    wire [31:0] kb_status_reg;
    wire        kb_ack;

    // CPU
    wire [31:0] retire_instruction;
    // ============================================================================
    // PS/2 진단용 LED 코드 (SoC Top의 LED 할당 부분만 교체)
    // ============================================================================
    // 기존 assign led[...] 전부 삭제하고 이걸로 대체할 것.
    //
    // LED 의미:
    //   LED[0] = CPU running (OFF = running)
    //   LED[1] = PS/2 clock ever went LOW (래치, 한번이라도 LOW 되면 영구 ON)
    //   LED[2] = PS/2 data ever went LOW (래치)
    //   LED[3] = PS/2 controller: frame_valid ever fired (래치)
    //   LED[4] = PS/2 controller: data_available (현재 상태, ACK 전까지 유지)
    //   LED[5] = PS/2 controller: is_break
    //   LED[6] = PS/2 edge counter > 0 (PS/2 falling edge가 한번이라도 감지됨)
    //   LED[7] = kb_ack (CPU가 키보드를 읽었는지)
    //
    // 키를 누른 후 결과:
    //   LED[1,2] = OFF  → PS/2 신호가 핀까지 안 옴 (XDC/하드웨어 문제)
    //   LED[1,2] = ON, LED[3] = OFF → 동기화/에지검출은 되나 프레임 파싱 실패
    //   LED[1,2,3,4] = ON → PS/2 수신 성공, CPU 읽기 확인 필요
    // ============================================================================
 
    // --- PS/2 Activity Latch (래치: 한번이라도 LOW가 오면 영구 ON) ---
    reg ps2_clk_ever_low;
    reg ps2_data_ever_low;
 
    always @(posedge sys_clk or posedge internal_reset) begin
        if (internal_reset) begin
            ps2_clk_ever_low  <= 1'b0;
            ps2_data_ever_low <= 1'b0;
        end else begin
            if (!ps2_clk)  ps2_clk_ever_low  <= 1'b1;
            if (!ps2_data) ps2_data_ever_low <= 1'b1;
        end
    end
 
    // --- PS/2 Falling Edge Counter (에지 감지 확인) ---
    // PS2_Keyboard_Controller 내부의 sync를 거치지 않고
    // 직접 동기화 + 에지 검출해서 별도로 카운트
    reg [1:0] dbg_ps2_clk_sync;
    reg       dbg_ps2_clk_prev;
    reg       dbg_ps2_edge_seen;
 
    always @(posedge sys_clk or posedge internal_reset) begin
        if (internal_reset) begin
            dbg_ps2_clk_sync <= 2'b11;
            dbg_ps2_clk_prev <= 1'b1;
            dbg_ps2_edge_seen <= 1'b0;
        end else begin
            dbg_ps2_clk_sync <= {dbg_ps2_clk_sync[0], ps2_clk};
            dbg_ps2_clk_prev <= dbg_ps2_clk_sync[1];
 
            // Falling edge detection (래치)
            if (dbg_ps2_clk_prev && !dbg_ps2_clk_sync[1])
                dbg_ps2_edge_seen <= 1'b1;
        end
    end
 
    // --- PS2 Controller 내부 frame_valid 래치 ---
    // PS2_Keyboard_Controller에 debug 포트를 추가하거나,
    // data_available가 한번이라도 1이 되었는지로 대체
    reg kb_data_ever_available;
    always @(posedge sys_clk or posedge internal_reset) begin
        if (internal_reset)
            kb_data_ever_available <= 1'b0;
        else if (kb_status_reg[0])
            kb_data_ever_available <= 1'b1;
    end
 
    // --- LED Assignment ---
    assign led[0] = ~cpu_clk_enable;
    assign led[1] = ps2_clk_ever_low;          // PS/2 CLK 신호 도달 여부
    assign led[2] = ps2_data_ever_low;          // PS/2 DATA 신호 도달 여부
    assign led[3] = dbg_ps2_edge_seen;          // Falling edge 감지 여부
    assign led[4] = kb_data_ever_available;     // 프레임 파싱 성공 여부 (래치)
    assign led[5] = kb_status_reg[0];           // 현재 data_available
    assign led[6] = kb_status_reg[1];           // 현재 is_break
    assign led[7] = kb_ack;                     // CPU ACK
    
    CLINT #(.XLEN(XLEN)) clint (
        .clk(sys_clk),
        .clk_enable(1'b1),
        .reset(internal_reset),
        .clint_we(clint_we),
        .clint_addr(clint_addr_w),
        .clint_raddr(clint_addr_r),
        .clint_wdata(clint_wdata),
        .clint_rdata(clint_rdata),
        .timer_interrupt(timer_interrupt)
    );
    // ========================================================================
    // UART Controller + TX
    // ========================================================================

    UnifiedUARTController unified_uart_controller (
        .clk(sys_clk),
        .reset(internal_reset),
        .btn_up(btn_up),
        .mmio_tx_data(mmio_uart_tx_data),
        .mmio_tx_start(mmio_uart_tx_start),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .benchmark_start(benchmark_start)
    );

    UARTTX uart_tx (
        .clk(sys_clk),
        .reset(internal_reset),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(uart_tx_in),
        .tx_busy(tx_busy)
    );

    // ========================================================================
    // MMIO Interface (UART + VRAM + Keyboard ACK)
    // ========================================================================

    MMIOInterface #(.XLEN(XLEN)) mmio_interface (
        .clk(sys_clk),
        .clk_enable(cpu_clk_enable),
        .reset(internal_reset),
        .data_memory_write_data(MMIO_data_memory_write_data),
        .data_memory_address(MMIO_data_memory_address),
        .data_memory_write_enable(MMIO_data_memory_write_enable),
        .UART_busy(tx_busy),
        // UART
        .mmio_uart_tx_data(mmio_uart_tx_data),
        .mmio_uart_status(mmio_uart_status),
        .mmio_uart_tx_start(mmio_uart_tx_start),
        .mmio_uart_status_hit(mmio_uart_status_hit),
        
        .clint_we(clint_we),
        .clint_addr(clint_addr_w),
        .clint_wdata(clint_wdata),
        
        // VRAM
        .vram_we(vram_we),
        .vram_addr(vram_addr_cpu),
        .vram_wdata(vram_wdata),
        .cursor_col(cursor_col),
        .cursor_row(cursor_row),
        // Keyboard ACK
        .kb_ack(kb_ack)
    );

    // ========================================================================
    // PS/2 Keyboard Controller
    // ========================================================================

    PS2_Keyboard_Controller keyboard (
        .clk            (sys_clk),
        .reset          (internal_reset),
        .ps2_clk_pin    (ps2_clk),
        .ps2_data_pin   (ps2_data),
        .kb_data_reg    (kb_data_reg),
        .kb_status_reg  (kb_status_reg),
        .kb_ack         (kb_ack)
    );

    // ========================================================================
    // CPU Core (포트 2개 추가: mmio_kb_data, mmio_kb_status)
    // ========================================================================

    RV32IM72F8SP #(.XLEN(XLEN)) rv32im72f_8sp (
        .clk(sys_clk),
        .clk_enable(cpu_clk_enable),
        .reset(internal_reset),
        .UART_busy(tx_busy),

        // Keyboard MMIO read data (신규)
        .mmio_kb_data(kb_data_reg),
        .mmio_kb_status(kb_status_reg),
        .timer_interrupt_pending(timer_interrupt),
        .clint_rdata(clint_rdata),

        .retire_instruction(retire_instruction),
        .MMIO_data_memory_write_data(MMIO_data_memory_write_data),
        .MMIO_data_memory_address(MMIO_data_memory_address),
        .MMIO_data_memory_write_enable(MMIO_data_memory_write_enable)
    );

    // ========================================================================
    //  HDMI TEXT DISPLAY SUBSYSTEM (Stage 2/3에서 검증 완료)
    // ========================================================================

    wire [10:0] hcount;
    wire [9:0]  vcount;
    wire        hsync, vsync, video_active;

    VGA_Timing_Generator vga_timing (
        .pixel_clk(pixel_clk), .reset(pixel_reset),
        .hcount(hcount), .vcount(vcount),
        .hsync(hsync), .vsync(vsync), .video_active(video_active)
    );

    wire [11:0] vram_addr_display;
    wire [7:0]  vram_data_display;

    Text_VRAM text_vram (
        .clk_a(sys_clk), .we_a(vram_we),
        .addr_a(vram_addr_cpu), .din_a(vram_wdata), .dout_a(),
        .clk_b(pixel_clk), .addr_b(vram_addr_display), .dout_b(vram_data_display)
    );

    wire [11:0] font_addr;
    wire [7:0]  font_data;

    Font_ROM font_rom (
        .clk(pixel_clk), .addr(font_addr), .data(font_data)
    );

    wire [23:0] rgb_rendered;
    wire        hsync_rendered, vsync_rendered, active_rendered;

    Text_Renderer text_renderer (
        .pixel_clk(pixel_clk), .reset(pixel_reset),
        .hcount(hcount), .vcount(vcount),
        .hsync_in(hsync), .vsync_in(vsync), .video_active_in(video_active),
        .vram_addr(vram_addr_display), .vram_data(vram_data_display),
        .font_addr(font_addr), .font_data(font_data),
        .rgb_out(rgb_rendered),
        .hsync_out(hsync_rendered), .vsync_out(vsync_rendered),
        .video_active_out(active_rendered)
    );

    wire [7:0] r_out = rgb_rendered[23:16];
    wire [7:0] g_out = rgb_rendered[15:8];
    wire [7:0] b_out = rgb_rendered[7:0];
    wire [23:0] rgb_swapped = {r_out, b_out, g_out};

    rgb2dvi_0 hdmi_encoder (
        .TMDS_Clk_p(hdmi_tx_clk_p), .TMDS_Clk_n(hdmi_tx_clk_n),
        .TMDS_Data_p(hdmi_tx_p), .TMDS_Data_n(hdmi_tx_n),
        .vid_pData(rgb_swapped),
        .vid_pHSync(hsync_rendered), .vid_pVSync(vsync_rendered),
        .vid_pVDE(active_rendered),
        .PixelClk(pixel_clk), .SerialClk(serial_clk),
        .aRst(pixel_reset)
    );

endmodule