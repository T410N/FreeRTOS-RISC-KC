// ============================================================================
// PS/2 Keyboard Controller
// ============================================================================
//
// 구조:
//   USB Keyboard → PIC24 (USB HID→PS/2 변환) → FPGA PS/2 핀 → 이 모듈
//
// PS/2 프로토콜:
//   - PIC24가 ps2_clk (~10-16.7kHz)과 ps2_data를 구동
//   - 11비트 프레임: Start(0) + Data[7:0](LSB first) + Parity(odd) + Stop(1)
//   - 데이터는 ps2_clk의 falling edge에서 샘플링
//   - 키 누름: scan code 전송 (예: 'A' = 0x1C)
//   - 키 뗌:  0xF0 + scan code 전송
//   - 확장 키: 0xE0 + scan code 전송
//
// MMIO 인터페이스:
//   이 모듈은 수신된 scan code를 레지스터에 저장하고,
//   CPU가 폴링으로 읽어갈 수 있게 한다.
//
//   0x1003_0000 (R):  scan_code[7:0] - 마지막으로 수신된 scan code
//   0x1003_0004 (R):  {30'b0, is_break, data_available}
//                     bit[0] = data_available (새 scan code 있음)
//                     bit[1] = is_break (0xF0 이후의 release code인 경우 1)
//   0x1003_0004 (W):  아무 값이나 쓰면 data_available 플래그 클리어
//
//   펌웨어 사용 패턴:
//     1. status = load(0x1003_0004)
//     2. if (status & 1) {
//     3.     code = load(0x1003_0000)
//     4.     is_release = (status >> 1) & 1
//     5.     store(0x1003_0004, 0)   // acknowledge, clear flag
//     6.     process(code, is_release)
//     7. }
//
// ============================================================================

