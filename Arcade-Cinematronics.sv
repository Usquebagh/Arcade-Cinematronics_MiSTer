// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (c) 2026 Usquebagh
module emu (
    `include "sys/emu_ports.vh"
);
    wire clk_sys, pll_locked;
    pll pll (.refclk(CLK_50M), .rst(1'b0), .outclk_0(clk_sys), .locked(pll_locked));
    `include "build_id.v"
    localparam CONF_STR = {
        "Cinematronics;;",
        "-;",
        "O[122:121],Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
        "O[7],Colour overlay,On,Off;",
        "O[9:8],Vector brightness,100%,75%,125%,150%;",
        "O[11:10],Overlay strength,100%,75%,50%,25%;",
        "-;DIP;O[6],Service mode,Off,On;",
        "-;R[0],Reset;",
        "J1,Fire,Thrust,Start 1,Coin,Start 2;",
        "jn,A,B,Start,Select,X;",
        "V,v",`BUILD_DATE," colour"
    };
    wire [127:0] status;
    wire [1:0] buttons;
    wire forced_scandoubler, direct_video;
    wire [21:0] gamma_bus;
    wire ioctl_download, ioctl_wr;
    wire [26:0] ioctl_addr;
    wire [7:0] ioctl_dout;
    wire [15:0] ioctl_index;
    wire [31:0] joy0, joy1;
    wire [10:0] ps2_key;
    hps_io #(.CONF_STR(CONF_STR)) hps_io (
        .clk_sys(clk_sys), .HPS_BUS(HPS_BUS), .EXT_BUS(),
        .gamma_bus(gamma_bus), .forced_scandoubler(forced_scandoubler),
        .direct_video(direct_video), .buttons(buttons), .status(status),
        .ioctl_download(ioctl_download), .ioctl_wr(ioctl_wr),
        .ioctl_addr(ioctl_addr), .ioctl_dout(ioctl_dout),
        .ioctl_index(ioctl_index), .ioctl_wait(1'b0),
        .joystick_0(joy0), .joystick_1(joy1), .ps2_key(ps2_key)
    );
    wire reset = RESET || status[0] || buttons[1] || !pll_locked;
    wire load_active, load_write, rom_loaded, load_error;
    wire [12:0] load_addr;
    wire [7:0] load_data;
    starcastle_download download (
        .clk(clk_sys), .cold_reset(!pll_locked),
        .downloading(ioctl_download), .wr(ioctl_wr), .index(ioctl_index),
        .addr(ioctl_addr), .data(ioctl_dout),
        .load_active(load_active), .load_write(load_write),
        .load_addr(load_addr), .load_data(load_data),
        .rom_loaded(rom_loaded), .load_error(load_error)
    );
    logic [7:0] dips = 8'h3f;
    always_ff @(posedge clk_sys)
        if (ioctl_wr && ioctl_index == 16'd254 && ioctl_addr == 0) dips <= ioctl_dout;
    wire start1, start2, left, right, thrust, fire, coin;
    starcastle_controls controls (
        .clk(clk_sys), .reset(reset || load_active), .ps2_key(ps2_key),
        .joy0(joy0), .joy1(joy1), .start1(start1), .start2(start2),
        .left(left), .right(right), .thrust(thrust), .fire(fire), .coin(coin)
    );
    wire [8:0] scan_x, scan_y;
    wire [8:0] pixel_x, pixel_y;
    wire [7:0] scan_gray, gray;
    wire signed [15:0] mono_audio;
    wire [7:0] display_gray = rom_loaded && !load_active && !reset ? gray : 8'd0;
    wire ce_pix, hs, vs, hblank, vblank;
    starcastle_machine machine (
        .clk(clk_sys), .reset(reset), .load_active(load_active), .rom_loaded(rom_loaded),
        .load_write(load_write), .load_addr(load_addr), .load_data(load_data),
        .start1(start1), .start2(start2), .left(left), .right(right),
        .thrust(thrust), .fire(fire), .coin(coin), .service(status[6]), .dips(dips[5:0]),
        .scan_x(scan_x), .scan_y(scan_y), .scan_gray(scan_gray),
        .audio(mono_audio), .audio_ce()
    );
    vector_scanout scanout (
        .clk(clk_sys), .reset(!pll_locked), .scan_gray(scan_gray),
        .scan_x(scan_x), .scan_y(scan_y), .gray(gray), .ce_pixel(ce_pix),
        .pixel_x(pixel_x), .pixel_y(pixel_y),
        .hs(hs), .vs(vs), .hblank(hblank), .vblank(vblank)
    );
    `include "rtl/video/overlays/starcastle_gains.svh"
    wire [23:0] display_rgb;
    wire colour_ce, colour_hs, colour_vs, colour_hblank, colour_vblank;
    vector_overlay #(.SPANS(STARCASTLE_OVERLAY_SPANS),
                     .GAINS(STARCASTLE_OVERLAY_GAINS)) overlay (
        .clk(clk_sys), .reset(!pll_locked), .enabled(!status[7]),
        .brightness(status[9:8]), .strength(status[11:10]),
        .x(pixel_x), .y(pixel_y), .rgb_in({display_gray,display_gray,display_gray}),
        .ce_in(ce_pix), .hs_in(hs), .vs_in(vs), .hblank_in(hblank), .vblank_in(vblank),
        .rgb_out(display_rgb), .ce_out(colour_ce), .hs_out(colour_hs), .vs_out(colour_vs),
        .hblank_out(colour_hblank), .vblank_out(colour_vblank)
    );
    // Gamma's serial RGB calculation also needs four clocks per pixel.
    arcade_video #(512,24,0) video (
        .clk_video(clk_sys), .ce_pix(colour_ce), .RGB_in(display_rgb),
        .HBlank(colour_hblank), .VBlank(colour_vblank), .HSync(colour_hs), .VSync(colour_vs),
        .CLK_VIDEO(CLK_VIDEO), .CE_PIXEL(CE_PIXEL),
        .VGA_R(VGA_R), .VGA_G(VGA_G), .VGA_B(VGA_B),
        .VGA_HS(VGA_HS), .VGA_VS(VGA_VS), .VGA_DE(VGA_DE), .VGA_SL(VGA_SL),
        // Native 31.25 kHz progressive output needs no scandoubler.
        // Its HQ2x path requires >=4 clocks/pixel; scanout provides two.
        .fx(3'd0), .forced_scandoubler(1'b0), .gamma_bus(gamma_bus)
    );
    wire [1:0] ar = status[122:121];
    assign VIDEO_ARX = ar == 0 ? 13'd4 : {11'd0,ar} - 13'd1;
    assign VIDEO_ARY = ar == 0 ? 13'd3 : 13'd0;
    assign {VGA_F1,VGA_SCALER,VGA_DISABLE,HDMI_FREEZE,HDMI_BLACKOUT,HDMI_BOB_DEINT} = 0;
    assign AUDIO_L = mono_audio;
    assign AUDIO_R = mono_audio;
    assign AUDIO_S = 1;
    assign AUDIO_MIX = 0;
    assign LED_USER = load_active || load_error;
    assign {LED_POWER,LED_DISK,BUTTONS} = 0;
    assign ADC_BUS = 'z;
    assign USER_OUT = '1;
    assign {UART_RTS,UART_TXD,UART_DTR} = 0;
    assign {SD_SCK,SD_MOSI,SD_CS} = 'z;
    assign {SDRAM_CLK,SDRAM_CKE,SDRAM_A,SDRAM_BA,SDRAM_DQML,SDRAM_DQMH} = 0;
    assign {SDRAM_nCS,SDRAM_nCAS,SDRAM_nRAS,SDRAM_nWE} = '1;
    assign SDRAM_DQ = 'z;
    assign DDRAM_CLK = clk_sys;
    assign {DDRAM_BURSTCNT,DDRAM_ADDR,DDRAM_RD,DDRAM_DIN,DDRAM_BE,DDRAM_WE} = 0;
`ifdef MISTER_FB
    assign {FB_EN,FB_FORMAT,FB_WIDTH,FB_HEIGHT,FB_BASE,FB_STRIDE,FB_FORCE_BLANK} = 0;
`endif
endmodule
