// SPDX-License-Identifier: BSD-3-Clause
// CC0 MAME armora.lay transmission tint plus additive playfield reflection.
// Packed two-bit map; ROM, multiplication and saturating-add stages. Every
// profile/bypass shares the same three-clock latency, including sync/blanking.
module armora_overlay (
    input wire clk,reset,enabled,
    input wire [1:0] strength,
    input wire [8:0] x,y,
    input wire [23:0] rgb_in,
    input wire ce_in,hs_in,vs_in,hblank_in,vblank_in,
    output logic [23:0] rgb_out,
    output logic ce_out,hs_out,vs_out,hblank_out,vblank_out
);
    logic [7:0] map [0:65535];
    initial $readmemh("rtl/video/overlays/armora_map.hex",map);
    logic [7:0] pixels;
    logic [1:0] low_x,strength_q;
    logic [23:0] rgb_q,bypass,reflection_q;
    logic enabled_q,enabled_qq;
    logic [4:0] timing_q,timing_qq;
    wire [1:0] code=pixels[{low_x,1'b0} +: 2];
    logic [26:0] tint;
    logic [23:0] reflection;
    logic [16:0] rp,gp,bp;
    function automatic [8:0] gain(input [8:0] v,input [1:0] amount);
        logic [8:0] loss;
        begin
            loss=9'd256-v;
            case(amount)
                1:gain=9'd256-(loss-(loss>>2));
                2:gain=9'd256-(loss>>1);
                3:gain=9'd256-(loss>>2);
                default:gain=v;
            endcase
        end
    endfunction
    function automatic [7:0] background(input [7:0] v,input [1:0] amount);
        case(amount)
            1:background=v-(v>>2);
            2:background=v>>1;
            3:background=v>>2;
            default:background=v;
        endcase
    endfunction
    function automatic [7:0] saturate(input [16:0] product,input [7:0] base);
        logic [9:0] sum;
        begin sum={1'b0,product[16:8]}+{2'b0,base};saturate=sum>255?8'hff:sum[7:0];end
    endfunction
    always_comb begin
        case(code)
            1:begin tint={9'd161,9'd256,9'd193};reflection=24'h17521c;end
            2:begin tint={9'd241,9'd241,9'd137};reflection=24'h959414;end
            default:begin tint=0;reflection=0;end
        endcase
    end
    always_ff @(posedge clk) pixels<=map[{y,x[8:2]}];
    always_ff @(posedge clk) begin
        if(reset) begin
            low_x<=0;strength_q<=0;rgb_q<=0;enabled_q<=0;enabled_qq<=0;
            timing_q<=5'b00011;timing_qq<=5'b00011;
            bypass<=0;reflection_q<=0;rp<=0;gp<=0;bp<=0;
            rgb_out<=0;{ce_out,hs_out,vs_out,hblank_out,vblank_out}<=5'b00011;
        end else begin
            low_x<=x[1:0];strength_q<=strength;rgb_q<=rgb_in;enabled_q<=enabled;
            timing_q<={ce_in,hs_in,vs_in,hblank_in,vblank_in};
            timing_qq<=timing_q;enabled_qq<=enabled_q;bypass<=rgb_q;
            rp<=rgb_q[23:16]*gain(tint[26:18],strength_q);
            gp<=rgb_q[15:8]*gain(tint[17:9],strength_q);
            bp<=rgb_q[7:0]*gain(tint[8:0],strength_q);
            reflection_q<={background(reflection[23:16],strength_q),
                           background(reflection[15:8],strength_q),background(reflection[7:0],strength_q)};
            {ce_out,hs_out,vs_out,hblank_out,vblank_out}<=timing_qq;
            rgb_out<=timing_qq[1] || timing_qq[0] ? 24'd0 : !enabled_qq ? bypass :
                      {saturate(rp,reflection_q[23:16]),saturate(gp,reflection_q[15:8]),saturate(bp,reflection_q[7:0])};
        end
    end
endmodule