module PS2_Keyboard_Controller (
    input  wire        clk,             // System clock (100 MHz)
    input  wire        reset,           // Active-high synchronous reset

    // PS/2 physical pins (directly from FPGA I/O)
    input  wire        ps2_clk_pin,     // PS/2 clock (W17)
    input  wire        ps2_data_pin,    // PS/2 data  (N13)

    // CPU MMIO read interface (active signals, directly muxed in CPU)
    output wire [31:0] kb_data_reg,     // 0x1003_0000: {24'b0, scan_code}
    output wire [31:0] kb_status_reg,   // 0x1003_0004: {30'b0, is_break, data_available}

    // CPU MMIO write interface (to clear data_available flag)
    input  wire        kb_ack           // Pulse when CPU writes to 0x1003_0004
);

    // ========================================================================
    // Stage 1: Input synchronization (metastability guard)
    // ========================================================================
    // PS/2 신호는 외부 비동기 클럭이므로, sys_clk 도메인으로
    // 2단 플립플롭으로 동기화해야 한다.

    reg [2:0] ps2_clk_sync;
    reg [2:0] ps2_data_sync;

    always @(posedge clk) begin
        ps2_clk_sync  <= {ps2_clk_sync[1:0], ps2_clk_pin};
        ps2_data_sync <= {ps2_data_sync[1:0], ps2_data_pin};
    end

    wire ps2_clk_s  = ps2_clk_sync[2];    // Synchronized clock (stable)
    wire ps2_data_s = ps2_data_sync[2];    // Synchronized data (stable)

    // ========================================================================
    // Stage 2: Falling edge detection on PS/2 clock
    // ========================================================================
    // PS/2 데이터는 클럭의 falling edge에서 유효하다.
    // 동기화된 클럭의 이전 값과 현재 값을 비교해서 falling edge를 검출.

    reg ps2_clk_prev;
    wire ps2_falling_edge = ps2_clk_prev & ~ps2_clk_s;

    always @(posedge clk) begin
        ps2_clk_prev <= ps2_clk_s;
    end

    // ========================================================================
    // Stage 3: PS/2 frame deserializer
    // ========================================================================
    // 11비트를 시프트 레지스터로 수신:
    //   bit 0: Start bit (always 0)
    //   bit 1-8: Data (LSB first)
    //   bit 9: Parity (odd)
    //   bit 10: Stop bit (always 1)
    //
    // 카운터가 11이 되면 프레임 완성.

    reg [10:0] shift_reg;
    reg [3:0]  bit_count;       // 0~10
    reg        frame_valid;     // Pulses for 1 clock when valid frame received

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            shift_reg   <= 11'd0;
            bit_count   <= 4'd0;
            frame_valid <= 1'b0;
        end else begin
            frame_valid <= 1'b0;   // default: no pulse

            if (ps2_falling_edge) begin
                // Shift in new bit (MSB position, will shift down)
                shift_reg <= {ps2_data_s, shift_reg[10:1]};
                bit_count <= bit_count + 4'd1;

                if (bit_count == 4'd10) begin
                    // 11 bits received - validate frame
                    bit_count <= 4'd0;

                    // Validation checks:
                    //   shift_reg[0]  = start bit (should be 0)
                    //   shift_reg[9]  = parity bit (odd parity over data)
                    //   shift_reg[10] = stop bit (should be 1)
                    // Data = shift_reg[8:1]

                    // After shifting: bit positions are:
                    // {ps2_data_s, shift_reg[10:1]} but we need the FINAL state.
                    // At bit_count==10, we're shifting in the 11th bit (stop).
                    // The complete frame after this shift:
                    //   new shift_reg = {stop, parity, d7,d6,d5,d4,d3,d2,d1,d0, start}
                    //   stop  = shift_reg would be at [10] after shift
                    //   But let's use a temp variable for clarity.

                    // We'll validate in the next section using frame_data wire
                    frame_valid <= 1'b1;
                end
            end

            // Timeout: PS/2 clock 비활성 상태가 길면 카운터 리셋
            // (불완전한 프레임 방지)
            // PS/2 clock은 ~10kHz = 100μs period. 
            // 11비트 = ~1.1ms. Timeout > 2ms 정도면 안전.
        end
    end

    // ========================================================================
    // Frame data extraction and validation
    // ========================================================================
    // shift_reg after 11 shifts:
    //   [0]   = start bit
    //   [8:1] = data byte (LSB first → already in correct order)
    //   [9]   = parity
    //   [10]  = stop bit

    wire [7:0] frame_data   = shift_reg[8:1];
    wire       frame_start  = shift_reg[0];
    wire       frame_parity = shift_reg[9];
    wire       frame_stop   = shift_reg[10];

    // Odd parity check: data bits + parity bit should have odd number of 1s
    wire parity_ok = ^{frame_data, frame_parity};  // XOR all = 1 if odd count

    wire frame_ok = frame_valid & (frame_start == 1'b0) 
                                & (frame_stop == 1'b1) 
                                & parity_ok;

    // ========================================================================
    // Stage 4: Make/Break tracking
    // ========================================================================
    // PS/2 키보드 scan code 패턴:
    //   키 누름: scan_code                    (예: 0x1C for 'A')
    //   키 뗌:  0xF0 → scan_code             (break prefix)
    //   확장:   0xE0 → scan_code             (extended key)
    //   확장 뗌: 0xE0 → 0xF0 → scan_code
    //
    // 이 모듈은 0xF0을 받으면 다음 코드를 "release"로 표시하고,
    // 0xE0은 extended 플래그로 저장한다.

    reg [7:0] scan_code;
    reg       data_available;
    reg       is_break;         // 1 if this is a key release
    reg       is_extended;      // 1 if 0xE0 prefix received
    reg       got_break_prefix; // 0xF0 was the previous byte

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            scan_code        <= 8'd0;
            data_available   <= 1'b0;
            is_break         <= 1'b0;
            is_extended      <= 1'b0;
            got_break_prefix <= 1'b0;
        end else begin
            // CPU acknowledges - clear the flag
            if (kb_ack) begin
                data_available <= 1'b0;
            end

            // New valid frame received
            if (frame_ok) begin
                if (frame_data == 8'hF0) begin
                    // Break prefix: 다음 코드가 key release
                    got_break_prefix <= 1'b1;
                end else if (frame_data == 8'hE0) begin
                    // Extended prefix: 다음 코드가 extended key
                    is_extended <= 1'b1;
                end else begin
                    // 실제 scan code
                    scan_code      <= frame_data;
                    data_available <= 1'b1;
                    is_break       <= got_break_prefix;

                    // Reset prefixes for next sequence
                    got_break_prefix <= 1'b0;
                    is_extended      <= 1'b0;
                end
            end
        end
    end

    // ========================================================================
    // MMIO Output Registers
    // ========================================================================

    assign kb_data_reg   = {24'b0, scan_code};
    assign kb_status_reg = {29'b0, is_extended, is_break, data_available};

endmodule