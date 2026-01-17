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

// --- Configuration ---
localparam [11:0] SPRITE_W = 12'd64; 
localparam [11:0] SPRITE_H = 12'd64; 
localparam [11:0] SCREEN_W = 12'd800; 
localparam [11:0] SCREEN_H = 12'd480; 
localparam [11:0] SPEED    = 12'd2;   

// --- Signals ---
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

// Sprite ROM Signals
wire [11:0] rom_addr;
wire [15:0] rom_data; 
reg  [11:0] rom_addr_reg;

// Sync Extraction
wire de_in = dvh_sync_i[2]; 
reg vsync_prev;
wire vsync_start = (!dvh_sync_i[1] && vsync_prev);

// --- Instantiate the Image ROM ---
image_rom my_sprite (
    .clk_i  (clk_i),
    .addr_i (rom_addr_reg),
    .data_o (rom_data)
);

// --- Main Logic ---
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
        
        // 1. Coordinate System
        if (de_in) begin
            pix_x <= pix_x + 12'd1;
        end else begin
            pix_x <= 0; 
            if (pix_x != 0) pix_y <= pix_y + 12'd1;
        end

        // VSync Reset
        vsync_prev <= dvh_sync_i[1];
        if (vsync_start) pix_y <= 0;

        // 2. Physics (Bouncing)
        if (vsync_start) begin
            // X Bounce
            if (vel_x_dir == 0) begin 
                if (box_x >= (SCREEN_W - SPRITE_W - SPEED)) vel_x_dir <= 1;
                else box_x <= box_x + SPEED;
            end else begin            
                if (box_x <= SPEED) vel_x_dir <= 0;
                else box_x <= box_x - SPEED;
            end

            // Y Bounce
            if (vel_y_dir == 0) begin 
                if (box_y >= (SCREEN_H - SPRITE_H - SPEED)) vel_y_dir <= 1;
                else box_y <= box_y + SPEED;
            end else begin            
                if (box_y <= SPEED) vel_y_dir <= 0;
                else box_y <= box_y - SPEED;
            end
        end

        // ROM Address Calculation (Pipelined)
        // We calculate address NOW, data comes out NEXT clock cycle
        if ( (pix_x >= box_x) && (pix_x < box_x + SPRITE_W) &&
             (pix_y >= box_y) && (pix_y < box_y + SPRITE_H) ) begin
             
             // Formula: (Row * Width) + Column
             rom_addr_reg <= (pix_y - box_y) * SPRITE_W + (pix_x - box_x);
        end else begin
             rom_addr_reg <= 0; 
        end

        // Renderer
        // Determine if we are inside the box area (Delayed by 1 cycle to match ROM latency)
        // Check if the PIXEL we requested 1 cycle ago was inside the box.
        
        if (vid_sel_i && de_in &&
            ((pix_x > box_x) && (pix_x <= box_x + SPRITE_W) &&
             (pix_y >= box_y) && (pix_y < box_y + SPRITE_H))
           ) begin
            
            // NOTE: If colors look weird (Blue is Red), swap the bytes:
            // reg [15:0] swapped = {rom_data[7:0], rom_data[15:8]};

            if (rom_data == 16'hFFFF) begin
                // Transparent pixel (White) -> Show Background
                vid_rgb_d1 <= vid_rgb_i;
            end else begin
                // Opaque pixel -> Show Sprite
                // Expand 16-bit RGB565 to 24-bit RGB888
                vid_rgb_d1 <= { 
                    rom_data[15:11], rom_data[15:13], // Red
                    rom_data[10:5],  rom_data[10:9],  // Green
                    rom_data[4:0],   rom_data[4:2]    // Blue
                };
            end
        end else begin
            // Background
            vid_rgb_d1 <= (de_in) ? vid_rgb_i : 24'h000000;
        end

        dvh_sync_d1 <= dvh_sync_i;
    end
end

assign dvh_sync_o  = dvh_sync_d1;
assign vid_rgb_o   = vid_rgb_d1;

endmodule