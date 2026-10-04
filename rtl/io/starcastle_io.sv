// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Controls and DIP values must be synchronous to clk. Controls are active-high;
// dips[5:0] are the electrical switch levels (default 6'h3f), service is active-high.
module starcastle_io (
    input wire clk, reset,
    input wire start1, start2, left, right, thrust, fire, coin, service,
    input wire [5:0] dips,
    input wire [7:0] outputs,
    output wire [23:0] inputs,
    output logic coin_latched
);
    logic last_coin, last_clear;
    wire [15:0] controls = {3'b111,!fire,1'b1,!thrust,1'b1,!right,
                            1'b1,!left,3'b111,!start2,1'b1,!start1};
    // Switch order follows board wiring; port 23 reads the latched coin.
    assign inputs = {!coin_latched,service,dips[1],dips[0],dips[3],dips[4],
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
