module video_driver #(
    parameter H_RES = 800,
    parameter V_RES = 480
)(
    input  wire        clk_i,
    input  wire        rst_n_i,
    output wire [23:0] vid_rgb_o,
    output wire [2:0]  dvh_sync_o, // {DE, VSync, HSync}
    output wire [1:0]  vh_blank_o
);
// Timing Constants for 800x480 @ 60Hz
    localparam H_FP = 40;  localparam H_PW = 48;  localparam H_BP = 40;
    localparam V_FP = 13;  localparam V_PW = 3;   localparam V_BP = 29;
    localparam H_TOTAL = H_RES + H_FP + H_PW + H_BP;
    localparam V_TOTAL = V_RES + V_FP + V_PW + V_BP;

    reg [11:0] h_cnt;
    reg [11:0] v_cnt;

    always @(posedge clk_i or negedge rst_n_i) begin
        if (!rst_n_i) begin
            h_cnt <= 0;
            v_cnt <= 0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 0;
                if (v_cnt == V_TOTAL - 1) v_cnt <= 0;
                else v_cnt <= v_cnt + 12'd1;
            end else begin
                h_cnt <= h_cnt + 12'd1;
            end
        end
    end

    // Sync Signals (Active Low typically for LCD, but we keep positive logic internally)
    // Tang Nano Screen usually expects Active Low Syncs, check datasheet. 
    // Here we generate Active Low for output.
    wire h_sync = (h_cnt >= (H_RES + H_FP)) && (h_cnt < (H_RES + H_FP + H_PW));
    wire v_sync = (v_cnt >= (V_RES + V_FP)) && (v_cnt < (V_RES + V_FP + V_PW));
    
    // Active Video Area
    wire active = (h_cnt < H_RES) && (v_cnt < V_RES);

    // Outputs
    // Note: Tang Nano 9K example uses Active Low Syncs usually.
    assign dvh_sync_o = { active, !v_sync, !h_sync }; 
    assign vh_blank_o = { !active, !active }; // Simplified blanking
    assign vid_rgb_o  = 24'h000000; // Black background source

endmodule