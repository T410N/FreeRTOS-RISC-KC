`include "./csr_funct3.vh"

// ============================================================================
// CSR File - Extended for FreeRTOS (Machine-mode Interrupt Support)
// ============================================================================
//
// 변경 사항 (기존 대비):
//   1. mstatus: wire(상수) → reg(R/W). MIE, MPIE, MPP 비트 관리.
//   2. mscratch (0x340): 신규 R/W. Context switch 시 SP 임시 저장.
//   3. mie (0x304): 신규 R/W. MTIE(bit 7) = timer interrupt enable.
//   4. mip (0x344): 신규 Read. MTIP(bit 7) = timer interrupt pending.
//      MTIP는 외부 CLINT 모듈이 구동하고, CSR에서는 읽기만 함.
//
// Trap 진입 시 mstatus 동작 (하드웨어 자동):
//   MPIE ← MIE     (현재 인터럽트 상태를 백업)
//   MIE  ← 0       (인터럽트 비활성화)
//   MPP  ← 11      (Machine mode)
//
// MRET 시 mstatus 동작 (하드웨어 자동):
//   MIE  ← MPIE    (인터럽트 상태 복원)
//   MPIE ← 1
//   MPP  ← 11
//
// ============================================================================

module CSRFile #(
    parameter XLEN = 32
)(
    input clk,
    input clk_enable,
    input reset,
    input trapped,
    input mret_executed,                  // 신규: MRET 명령 실행 시 펄스
    input timer_interrupt_pending,        // 신규: CLINT에서 오는 MTIP 신호
    input csr_write_enable,
    input [11:0] csr_read_address,
    input [11:0] csr_write_address,
    input [XLEN-1:0] csr_write_data,
    input instruction_retired,
    input valid_csr_address,

    output reg [XLEN-1:0] csr_read_out,
    output reg csr_ready,

    // 신규: interrupt enable status (Exception Detector가 참조)
    output wire mstatus_mie,              // Global interrupt enable
    output wire mie_mtie                  // Timer interrupt enable
);
    wire [XLEN-1:0] mvendorid = 32'h52_56_4B_43;    // "RVKC"
    wire [XLEN-1:0] marchid   = 32'h34_36_53_35;    // "46S5"
    wire [XLEN-1:0] mimpid    = 32'h34_36_49_31;    // "46I1"
    wire [XLEN-1:0] mhartid   = 32'h52_4B_43_30;    // "RKC0"
    wire [XLEN-1:0] misa      = 32'h40001100;        // RV32I + M

    // ========================================================================
    // mstatus register (변경: wire → reg)
    // ========================================================================
    // Bit layout (M-mode only, relevant bits):
    //   [3]     MIE   - Machine Interrupt Enable (global)
    //   [7]     MPIE  - Previous MIE value (saved on trap entry)
    //   [12:11] MPP   - Previous privilege mode (always 11 = Machine)
    //
    // 나머지 비트는 0으로 고정 (S/U mode 미구현).

    reg        mstatus_MIE_reg;
    reg        mstatus_MPIE_reg;
    wire [1:0] mstatus_MPP = 2'b11;      // Always Machine mode

    wire [XLEN-1:0] mstatus = {19'b0, mstatus_MPP, 3'b0, mstatus_MPIE_reg,
                                 3'b0, mstatus_MIE_reg, 3'b0};

    assign mstatus_mie = mstatus_MIE_reg;

    // ========================================================================
    // mie register (신규)
    // ========================================================================
    // Bit [7] = MTIE (Machine Timer Interrupt Enable)

    reg mie_MTIE_reg;
    wire [XLEN-1:0] mie = {24'b0, mie_MTIE_reg, 7'b0};

    assign mie_mtie = mie_MTIE_reg;

    // ========================================================================
    // mip register (신규, read-only from software)
    // ========================================================================
    // Bit [7] = MTIP (Machine Timer Interrupt Pending)
    // CLINT가 구동하는 외부 신호를 그대로 반영.

    wire [XLEN-1:0] mip = {24'b0, timer_interrupt_pending, 7'b0};

    // ========================================================================
    // mscratch register (신규)
    // ========================================================================
    reg [XLEN-1:0] mscratch;

    // ========================================================================
    // Existing registers (기존 유지)
    // ========================================================================
    reg [XLEN-1:0] mtvec;
    reg [XLEN-1:0] mepc;
    reg [XLEN-1:0] mcause;
    reg [63:0] mcycle;
    reg [63:0] minstret;

    reg csr_processing;
    reg [XLEN-1:0] csr_read_data;

    wire csr_access;
    assign csr_access = valid_csr_address;

    localparam [XLEN-1:0] DEFAULT_mtvec    = 32'h00006D60;
    localparam [XLEN-1:0] DEFAULT_mepc     = {XLEN{1'b0}};
    localparam [XLEN-1:0] DEFAULT_mcause   = {XLEN{1'b0}};
    localparam [XLEN-1:0] DEFAULT_mcycle   = 32'b0;
    localparam [XLEN-1:0] DEFAULT_minstret = 32'b0;

    // ========================================================================
    // Read Operation (확장)
    // ========================================================================
    always @(*) begin
        case (csr_read_address)
            12'hB00: csr_read_data = mcycle[XLEN-1:0];
            12'hB02: csr_read_data = minstret[XLEN-1:0];
            12'hB80: csr_read_data = mcycle[63:32];
            12'hB82: csr_read_data = minstret[63:32];
            12'hF11: csr_read_data = mvendorid;
            12'hF12: csr_read_data = marchid;
            12'hF13: csr_read_data = mimpid;
            12'hF14: csr_read_data = mhartid;
            12'h300: csr_read_data = mstatus;
            12'h301: csr_read_data = misa;
            12'h304: csr_read_data = mie;          // 신규
            12'h305: csr_read_data = mtvec;
            12'h340: csr_read_data = mscratch;     // 신규
            12'h341: csr_read_data = mepc;
            12'h342: csr_read_data = mcause;
            12'h344: csr_read_data = mip;          // 신규
            default: csr_read_data = {XLEN{1'b0}};
        endcase

        if (reset) begin
            csr_ready = 1'b1;
        end
        else begin
            if (csr_access && !csr_processing)
                csr_ready = 1'b0;
            else if (csr_processing)
                csr_ready = 1'b1;
            else
                csr_ready = 1'b1;
        end
    end

    // ========================================================================
    // Write Operation + mstatus Trap Entry/Exit Logic
    // ========================================================================
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            mstatus_MIE_reg  <= 1'b0;     // 부팅 시 인터럽트 비활성화
            mstatus_MPIE_reg <= 1'b0;
            mie_MTIE_reg     <= 1'b0;
            mscratch         <= {XLEN{1'b0}};
            mtvec            <= DEFAULT_mtvec;
            mepc             <= DEFAULT_mepc;
            mcause           <= DEFAULT_mcause;
            mcycle           <= DEFAULT_mcycle;
            minstret         <= DEFAULT_minstret;
            csr_processing   <= 1'b0;
            csr_read_out     <= {XLEN{1'b0}};
        end
        else if (clk_enable) begin
            // Cycle counter (항상 증가)
            mcycle <= mcycle + 1;

            if (instruction_retired)
                minstret <= minstret + 1;

            // CSR access pipeline stall 처리 (기존 로직 유지)
            if (csr_access && !csr_processing) begin
                csr_processing <= 1'b1;
                csr_read_out <= csr_read_data;
            end
            else if (csr_processing) begin
                csr_processing <= 1'b0;
                csr_read_out <= csr_read_data;
            end
            else if (csr_write_enable) begin
                csr_read_out <= csr_read_data;
            end

            // ================================================================
            // mstatus 자동 전환 (Trap Controller가 신호를 보냄)
            // ================================================================
            // Trap 진입 시 (ECALL, Timer IRQ 등):
            //   MPIE ← MIE, MIE ← 0
            // MRET 실행 시:
            //   MIE ← MPIE, MPIE ← 1

            if (trapped && !mret_executed) begin
                // Trap 진입: 인터럽트 비활성화, 이전 상태 백업
                mstatus_MPIE_reg <= mstatus_MIE_reg;
                mstatus_MIE_reg  <= 1'b0;
            end
            else if (mret_executed) begin
                // MRET: 인터럽트 상태 복원
                mstatus_MIE_reg  <= mstatus_MPIE_reg;
                mstatus_MPIE_reg <= 1'b1;
            end

            // ================================================================
            // Software CSR writes (CSRRW, CSRRS, CSRRC)
            // ================================================================
            if ((trapped && csr_write_enable) || csr_write_enable) begin
                case (csr_write_address)
                    12'h300: begin   // mstatus
                        mstatus_MIE_reg  <= csr_write_data[3];
                        mstatus_MPIE_reg <= csr_write_data[7];
                        // MPP는 항상 11 (M-mode only), 쓰기 무시
                    end
                    12'h304: begin   // mie
                        mie_MTIE_reg <= csr_write_data[7];
                    end
                    12'h305: mtvec    <= csr_write_data;
                    12'h340: mscratch <= csr_write_data;   // 신규
                    12'h341: mepc     <= csr_write_data;
                    12'h342: mcause   <= csr_write_data;
                    // 12'h344: mip - read-only, 쓰기 무시
                    default: ;
                endcase
            end
        end
    end

endmodule