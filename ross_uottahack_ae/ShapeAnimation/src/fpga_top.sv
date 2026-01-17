module fpga_top (
    input  wire       XTAL_IN,      // 27 MHz onboard oscillator
    input  wire       nRST,         
    
    //RGB Screen Interface
    output wire       LCD_CLK,
    output wire       LCD_HYNC,
    output wire       LCD_SYNC,     // VSYNC
    output wire       LCD_DEN,      // Data Enable
    output wire [4:0] LCD_R,
    output wire [5:0] LCD_G,
    output wire [4:0] LCD_B,
    output wire LCD_BL
);

    // Clock Generation
    wire clk_pix; 
    
    Gowin_rPLL pll_inst (
        .clkout(clk_pix), 
        .clkin(XTAL_IN)
    );

    wire cen_vid;
    assign cen_vid = 1;

    //Timing Generator
    wire [23:0] vid_rgb_src;
    wire [1:0]  vh_blank_src;
    wire [2:0]  dvh_sync_src;

    video_driver #(.H_RES(800), .V_RES(480)) driver_inst (
        .clk_i      (clk_pix),
        .rst_n_i    (nRST),
        .vid_rgb_o  (vid_rgb_src),  
        .dvh_sync_o (dvh_sync_src), 
        .vh_blank_o (vh_blank_src)
    );

    //The Bouncing Square Logic
    wire [23:0] vid_rgb_out;
    wire [2:0]  dvh_sync_out;

    video_uut uut_inst (
        .clk_i      (clk_pix),
        .cen_i      (cen_vid),
        .rst_i      (1'b0),        // video_uut uses active high reset
        .vid_sel_i  (1'b1),            
        .vid_rgb_i  (vid_rgb_src),
        .vh_blank_i (vh_blank_src),
        .dvh_sync_i (dvh_sync_src),
        .dvh_sync_o (dvh_sync_out),
        .vid_rgb_o  (vid_rgb_out)
    );

    //Output Mapping
    assign LCD_CLK  = clk_pix;
    assign LCD_HYNC = dvh_sync_out[0]; 
    assign LCD_SYNC = dvh_sync_out[1]; 
    assign LCD_DEN  = dvh_sync_out[2]; 

    assign LCD_R = vid_rgb_out[23:19]; 
    assign LCD_G = vid_rgb_out[15:10]; 
    assign LCD_B = vid_rgb_out[7:3];   

assign LCD_BL = 1'b1;

endmodule