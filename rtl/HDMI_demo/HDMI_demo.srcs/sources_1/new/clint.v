// ============================================================================
// CLINT - Core Local Interruptor (Machine Timer)
// ============================================================================
//
// 역할:
//   FreeRTOS의 시스템 틱(tick)을 생성하는 하드웨어 타이머.
//
//   mtime:    64-bit free-running counter, 매 클럭마다 +1
//   mtimecmp: 64-bit compare register, 소프트웨어가 설정
//
//   mtime >= mtimecmp 이면 timer_interrupt 신호를 assert.
//   소프트웨어가 mtimecmp를 미래 시점으로 갱신하면 interrupt가 해제됨.
//
// Memory Map (MMIO):
//   0x0200_0000  mtime     low  (R/W)
//   0x0200_0004  mtime     high (R/W)
//   0x0200_0008  mtimecmp  low  (R/W)
//   0x0200_000C  mtimecmp  high (R/W)
//
// FreeRTOS 사용 패턴:
//   1. 부팅 시: mtimecmp = mtime + TICK_INTERVAL (예: 100000 = 1ms @ 100MHz)
//   2. Timer IRQ handler: mtimecmp += TICK_INTERVAL (다음 틱 설정)
//   3. uptime 계산: mtime / clock_frequency = 초
//
// ============================================================================

module CLINT #(
    parameter XLEN = 32
)(
    input  wire        clk,
    input  wire        clk_enable,
    input  wire        reset,

    // MMIO write interface (from MMIO decoder)
    input  wire        clint_we,            // Write enable
    input  wire [3:0]  clint_addr,          // Address offset [3:0] (0x0,0x4,0x8,0xC)
    input  wire [XLEN-1:0] clint_wdata,     // Write data

    // MMIO read interface (directly muxed in CPU)
    output wire [XLEN-1:0] clint_rdata,     // Read data for selected address
    input  wire [3:0]  clint_raddr,         // Read address offset

    // Timer interrupt output
    output wire        timer_interrupt      // 1 when mtime >= mtimecmp
);

    // ========================================================================
    // mtime: 64-bit free-running counter
    // ========================================================================
    // 매 clk_enable 사이클마다 +1.
    // CPU가 100MHz에서 clk_enable = 항상 1이면, 1 tick = 10ns.
    // FreeRTOS tick을 1ms로 하려면 mtimecmp increment = 100,000.

    reg [63:0] mtime;
    reg [63:0] mtimecmp;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mtime <= 64'd0;
        end else if (clk_enable) begin
            mtime <= mtime + 64'd1;

            // Software write to mtime (override counter)
            if (clint_we) begin
                case (clint_addr)
                    4'h0: mtime[31:0]  <= clint_wdata;
                    4'h4: mtime[63:32] <= clint_wdata;
                    default: ;
                endcase
            end
        end
    end

    // ========================================================================
    // mtimecmp: 64-bit compare register
    // ========================================================================
    // 소프트웨어가 이 값을 설정하면, mtime이 이 값 이상이 될 때
    // timer_interrupt가 assert된다.
    // 초기값 = 0xFFFFFFFFFFFFFFFF (부팅 시 interrupt 발생 방지)

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mtimecmp <= 64'hFFFF_FFFF_FFFF_FFFF;
        end else if (clk_enable && clint_we) begin
            case (clint_addr)
                4'h8: mtimecmp[31:0]  <= clint_wdata;
                4'hC: mtimecmp[63:32] <= clint_wdata;
                default: ;
            endcase
        end
    end

    // ========================================================================
    // Timer interrupt generation
    // ========================================================================
    // Unsigned comparison: mtime >= mtimecmp
    // 이 신호는 비동기로 즉시 반응한다.
    // mtimecmp를 미래 값으로 갱신하면 자동으로 deassert.

    assign timer_interrupt = (mtime >= mtimecmp);

    // ========================================================================
    // Read multiplexer
    // ========================================================================

    reg [XLEN-1:0] rdata_mux;

    always @(*) begin
        case (clint_raddr)
            4'h0: rdata_mux = mtime[31:0];
            4'h4: rdata_mux = mtime[63:32];
            4'h8: rdata_mux = mtimecmp[31:0];
            4'hC: rdata_mux = mtimecmp[63:32];
            default: rdata_mux = {XLEN{1'b0}};
        endcase
    end

    assign clint_rdata = rdata_mux;

endmodule