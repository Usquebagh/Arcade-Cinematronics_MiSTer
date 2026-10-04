// SPDX-License-Identifier: GPL-3.0-or-later
module mister_video_harness (
    input wire clk, reset,
    output wire ce, de, hs, vs,
    output wire [7:0] r, g, b
);
    wire [8:0] sx,sy;
    logic [7:0] scan_gray;
    wire [7:0] gray;
    wire pixel, hsync, vsync, hblank, vblank;
    wire [21:0] gamma_bus;
    assign gamma_bus[20:0] = {clk,20'd0}; // HPS gamma disabled, clock present.
    always_ff @(posedge clk) scan_gray <= sx[7:0] ^ sy[7:0];
    vector_scanout scanout (
        .clk(clk), .reset(reset), .scan_gray(scan_gray), .scan_x(sx), .scan_y(sy),
        .gray(gray), .ce_pixel(pixel), .hs(hsync), .vs(vsync), .hblank(hblank), .vblank(vblank)
    );
    arcade_video #(512,24,0) video (
        .clk_video(clk), .ce_pix(pixel), .RGB_in({gray,gray,gray}),
        .HBlank(hblank), .VBlank(vblank), .HSync(hsync), .VSync(vsync),
        .CLK_VIDEO(), .CE_PIXEL(ce), .VGA_R(r), .VGA_G(g), .VGA_B(b),
        .VGA_HS(hs), .VGA_VS(vs), .VGA_DE(de), .VGA_SL(),
        .fx(3'd0), .forced_scandoubler(1'b0), .gamma_bus(gamma_bus)
    );
endmodule
