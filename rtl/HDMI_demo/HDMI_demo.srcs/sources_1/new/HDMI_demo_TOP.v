// ============================================================================
// HDMI Text Mode - Stage 2 Test Top
// ============================================================================
//
// 목표: VRAM에 초기화된 텍스트를 HDMI 모니터에 표시한다.
//       CPU 연결 없이, $readmemh로 미리 채운 문자열이 화면에 보이면 성공.
//
// 모듈 구성:
//   PLL (clk_wiz_0)  →  pixel_clk (25MHz) + serial_clk (125MHz)
//   VGA_Timing_Generator  →  hcount, vcount, hsync, vsync, video_active
//   Text_VRAM (Port B)    →  char_code (읽기 전용, 디스플레이 도메인)
//   Font_ROM              →  glyph bitmap byte
//   Text_Renderer         →  pipeline: 좌표 → 문자 → 글리프 → RGB
//   rgb2dvi_0             →  RGB parallel → TMDS serial → HDMI
//
// RGB 채널 순서:
//   Stage 1에서 확인: rgb2dvi는 {R, B, G} 순서를 기대한다.
//   Text_Renderer가 표준 {R, G, B}를 출력하므로 연결 시 스왑한다.
//
// ============================================================================

module HDMI_Test_Top (
    input  wire       sys_clk,          // 100 MHz (R4)
    input  wire       reset_n,          // Active-low (G4)

    // HDMI TX
    output wire [2:0] hdmi_tx_p,
    output wire [2:0] hdmi_tx_n,
    output wire       hdmi_tx_clk_p,
    output wire       hdmi_tx_clk_n
);

    wire reset = ~reset_n;

    // ========================================================================
    // Clocks: 100 MHz → 25 MHz (pixel) + 125 MHz (serial)
    // ========================================================================

    wire pixel_clk;
    wire serial_clk;
    wire pll_locked;

    clk_wiz_0 pll_inst (
        .clk_in1  (sys_clk),
        .clk_out1 (pixel_clk),
        .clk_out2 (serial_clk),
        .reset    (reset),
        .locked   (pll_locked)
    );

    // ========================================================================
    // Reset synchronizer (pixel_clk domain)
    // ========================================================================

    reg [2:0] reset_sync;
    wire pixel_reset = reset_sync[2];

    always @(posedge pixel_clk or negedge pll_locked) begin
        if (!pll_locked) begin
            reset_sync <= 3'b111;
        end else begin
            reset_sync <= {reset_sync[1:0], 1'b0};
        end
    end

    // ========================================================================
    // VGA Timing Generator
    // ========================================================================

    wire [10:0] hcount;
    wire [9:0]  vcount;
    wire        hsync, vsync, video_active;

    VGA_Timing_Generator vga_timing (
        .pixel_clk    (pixel_clk),
        .reset        (pixel_reset),
        .hcount       (hcount),
        .vcount       (vcount),
        .hsync        (hsync),
        .vsync        (vsync),
        .video_active (video_active)
    );

    // ========================================================================
    // Text VRAM (dual-port)
    // ========================================================================
    // Stage 2: Port A 미사용 (CPU 연결 없음). 초기값만 표시.
    // Port B: Text Renderer가 pixel_clk 도메인에서 읽음.

    wire [11:0] vram_addr;
    wire [7:0]  vram_data;

    Text_VRAM text_vram (
        // Port A: unused in Stage 2
        .clk_a   (sys_clk),
        .we_a    (1'b0),
        .addr_a  (12'd0),
        .din_a   (8'd0),
        .dout_a  (),            // unconnected

        // Port B: display read
        .clk_b   (pixel_clk),
        .addr_b  (vram_addr),
        .dout_b  (vram_data)
    );

    // ========================================================================
    // Font ROM
    // ========================================================================

    wire [11:0] font_addr;
    wire [7:0]  font_data;

    Font_ROM font_rom (
        .clk  (pixel_clk),
        .addr (font_addr),
        .data (font_data)
    );

    // ========================================================================
    // Text Renderer (2-stage pipeline)
    // ========================================================================

    wire [23:0] rgb_rendered;
    wire        hsync_rendered;
    wire        vsync_rendered;
    wire        active_rendered;

    Text_Renderer text_renderer (
        .pixel_clk       (pixel_clk),
        .reset           (pixel_reset),

        .hcount          (hcount),
        .vcount          (vcount),
        .hsync_in        (hsync),
        .vsync_in        (vsync),
        .video_active_in (video_active),

        .vram_addr       (vram_addr),
        .vram_data       (vram_data),
        .font_addr       (font_addr),
        .font_data       (font_data),

        .rgb_out         (rgb_rendered),
        .hsync_out       (hsync_rendered),
        .vsync_out       (vsync_rendered),
        .video_active_out(active_rendered)
    );

    // ========================================================================
    // RGB channel swap: renderer outputs {R,G,B}, rgb2dvi expects {R,B,G}
    // ========================================================================
    // Stage 1에서 실험으로 확인된 채널 매핑.

    wire [7:0] r_out = rgb_rendered[23:16];
    wire [7:0] g_out = rgb_rendered[15:8];
    wire [7:0] b_out = rgb_rendered[7:0];

    wire [23:0] rgb_swapped = {r_out, b_out, g_out};  // {R, B, G} for rgb2dvi

    // ========================================================================
    // rgb2dvi: parallel RGB → TMDS serial → HDMI
    // ========================================================================

    rgb2dvi_0 hdmi_encoder (
        .TMDS_Clk_p   (hdmi_tx_clk_p),
        .TMDS_Clk_n   (hdmi_tx_clk_n),
        .TMDS_Data_p  (hdmi_tx_p),
        .TMDS_Data_n  (hdmi_tx_n),

        .vid_pData    (rgb_swapped),
        .vid_pHSync   (hsync_rendered),
        .vid_pVSync   (vsync_rendered),
        .vid_pVDE     (active_rendered),

        .PixelClk     (pixel_clk),
        .SerialClk    (serial_clk),

        .aRst         (pixel_reset)
    );

endmodule