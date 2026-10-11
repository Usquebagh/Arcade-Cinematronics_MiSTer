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
        "O[7],Screen overlay,On,Off;",
        "O[12],Detailed artwork,On,Off;",
        "O[9:8],Beam brightness,100%,75%,125%,150%;",
        "O[14:13],Glow amount,Medium,Off,Low,High;",
        "O[16:15],Glow spread,Soft,Tight,Wide;",
        "O[11:10],Overlay strength,100%,75%,50%,25%;",
        "-;DIP;O[6],Service mode,Off,On;",
        "-;R[0],Reset;",
        "J1,Fire,Thrust/Forward,Start 1,Coin,Start 2;",
        "jn,A,B,Start,Select,X;",
        "V,v",`BUILD_DATE
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
    wire [1:0] game_id, load_game_id;
    wire profile_valid, profile_active;
    cinemat_profile profile (
        .clk(clk_sys), .cold_reset(!pll_locked), .downloading(ioctl_download),
        .wr(ioctl_wr), .index(ioctl_index), .addr(ioctl_addr), .data(ioctl_dout),
        .game_id(game_id), .load_game_id(load_game_id), .valid(profile_valid), .active(profile_active)
    );
    wire [13:0] load_addr;
    wire [7:0] load_data;
    cinemat_download download (
        .rom_16k(load_game_id == 2),
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
    wire left2, right2, thrust2, fire2;
    cinemat_controls controls (
        .clk(clk_sys), .reset(reset || load_active || profile_active || !profile_valid),
        .game_id(game_id), .ps2_key(ps2_key),
        .joy0(joy0), .joy1(joy1), .start1(start1), .start2(start2),
        .left(left), .right(right), .thrust(thrust), .fire(fire), .coin(coin),
        .left2(left2), .right2(right2), .thrust2(thrust2), .fire2(fire2)
    );
    wire [8:0] scan_x, scan_y;
    wire [8:0] pixel_x, pixel_y;
    wire [7:0] scan_gray, gray;
    wire signed [15:0] mono_audio;
    wire [7:0] display_gray = rom_loaded && profile_valid && !profile_active && !load_active && !reset ? gray : 8'd0;
    wire ce_pix, hs, vs, hblank, vblank;
    cinemat_machine machine (
        .clk(clk_sys), .reset(reset || profile_active || !profile_valid),
        .game_id(game_id), .left2(left2), .right2(right2), .thrust2(thrust2), .fire2(fire2),
        .load_active(load_active), .rom_loaded(rom_loaded),
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
    wire [8:0] beam_x, beam_y;
    wire [7:0] beam_gray;
    wire beam_ce, beam_hs, beam_vs, beam_hblank, beam_vblank;
    vector_glow beam (
        .clk(clk_sys), .reset(!pll_locked), .brightness(status[9:8]),
        .amount(status[14:13]), .spread(status[16:15]),
        .x_in(pixel_x), .y_in(pixel_y), .gray_in(display_gray),
        .ce_in(ce_pix), .hs_in(hs), .vs_in(vs), .hblank_in(hblank), .vblank_in(vblank),
        .x_out(beam_x), .y_out(beam_y), .gray_out(beam_gray),
        .ce_out(beam_ce), .hs_out(beam_hs), .vs_out(beam_vs),
        .hblank_out(beam_hblank), .vblank_out(beam_vblank)
    );
    `include "rtl/video/overlays/starcastle_gains.svh"
    wire [23:0] display_rgb;
    wire colour_ce, colour_hs, colour_vs, colour_hblank, colour_vblank;
    vector_overlay #(.SPANS(STARCASTLE_OVERLAY_SPANS),
                     .GAINS(STARCASTLE_OVERLAY_GAINS)) overlay (
        .clk(clk_sys), .reset(!pll_locked), .enabled(!status[7] && game_id == 0),
        .brightness(2'd0), .strength(status[11:10]),
        .x(beam_x), .y(beam_y), .rgb_in({beam_gray,beam_gray,beam_gray}),
        .ce_in(beam_ce), .hs_in(beam_hs), .vs_in(beam_vs), .hblank_in(beam_hblank), .vblank_in(beam_vblank),
        .rgb_out(display_rgb), .ce_out(colour_ce), .hs_out(colour_hs), .vs_out(colour_vs),
        .hblank_out(colour_hblank), .vblank_out(colour_vblank)
    );
    // Match the coordinates to the preceding two-clock Star/bypass compositor.
    logic [8:0] artwork_x1,artwork_x2,artwork_y1,artwork_y2;
    always_ff @(posedge clk_sys) begin
        artwork_x1<=beam_x;artwork_x2<=artwork_x1;
        artwork_y1<=beam_y;artwork_y2<=artwork_y1;
    end
    wire [23:0] final_rgb;
    wire final_ce,final_hs,final_vs,final_hblank,final_vblank;
    wire [1:0] artwork_ink;
    armora_artwork artwork (
        .clk(clk_sys),.x(artwork_x2),.y(artwork_y2),.ink(artwork_ink)
    );
    armora_overlay town (
        .ink(artwork_ink),.artwork_enabled(!status[12]),
        .clk(clk_sys),.reset(!pll_locked),
        .enabled(game_id==2 && !status[7] && rom_loaded && profile_valid && !profile_active && !load_active && !reset),
        .strength(status[11:10]),.x(artwork_x2),.y(artwork_y2),.rgb_in(display_rgb),
        .ce_in(colour_ce),.hs_in(colour_hs),.vs_in(colour_vs),
        .hblank_in(colour_hblank),.vblank_in(colour_vblank),.rgb_out(final_rgb),
        .ce_out(final_ce),.hs_out(final_hs),.vs_out(final_vs),.hblank_out(final_hblank),.vblank_out(final_vblank)
    );
    // Gamma's serial RGB calculation also needs four clocks per pixel.
    arcade_video #(512,24,0) video (
        .clk_video(clk_sys), .ce_pix(final_ce), .RGB_in(final_rgb),
        .HBlank(final_hblank), .VBlank(final_vblank), .HSync(final_hs), .VSync(final_vs),
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
    assign LED_USER = load_active || load_error || profile_active || !profile_valid;
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
