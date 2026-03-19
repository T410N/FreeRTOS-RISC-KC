// ============================================================================
// MMIO Interface - UART + VRAM + Keyboard
// ============================================================================
//
// Memory Map:
//   0x1001_0000       UART TX Data     (Write-Only)
//   0x1001_0004       UART Status      (Read-Only, CPU 내부 처리)
//   0x1002_0000~095F  Text VRAM        (Write-Only)
//   0x1002_0960       Cursor Position  (Write-Only)
//   0x1003_0000       Keyboard Data    (Read-Only, CPU 내부 처리)
//   0x1003_0004       Keyboard Status  (Read: CPU 내부, Write: ACK)
//
// 읽기(load) 경로는 CPU 내부에서 직접 처리한다 (파이프라인 타이밍 때문).
// 이 모듈은 쓰기(store) 디코딩만 담당한다.
//
// ============================================================================

module MMIOInterface #(
    parameter XLEN = 32
)(
    input clk,
    input clk_enable,
    input reset,
    input [XLEN-1:0] data_memory_write_data,
    input [XLEN-1:0] data_memory_address,
    input data_memory_write_enable,
    input UART_busy,

    // UART outputs
    output reg [7:0] mmio_uart_tx_data,
    output [XLEN-1:0] mmio_uart_status,
    output reg mmio_uart_tx_start,
    output mmio_uart_status_hit,
    
    output reg clint_we,
    output reg [3:0] clint_addr,
    output reg [XLEN-1:0] clint_wdata,

    // VRAM outputs
    output reg        vram_we,
    output reg [11:0] vram_addr,
    output reg [7:0]  vram_wdata,

    // Cursor outputs
    output reg [6:0]  cursor_col,
    output reg [4:0]  cursor_row,

    // Keyboard ACK output (pulses when CPU writes to 0x1003_0004)
    output reg        kb_ack
);

    // ========================================================================
    // Address Decoding
    // ========================================================================

    localparam UART_TX_ADDR     = 32'h1001_0000;
    localparam UART_STATUS_ADDR = 32'h1001_0004;
    localparam VRAM_BASE_ADDR   = 32'h1002_0000;
    localparam VRAM_END_ADDR    = 32'h1002_095F;
    localparam CURSOR_ADDR      = 32'h1002_0960;
    localparam KB_STATUS_ADDR   = 32'h1003_0004;
    localparam CLINT_BASE_ADDR  = 32'h0200_0000;
    localparam CLINT_END_ADDR   = 32'h0200_000F;
    
    wire clint_hit = (data_memory_address >= CLINT_BASE_ADDR) && (data_memory_address <= CLINT_END_ADDR);
    wire uart_tx_hit   = (data_memory_address == UART_TX_ADDR);
    wire uart_stat_hit = (data_memory_address == UART_STATUS_ADDR);
    assign mmio_uart_status_hit = uart_tx_hit || uart_stat_hit;
    assign mmio_uart_status = uart_stat_hit ? {{(XLEN-1){1'b0}}, UART_busy} : 32'h0;

    wire vram_hit   = (data_memory_address >= VRAM_BASE_ADDR) &&
                      (data_memory_address <= VRAM_END_ADDR);
    wire cursor_hit = (data_memory_address == CURSOR_ADDR);
    wire kb_ack_hit = (data_memory_address == KB_STATUS_ADDR);

    // ========================================================================
    // UART Write Logic
    // ========================================================================

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mmio_uart_tx_data  <= 8'h0;
            mmio_uart_tx_start <= 1'b0;
        end else begin
            mmio_uart_tx_start <= 1'b0;
            if (clk_enable && data_memory_write_enable && uart_tx_hit && !UART_busy) begin
                mmio_uart_tx_data  <= data_memory_write_data[7:0];
                mmio_uart_tx_start <= 1'b1;
            end else begin
                mmio_uart_tx_data  <= 8'b0;
                mmio_uart_tx_start <= 1'b0;
            end
        end
    end
    
    always @ (posedge clk or posedge reset) begin
        if (reset) begin
            clint_we <= 1'b0;
        end 
        else begin
        clint_we <= 1'b0;
        if (clk_enable && data_memory_write_enable && clint_hit) begin
            clint_we <= 1'b1;
            clint_addr <= data_memory_address[3:0];
            clint_wdata <= data_memory_write_data;
            end
        end
    end

    // ========================================================================
    // VRAM Write Logic
    // ========================================================================

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            vram_we    <= 1'b0;
            vram_addr  <= 12'd0;
            vram_wdata <= 8'd0;
        end else begin
            vram_we <= 1'b0;
            if (clk_enable && data_memory_write_enable && vram_hit) begin
                vram_we    <= 1'b1;
                vram_addr  <= data_memory_address[11:0];
                vram_wdata <= data_memory_write_data[7:0];
            end
        end
    end

    // ========================================================================
    // Cursor Register
    // ========================================================================

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            cursor_col <= 7'd0;
            cursor_row <= 5'd0;
        end else begin
            if (clk_enable && data_memory_write_enable && cursor_hit) begin
                cursor_col <= data_memory_write_data[6:0];
                cursor_row <= data_memory_write_data[12:8];
            end
        end
    end

    // ========================================================================
    // Keyboard ACK (write to 0x1003_0004 clears data_available)
    // ========================================================================

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            kb_ack <= 1'b0;
        end else begin
            kb_ack <= 1'b0;
            if (clk_enable && data_memory_write_enable && kb_ack_hit) begin
                kb_ack <= 1'b1;
            end
        end
    end

endmodule