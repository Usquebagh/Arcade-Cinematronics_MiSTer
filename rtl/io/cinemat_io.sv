// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Controls and DIP values must be synchronous to clk. Controls are active-high;
// dips[5:0] are electrical levels; service is a logical request. Its electrical
// polarity is active-high for Star Castle and active-low for Rip Off.
module cinemat_io (
    input wire clk, reset,
    input wire game_ripoff, left2, right2, thrust2, fire2,
    input wire start1, start2, left, right, thrust, fire, coin, service,
    input wire [5:0] dips,
    input wire [7:0] outputs,
    output wire [23:0] inputs,
    output logic coin_latched
);
    logic last_coin, last_clear;
    wire [15:0] star_controls = {3'b111,!fire,1'b1,!thrust,1'b1,!right,
                            1'b1,!left,3'b111,!start2,1'b1,!start1};
    wire [15:0] rip_controls = {!thrust,!right,!fire,!left,6'b111111,
                                !fire2,!thrust2,!start2,!right2,!start1,!left2};
    wire [15:0] controls = game_ripoff ? rip_controls : star_controls;
    wire service_level = game_ripoff ? !service : service;
    // Switch order follows board wiring; port 23 reads the latched coin.
    assign inputs = {!coin_latched,service_level,dips[1],dips[0],dips[3],dips[4],
                     dips[5],dips[2],controls};
    always_ff @(posedge clk) begin
        if (reset) begin coin_latched <= 0; last_coin <= 0; last_clear <= 0; end
        else begin
            last_coin <= coin; last_clear <= outputs[5];
            if (outputs[5] && !last_clear) coin_latched <= 0;
            // A new coin wins if it coincides with the acknowledge edge.
            if (coin && !last_coin) coin_latched <= 1;
        end
    end
endmodule
