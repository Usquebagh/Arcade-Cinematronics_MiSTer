// SPDX-License-Identifier: BSD-3-Clause
// Software license applies to this module; artwork provenance is separate.
module armora_artwork(input wire clk,input wire [8:0] x,y,output wire [1:0] ink);
    logic [7:0] memory [0:65535];
    initial $readmemh("rtl/video/overlays/armora_ink.hex",memory);
    logic [7:0] pixels;
    logic [1:0] low_x;
    assign ink=pixels[{low_x,1'b0} +: 2];
    always_ff @(posedge clk)begin pixels<=memory[{y,x[8:2]}];low_x<=x[1:0];end
endmodule
