// ============================================================================
// Font ROM - 8×16 CP437-style Character Glyphs
// ============================================================================
//
// 역할:
//   ASCII 코드 + 글리프 행 번호를 받아서 8비트 비트맵 한 줄을 돌려준다.
//   예: 'A'(0x41)의 4번째 행 → font_rom[0x41*16 + 4] → 8'b0110_0110
//
// 구조:
//   256 문자 × 16 행 = 4096 entries, 각 8비트
//   주소 = {char_code[7:0], row[3:0]} = 12비트
//   Vivado가 1개 BRAM (18Kb)으로 추론
//
// 초기화:
//   $readmemh로 font_cp437.mem 파일을 읽는다.
//   gen_font_rom.py 스크립트로 생성.
//
// 타이밍:
//   동기 읽기 (1 clock latency) - addr 제시 후 다음 클럭에 data 유효.
//
// ============================================================================

module Font_ROM (
    input  wire        clk,
    input  wire [11:0] addr,    // {char_code[7:0], glyph_row[3:0]}
    output reg  [7:0]  data     // 8-pixel bitmap (MSB = leftmost pixel)
);

    (* rom_style = "block" *) reg [7:0] rom [0:4095];

    initial begin
        $readmemh("./font_cp437.mem", rom);
    end

    always @(posedge clk) begin
        data <= rom[addr];
    end

endmodule