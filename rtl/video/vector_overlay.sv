// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Shared static colour-filter compositor. Each profile supplies a synchronous
// row ROM of {valid,right,left} spans and a packed RGB Q8 palette (256 = unity).
// Later spans win. RGB input permits future electronic-colour renderers.
// Both the enabled and bypass paths have identical two-clock latency.
module vector_overlay #(
    parameter integer SPANS = 4,
    parameter SPAN_FILE = "rtl/video/overlays/starcastle_spans.hex",
    parameter [SPANS*27-1:0] GAINS = {SPANS{27'h4020100}}
) (
    input wire clk, reset, enabled,
    input wire [1:0] brightness, strength,
    input wire ce_in, hs_in, vs_in, hblank_in, vblank_in,
    input wire [8:0] x, y,
    input wire [23:0] rgb_in,
    output logic ce_out, hs_out, vs_out, hblank_out, vblank_out,
    output logic [23:0] rgb_out
);
    localparam integer ROW_BITS = SPANS*19;
    logic [ROW_BITS-1:0] rows [0:511];
    initial $readmemh(SPAN_FILE, rows);
    logic [ROW_BITS-1:0] row;
    logic [8:0] px;
    logic [23:0] rgb;
    logic enable_q, ce_q, hs_q, vs_q, hblank_q, vblank_q;
    logic [1:0] strength_q;
    logic [26:0] gains;
    logic [16:0] red_product, green_product, blue_product;
    logic [8:0] brightness_gain;
    logic [16:0] bright_red, bright_green, bright_blue;
    function automatic [8:0] tint_gain(input [8:0] original, input [1:0] amount);
        logic [8:0] loss;
        begin
            loss = 9'd256 - original;
            case (amount)
                2'd1: tint_gain = 9'd256 - (loss - (loss >> 2));
                2'd2: tint_gain = 9'd256 - (loss >> 1);
                2'd3: tint_gain = 9'd256 - (loss >> 2);
                default: tint_gain = original;
            endcase
        end
    endfunction
    always_comb begin
        case (brightness)
            2'd1: brightness_gain = 9'd192;
            2'd2: brightness_gain = 9'd320;
            2'd3: brightness_gain = 9'd384;
            default: brightness_gain = 9'd256;
        endcase
        bright_red = rgb_in[23:16] * brightness_gain;
        bright_green = rgb_in[15:8] * brightness_gain;
        bright_blue = rgb_in[7:0] * brightness_gain;
        gains = {9'd256,9'd256,9'd256};
        for (integer n=0; n<SPANS; n=n+1)
            if (enable_q && row[n*19+18] &&
                px >= row[n*19 +: 9] && px <= row[n*19+9 +: 9])
                gains = GAINS[n*27 +: 27];
        gains = {tint_gain(gains[26:18],strength_q),
                 tint_gain(gains[17:9],strength_q), tint_gain(gains[8:0],strength_q)};
        red_product = rgb[23:16] * gains[26:18];
        green_product = rgb[15:8] * gains[17:9];
        blue_product = rgb[7:0] * gains[8:0];
    end
    // Unconditional synchronous ROM read infers block RAM in Quartus.
    always_ff @(posedge clk) row <= rows[y];
    always_ff @(posedge clk) begin
        if (reset) begin
            px <= 0; rgb <= 0; enable_q <= 0; strength_q <= 0;
            ce_q <= 0; hs_q <= 0; vs_q <= 0; hblank_q <= 1; vblank_q <= 1;
            rgb_out <= 0; ce_out <= 0; hs_out <= 0; vs_out <= 0;
            hblank_out <= 1; vblank_out <= 1;
        end else begin
            px <= x; enable_q <= enabled; strength_q <= strength;
            rgb <= {bright_red[16] ? 8'hff : bright_red[15:8],
                    bright_green[16] ? 8'hff : bright_green[15:8],
                    bright_blue[16] ? 8'hff : bright_blue[15:8]};
            ce_q <= ce_in; hs_q <= hs_in; vs_q <= vs_in;
            hblank_q <= hblank_in; vblank_q <= vblank_in;
            rgb_out <= hblank_q || vblank_q ? 24'd0 :
                       {red_product[15:8],green_product[15:8],blue_product[15:8]};
            ce_out <= ce_q; hs_out <= hs_q; vs_out <= vs_q;
            hblank_out <= hblank_q; vblank_out <= vblank_q;
        end
    end
endmodule
