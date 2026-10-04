// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
module cinemat_controls (
    input wire clk, reset, game_ripoff,
    input wire [10:0] ps2_key,
    input wire [31:0] joy0, joy1,
    output wire start1, start2, left, right, thrust, fire, coin,
    output wire left2, right2, thrust2, fire2
);
    logic key_toggle;
    logic k_start1, k_start2, k_left, k_right, k_thrust, k_fire, k_coin;
    logic k_left2, k_right2, k_thrust2, k_fire2;
    wire [31:0] joy = joy0 | joy1;
    wire [31:0] player1 = game_ripoff ? joy0 : joy;
    assign left2 = joy1[1] || k_left2;
    assign right2 = joy1[0] || k_right2;
    assign thrust2 = joy1[5] || joy1[3] || k_thrust2;
    assign fire2 = joy1[4] || k_fire2;
    assign start1 = joy0[6] || k_start1;
    assign start2 = joy1[6] || joy[8] || k_start2;
    assign left = player1[1] || k_left;
    assign right = player1[0] || k_right;
    assign thrust = player1[5] || player1[3] || k_thrust;
    assign fire = player1[4] || k_fire;
    assign coin = joy[7] || k_coin;
    always_ff @(posedge clk) begin
        key_toggle <= ps2_key[10];
        if (reset) begin
            k_start1 <= 0; k_start2 <= 0; k_left <= 0; k_right <= 0;
            k_thrust <= 0; k_fire <= 0; k_coin <= 0;
            k_left2 <= 0; k_right2 <= 0; k_thrust2 <= 0; k_fire2 <= 0;
        end else if (key_toggle != ps2_key[10]) begin
            case (ps2_key[8:0])
                9'h016: k_start1 <= ps2_key[9]; // 1
                9'h01e: k_start2 <= ps2_key[9]; // 2
                9'h02e: k_coin <= ps2_key[9];   // 5
                9'h16b: k_left <= ps2_key[9];
                9'h174: k_right <= ps2_key[9];
                9'h175: k_thrust <= ps2_key[9]; // up
                9'h029: k_fire <= ps2_key[9];   // space
                9'h01c: k_left2 <= ps2_key[9]; // A
                9'h023: k_right2 <= ps2_key[9]; // D
                9'h01d: k_thrust2 <= ps2_key[9]; // W
                9'h02b: k_fire2 <= ps2_key[9]; // F
                default: ;
            endcase
        end
    end
endmodule
