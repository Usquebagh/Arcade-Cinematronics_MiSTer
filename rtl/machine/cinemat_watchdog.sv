// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
module cinemat_watchdog (
    input wire clk, reset, frame_tick, clear,
    output logic expired
);
    logic [1:0] frames;
    always_ff @(posedge clk) begin
        expired <= 0;
        if (reset || clear) frames <= 0;
        else if (frame_tick) begin
            if (frames == 2) begin frames <= 0; expired <= 1; end
            else frames <= frames + 2'd1;
        end
    end
endmodule
