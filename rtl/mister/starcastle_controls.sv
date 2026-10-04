// SPDX-License-Identifier: BSD-3-Clause
module starcastle_controls (
    input wire clk, reset,
    input wire [10:0] ps2_key,
    input wire [31:0] joy0, joy1,
    output wire start1, start2, left, right, thrust, fire, coin
);
    cinemat_controls controls (.game_ripoff(1'b0), .left2(), .right2(), .thrust2(), .fire2(), .*);
endmodule
