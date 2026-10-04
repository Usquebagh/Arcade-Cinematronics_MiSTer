// SPDX-License-Identifier: GPL-3.0-or-later
module mister_video_harness (
    input wire clk, reset, overlay_enabled,
    input wire [1:0] brightness, strength,
    output wire ce, de, hs, vs,
    output wire [7:0] r, g, b
);
    wire [8:0] sx,sy;
    wire [8:0] px,py;
    logic [7:0] scan_gray;
    wire [7:0] gray;
    wire pixel, hsync, vsync, hblank, vblank;
    wire [21:0] gamma_bus;
    assign gamma_bus[20:0] = {clk,20'd0}; // HPS gamma disabled, clock present.
    always_ff @(posedge clk) scan_gray <= sx[7:0] ^ sy[7:0];
    vector_scanout scanout (
        .clk(clk), .reset(reset), .scan_gray(scan_gray), .scan_x(sx), .scan_y(sy),
        .gray(gray), .ce_pixel(pixel), .hs(hsync), .vs(vsync), .hblank(hblank), .vblank(vblank),
        .pixel_x(px), .pixel_y(py)
    );
    `include "rtl/video/overlays/starcastle_gains.svh"
    wire [23:0] rgb;
    wire colour_ce, colour_hs, colour_vs, colour_hblank, colour_vblank;
    vector_overlay #(.SPANS(STARCASTLE_OVERLAY_SPANS), .GAINS(STARCASTLE_OVERLAY_GAINS)) overlay (
        .clk(clk), .reset(reset), .enabled(overlay_enabled), .x(px), .y(py),
        .brightness(brightness), .strength(strength),
        .rgb_in({gray,gray,gray}), .ce_in(pixel), .hs_in(hsync), .vs_in(vsync),
        .hblank_in(hblank), .vblank_in(vblank), .rgb_out(rgb), .ce_out(colour_ce),
        .hs_out(colour_hs), .vs_out(colour_vs), .hblank_out(colour_hblank), .vblank_out(colour_vblank)
    );
    arcade_video #(512,24,0) video (
        .clk_video(clk), .ce_pix(colour_ce), .RGB_in(rgb),
        .HBlank(colour_hblank), .VBlank(colour_vblank), .HSync(colour_hs), .VSync(colour_vs),
        .CLK_VIDEO(), .CE_PIXEL(ce), .VGA_R(r), .VGA_G(g), .VGA_B(b),
        .VGA_HS(hs), .VGA_VS(vs), .VGA_DE(de), .VGA_SL(),
        .fx(3'd0), .forced_scandoubler(1'b0), .gamma_bus(gamma_bus)
    );
endmodule
