// ============================================================================
// VGA Timing Generator — 640×480 @ 60Hz
// ============================================================================
module VGA_Timing_Generator (
    input  wire        pixel_clk,      // 25 MHz pixel clock (from PLL)
    input  wire        reset,          // Active-high synchronous reset

    output reg  [10:0] hcount,         // Horizontal pixel counter (0~799)
    output reg  [9:0]  vcount,         // Vertical   line  counter (0~524)
    output wire        hsync,          // Horizontal sync (active-low)
    output wire        vsync,          // Vertical   sync (active-low)
    output wire        video_active    // 1 = inside visible 640×480 area
);

    // ========================================================================
    // Timing parameters (VESA standard for 640×480 @ 60Hz)
    // ========================================================================

    // Horizontal timing (in pixel clocks)
    localparam H_ACTIVE      = 640;    // Visible pixels per line
    localparam H_FRONT_PORCH = 16;     // After active, before sync
    localparam H_SYNC_PULSE  = 96;     // Sync pulse width
    localparam H_BACK_PORCH  = 48;     // After sync, before next active
    localparam H_TOTAL       = 800;    // = 640 + 16 + 96 + 48

    // Vertical timing (in lines)
    localparam V_ACTIVE      = 480;    // Visible lines per frame
    localparam V_FRONT_PORCH = 10;     // After active, before sync
    localparam V_SYNC_PULSE  = 2;      // Sync pulse width
    localparam V_BACK_PORCH  = 33;     // After sync, before next active
    localparam V_TOTAL       = 525;    // = 480 + 10 + 2 + 33

    // Sync pulse boundaries (where sync goes low)
    localparam H_SYNC_START  = H_ACTIVE + H_FRONT_PORCH;           // 656
    localparam H_SYNC_END    = H_ACTIVE + H_FRONT_PORCH + H_SYNC_PULSE; // 752
    localparam V_SYNC_START  = V_ACTIVE + V_FRONT_PORCH;           // 490
    localparam V_SYNC_END    = V_ACTIVE + V_FRONT_PORCH + V_SYNC_PULSE; // 492

    // ========================================================================
    // Horizontal counter: 0 -> 799 -> 0 -> 799 -> ...
    // ========================================================================
    wire h_end = (hcount == H_TOTAL - 1);  // hcount == 799

    always @(posedge pixel_clk) begin
        if (reset) begin
            hcount <= 11'd0;
        end else begin
            if (h_end)
                hcount <= 11'd0;
            else
                hcount <= hcount + 11'd1;
        end
    end

    // ========================================================================
    // Vertical counter: hcount가 한 줄 끝날 때마다 +1
    // ========================================================================
    wire v_end = (vcount == V_TOTAL - 1);  // vcount == 524

    always @(posedge pixel_clk) begin
        if (reset) begin
            vcount <= 10'd0;
        end else if (h_end) begin
            if (v_end)
                vcount <= 10'd0;
            else
                vcount <= vcount + 10'd1;
        end
    end

    // ========================================================================
    // Output signals (combinational)
    // ========================================================================

    // Sync signals: active-low (0 during sync pulse)
    // 640×480 표준은 hsync, vsync 모두 negative polarity
    assign hsync = ~((hcount >= H_SYNC_START) && (hcount < H_SYNC_END));
    assign vsync = ~((vcount >= V_SYNC_START) && (vcount < V_SYNC_END));

    // Video active: 실제 화면 영역 (0,0) ~ (639,479) 에서만 1
    assign video_active = (hcount < H_ACTIVE) && (vcount < V_ACTIVE);

endmodule