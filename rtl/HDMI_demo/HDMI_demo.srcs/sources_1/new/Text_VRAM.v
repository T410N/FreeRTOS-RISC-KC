// ============================================================================
// Text VRAM - Dual-Port BRAM for 80×30 Character Display
// ============================================================================
//
// 역할:
//   80×30 = 2400 바이트의 문자 코드를 저장.
//   Port A: CPU 쪽 (100MHz 도메인) - MMIO를 통해 문자를 쓴다
//   Port B: 디스플레이 쪽 (25MHz 도메인) - Text Renderer가 읽는다
//
// 두 포트가 독립된 클럭 도메인을 쓸 수 있는 이유:
//   Xilinx BRAM은 하드웨어적으로 True Dual-Port를 지원.
//   각 포트가 자기 클럭으로 동작하며, 같은 주소에 동시 접근하지 않는 한
//   충돌이 발생하지 않는다. (같은 주소 동시 쓰기는 없으므로 안전)
//
// 초기화:
//   $readmemh로 vram_init.mem 파일을 읽어 테스트 문자열을 미리 채운다.
//   Stage 3에서 CPU가 런타임에 덮어쓰게 된다.
//
// ============================================================================

module Text_VRAM (
    // Port A: CPU write/read (system clock domain)
    input  wire        clk_a,
    input  wire        we_a,       // Write enable
    input  wire [11:0] addr_a,     // 0 ~ 2399
    input  wire [7:0]  din_a,      // Write data (ASCII code)
    output reg  [7:0]  dout_a,     // Read data

    // Port B: Display read-only (pixel clock domain)
    input  wire        clk_b,
    input  wire [11:0] addr_b,     // 0 ~ 2399
    output reg  [7:0]  dout_b      // Read data (char code → text renderer)
);

    // 2400 bytes, but BRAM will be allocated as 4096
    // (smallest power-of-2 BRAM that fits)
    (* ram_style = "block" *) reg [7:0] mem [0:2399];

    // Initialize with test text
    initial begin
        $readmemh("./vram_init.mem", mem);
    end

    // Port A: read-first mode (read before write on same address)
    always @(posedge clk_a) begin
        dout_a <= mem[addr_a];
        if (we_a) begin
            mem[addr_a] <= din_a;
        end
    end

    // Port B: read-only
    always @(posedge clk_b) begin
        dout_b <= mem[addr_b];
    end

endmodule