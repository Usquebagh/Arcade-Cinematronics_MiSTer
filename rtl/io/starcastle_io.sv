// SPDX-License-Identifier: BSD-3-Clause
module starcastle_io (
    input wire clk, reset,
    input wire start1, start2, left, right, thrust, fire, coin, service,
    input wire [5:0] dips,
    input wire [7:0] outputs,
    output wire [23:0] inputs,
    output wire coin_latched
);
    cinemat_io io (.game_ripoff(1'b0), .left2(1'b0), .right2(1'b0),
                  .thrust2(1'b0), .fire2(1'b0), .*);
endmodule
