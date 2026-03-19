// ============================================================================
// Text Renderer - VRAM + Font ROM → RGB Pixel Pipeline
// ============================================================================
//
// 역할:
//   VGA timing generator의 현재 좌표(hcount, vcount)를 받아서,
//   VRAM에서 문자 코드를 읽고, Font ROM에서 글리프를 읽어,
//   최종 RGB 픽셀 색상을 출력한다.
//
// 파이프라인 구조 (2-stage, BRAM 읽기 지연 보상):
//
//   ┌─────────────────────────────────────────────────────────────────┐
//   │ Clock C: hcount=H 확정                                          │
//   │   → vram_addr = (H/8) + (V/16)*80  [조합 논리]                  │
//   │   → VRAM에 주소 제시 (BRAM이 다음 클럭에 데이터 출력)              │
//   │   → hsync, vsync, active, bit_sel = H[2:0] 저장 (d1 레지스터)    │
//   ├─────────────────────────────────────────────────────────────────┤
//   │ Clock C+1: VRAM 출력 유효 (char_code)                           │
//   │   → font_addr = {char_code, glyph_row}  [조합 논리]              │
//   │   → Font ROM에 주소 제시                                         │
//   │   → d1 레지스터 → d2 레지스터로 전달                              │
//   ├─────────────────────────────────────────────────────────────────┤
//   │ Clock C+2: Font ROM 출력 유효 (glyph_byte)                      │
//   │   → glyph_byte[7 - bit_sel_d2] 로 foreground/background 결정    │
//   │   → RGB 출력 + sync 출력 (d2 레지스터와 정렬)                     │
//   └─────────────────────────────────────────────────────────────────┘
//
//   결과적으로 출력 RGB/sync는 입력 대비 2클럭 지연된다.
//   이는 화면이 2픽셀 오른쪽으로 밀리는 것과 같은데,
//   640×480 해상도에서 2픽셀은 완전히 무시할 수 있는 수준이다.
//
// ============================================================================

module Text_Renderer (
    input  wire        pixel_clk,
    input  wire        reset,

    // VGA timing inputs (from VGA_Timing_Generator)
    input  wire [10:0] hcount,
    input  wire [9:0]  vcount,
    input  wire        hsync_in,
    input  wire        vsync_in,
    input  wire        video_active_in,

    // VRAM read port (Port B of Text_VRAM)
    output wire [11:0] vram_addr,
    input  wire [7:0]  vram_data,       // 1-clock latency after vram_addr

    // Font ROM read port
    output wire [11:0] font_addr,
    input  wire [7:0]  font_data,       // 1-clock latency after font_addr

    // RGB output to rgb2dvi (2-clock delayed, aligned with pipeline)
    output wire [23:0] rgb_out,
    output wire        hsync_out,
    output wire        vsync_out,
    output wire        video_active_out
);

    // ========================================================================
    // Color configuration
    // ========================================================================
    // 클래식 터미널 색상: 흰 글자 + 검정 배경
    // 나중에 MMIO 레지스터로 변경 가능하게 확장할 수 있다.

    localparam [23:0] FG_COLOR = 24'hAAAAAA;  // Light gray (foreground)
    localparam [23:0] BG_COLOR = 24'h000000;  // Black (background)

    // ========================================================================
    // Stage 0: VRAM address computation (combinational)
    // ========================================================================
    // 현재 픽셀 좌표에서 문자 그리드 위치를 계산한다.
    //
    //   char_col = hcount / 8  (0~79)  - 가로 80칸
    //   char_row = vcount / 16 (0~29)  - 세로 30줄
    //
    //   vram_addr = char_row × 80 + char_col
    //
    // 80 = 64 + 16 이므로 곱셈은 시프트+덧셈으로 합성됨.
    // 25MHz에서 타이밍 여유 충분.

    wire [6:0] char_col  = hcount[9:3];     // hcount / 8   (bits [9:3])
    wire [4:0] char_row  = vcount[8:4];     // vcount / 16  (bits [8:4])
    wire [3:0] glyph_row = vcount[3:0];     // vcount % 16  (bits [3:0])
    wire [2:0] bit_sel   = hcount[2:0];     // hcount % 8   (bits [2:0])

    // VRAM 주소: char_row * 80 + char_col
    assign vram_addr = (char_row * 80) + {5'b0, char_col};

    // ========================================================================
    // Pipeline stage 1 registers
    // ========================================================================
    // VRAM 읽기가 1클럭 걸리므로, 동기 신호와 비트 위치를 함께 지연시킨다.

    reg [3:0] glyph_row_d1;
    reg [2:0] bit_sel_d1;
    reg       hsync_d1, vsync_d1, active_d1;

    always @(posedge pixel_clk) begin
        if (reset) begin
            glyph_row_d1 <= 4'd0;
            bit_sel_d1   <= 3'd0;
            hsync_d1     <= 1'b1;
            vsync_d1     <= 1'b1;
            active_d1    <= 1'b0;
        end else begin
            glyph_row_d1 <= glyph_row;
            bit_sel_d1   <= bit_sel;
            hsync_d1     <= hsync_in;
            vsync_d1     <= vsync_in;
            active_d1    <= video_active_in;
        end
    end

    // ========================================================================
    // Stage 1 → Font ROM address (combinational)
    // ========================================================================
    // VRAM 출력(char_code)이 유효해진 시점에서,
    // Font ROM 주소를 조합 논리로 생성한다.
    //
    // font_addr = char_code × 16 + glyph_row
    //           = {char_code[7:0], glyph_row[3:0]}  (단순 비트 연결)

    assign font_addr = {vram_data, glyph_row_d1};

    // ========================================================================
    // Pipeline stage 2 registers
    // ========================================================================

    reg [2:0] bit_sel_d2;
    reg       hsync_d2, vsync_d2, active_d2;

    always @(posedge pixel_clk) begin
        if (reset) begin
            bit_sel_d2 <= 3'd0;
            hsync_d2   <= 1'b1;
            vsync_d2   <= 1'b1;
            active_d2  <= 1'b0;
        end else begin
            bit_sel_d2 <= bit_sel_d1;
            hsync_d2   <= hsync_d1;
            vsync_d2   <= vsync_d1;
            active_d2  <= active_d1;
        end
    end

    // ========================================================================
    // Stage 2 → Pixel output (combinational from Font ROM data)
    // ========================================================================
    // Font ROM 출력(glyph_byte)이 유효해진 시점에서,
    // 비트 위치로 해당 픽셀이 foreground인지 background인지 결정한다.
    //
    // MSB (bit 7) = 왼쪽 픽셀, LSB (bit 0) = 오른쪽 픽셀
    // 따라서 bit_sel=0이면 bit 7, bit_sel=7이면 bit 0

    wire pixel_on = font_data[3'd7 - bit_sel_d2];

    // 최종 RGB 출력:
    //   video_active 구간 + pixel_on → 전경색
    //   video_active 구간 + ~pixel_on → 배경색
    //   blanking 구간 → 검정 (rgb2dvi 요구사항)
    assign rgb_out = active_d2 ? (pixel_on ? FG_COLOR : BG_COLOR)
                               : 24'h000000;

    assign hsync_out        = hsync_d2;
    assign vsync_out        = vsync_d2;
    assign video_active_out = active_d2;

endmodule