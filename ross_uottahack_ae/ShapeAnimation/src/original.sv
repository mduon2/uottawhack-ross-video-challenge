module video_uut (
    input  wire         clk_i           ,
    input  wire         cen_i           ,
    input  wire         rst_i           ,
    input  wire         vid_sel_i       ,
    input  wire [23:0]  vid_rgb_i       ,
    input  wire [1:0]   vh_blank_i      ,
    input  wire [2:0]   dvh_sync_i      ,
    output wire [2:0]   dvh_sync_o      ,
    output wire [23:0]  vid_rgb_o        
); 

localparam [11:0] BOX_SIZE = 12'd50;
localparam [11:0] SCREEN_W = 12'd800; 
localparam [11:0] SCREEN_H = 12'd480; 
localparam [11:0] SPEED    = 12'd2;   // Slower speed to see it better
localparam [23:0] BOX_COLOR = 24'h00_FF_00; 

reg [23:0]  vid_rgb_d1;
reg [2:0]   dvh_sync_d1;

// Internal counters
reg [11:0]  pix_x;
reg [11:0]  pix_y;

// Animation State
reg [11:0]  box_x;
reg [11:0]  box_y;
reg         vel_x_dir; 
reg         vel_y_dir; 

// Extract Data Enable (DE)
wire de_in = dvh_sync_i[2]; 
// Detect Vertical Sync Start (Falling edge for Active Low Sync)
reg vsync_prev;
wire vsync_start = (!dvh_sync_i[1] && vsync_prev);

always @(posedge clk_i) begin
    if (rst_i) begin
        box_x <= 12'd100;
        box_y <= 12'd100;
        vel_x_dir <= 0;
        vel_y_dir <= 0;
        pix_x <= 0;
        pix_y <= 0;
    end
    else if(cen_i) begin
        
//         --- 1. Coordinate System Based on Data Enable (DE) ---
//         We only count X and Y when DE is HIGH (Active Video)
        if (de_in) begin
            pix_x <= pix_x + 12'd1;
        end else begin
            pix_x <= 0; // Reset X whenever we are in blanking
//             If we just finished a line (DE went low), increment Y
//             But only if we are not in VSync
            if (pix_x != 0) begin 
                pix_y <= pix_y + 12'd1;
            end
        end

//         Reset Y at the start of a new frame (VSync)
        vsync_prev <= dvh_sync_i[1];
        if (vsync_start) begin
            pix_y <= 0;
        end

//         --- 2. Animation Physics (Update once per frame) ---
        if (vsync_start) begin
//             X Bounce
            if (vel_x_dir == 0) begin 
                if (box_x >= (SCREEN_W - BOX_SIZE - SPEED)) vel_x_dir <= 1;
                else box_x <= box_x + SPEED;
            end else begin            
                if (box_x <= SPEED) vel_x_dir <= 0;
                else box_x <= box_x - SPEED;
            end

//             Y Bounce
            if (vel_y_dir == 0) begin 
                if (box_y >= (SCREEN_H - BOX_SIZE - SPEED)) vel_y_dir <= 1;
                else box_y <= box_y + SPEED;
            end else begin            
                if (box_y <= SPEED) vel_y_dir <= 0;
                else box_y <= box_y - SPEED;
            end
        end

//         --- 3. Renderer (Gate with DE) ---
//         CRITICAL FIX: Only draw if de_in is HIGH
        if (vid_sel_i && de_in &&
            (pix_x >= box_x) && (pix_x < box_x + BOX_SIZE) &&
            (pix_y >= box_y) && (pix_y < box_y + BOX_SIZE)) 
        begin
            vid_rgb_d1 <= BOX_COLOR; 
        end else begin
//             If inside blanking ( !de_in ), we MUST output black
//             otherwise the screen loses sync.
            vid_rgb_d1 <= (de_in) ? vid_rgb_i : 24'h000000; 
        end

        dvh_sync_d1 <= dvh_sync_i;
    end
end

assign dvh_sync_o  = dvh_sync_d1;
assign vid_rgb_o   = vid_rgb_d1;

endmodule