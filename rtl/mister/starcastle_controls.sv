// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
module starcastle_controls (
    input wire clk, reset,
    input wire [10:0] ps2_key,
    input wire [31:0] joy0, joy1,
    output wire start1, start2, left, right, thrust, fire, coin
);
    logic key_toggle;
    logic k_start1, k_start2, k_left, k_right, k_thrust, k_fire, k_coin;
    wire [31:0] joy = joy0 | joy1;
    assign start1 = joy0[6] || k_start1;
    assign start2 = joy1[6] || joy[8] || k_start2;
    assign left = joy[1] || k_left;
    assign right = joy[0] || k_right;
    assign thrust = joy[5] || joy[3] || k_thrust;
    assign fire = joy[4] || k_fire;
    assign coin = joy[7] || k_coin;
    always_ff @(posedge clk) begin
        key_toggle <= ps2_key[10];
        if (reset) begin
            k_start1 <= 0; k_start2 <= 0; k_left <= 0; k_right <= 0;
            k_thrust <= 0; k_fire <= 0; k_coin <= 0;
        end else if (key_toggle != ps2_key[10]) begin
            case (ps2_key[8:0])
                9'h016: k_start1 <= ps2_key[9]; // 1
                9'h01e: k_start2 <= ps2_key[9]; // 2
                9'h02e: k_coin <= ps2_key[9];   // 5
                9'h16b: k_left <= ps2_key[9];
                9'h174: k_right <= ps2_key[9];
                9'h175: k_thrust <= ps2_key[9]; // up
                9'h029: k_fire <= ps2_key[9];   // space
                default: ;
            endcase
        end
    end
endmodule
