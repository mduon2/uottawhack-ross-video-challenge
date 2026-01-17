module image_rom (
    input  wire        clk_i,
    input  wire [11:0] addr_i, // 0 to 4095
    output reg  [15:0] data_o
);

    // 64x64 = 4096 pixels
    reg [15:0] memory [0:4095];

    initial begin
        // Load your hex file into the memory array
        $readmemh("image_data.hex", memory);
    end

    always @(posedge clk_i) begin
        data_o <= memory[addr_i];
    end

endmodule