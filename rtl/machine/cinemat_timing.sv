// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Exact-average 19.923 MHz / 4 enable from a synchronous system clock.
module cinemat_timing #(
    parameter integer CLOCK_HZ = 50000000,
    parameter integer CPU_HZ = 4980750,
    parameter integer FRAME_CYCLES = 131072
) (
    input wire clk, reset,
    output wire cpu_ce, frame_tick
);
    localparam integer FRAME_BITS = $clog2(FRAME_CYCLES);
    logic [31:0] phase;
    logic [FRAME_BITS-1:0] divider;
    wire [32:0] sum = {1'b0,phase} + 33'(CPU_HZ);
    assign cpu_ce = !reset && sum >= 33'(CLOCK_HZ);
    assign frame_tick = cpu_ce && divider == FRAME_BITS'(FRAME_CYCLES-1);
    always_ff @(posedge clk) begin
        if (reset) begin phase <= 0; divider <= 0; end
        else begin
            if (cpu_ce) begin
                phase <= 32'(sum - 33'(CLOCK_HZ));
                if (frame_tick) divider <= 0;
                else divider <= divider + 1'b1;
            end else phase <= sum[31:0];
        end
    end
endmodule
