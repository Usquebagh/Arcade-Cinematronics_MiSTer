// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// 25 MHz pixels, 800 x 521 total: 59.981 Hz, 31.25 kHz horizontal.
// Sample the one-clock framebuffer read on alternate system clocks.
module vector_scanout (
    input wire clk, reset,
    input wire [7:0] scan_gray,
    output wire [8:0] scan_x, scan_y,
    output logic [7:0] gray,
    output logic ce_pixel, hs, vs, hblank, vblank
);
    logic phase;
    logic [9:0] h, v;
    assign scan_x = h[8:0];
    assign scan_y = v < 10'd384 ? 9'd383 - v[8:0] : 9'd511;
    always_ff @(posedge clk) begin
        if (reset) begin
            phase <= 0; h <= 0; v <= 0;
            ce_pixel <= 0; gray <= 0; hs <= 0; vs <= 0;
            hblank <= 1; vblank <= 1;
        end else begin
            phase <= !phase;
            ce_pixel <= phase;
            if (phase) begin
                gray <= h < 10'd512 && v < 10'd384 ? scan_gray : 8'd0;
                hs <= h >= 10'd528 && h < 10'd624;
                vs <= v >= 10'd394 && v < 10'd396;
                hblank <= h >= 10'd512;
                vblank <= v >= 10'd384;
                if (h == 10'd799) begin
                    h <= 0;
                    v <= v == 10'd520 ? 10'd0 : v + 10'd1;
                end else h <= h + 10'd1;
            end
        end
    end
endmodule
