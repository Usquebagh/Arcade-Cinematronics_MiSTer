// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Star Castle audio board 72-10861-02, manual PDF pages 86-87.
// Digital latch wiring follows the schematic. Analog sections use 96 kHz
// behavioral RC/VCO models, not a transistor-level circuit solver. See
// docs/sound.md for component values, approximations and validation limits.
module starcastle_sound #(
    parameter integer CLOCK_HZ = 50000000
) (
    input wire clk, reset,
    input wire [7:0] outputs,
    output logic signed [15:0] audio,
    output wire sample_ce,
    output logic [7:0] shift_register, sound_latch
);
    localparam logic [26:0] CLOCK_RATE = 27'(CLOCK_HZ);
    localparam logic signed [31:0] FULL = 32'sd16777216;
    logic [26:0] sample_phase;
    wire [26:0] sample_next = sample_phase + 27'd96000;
    assign sample_ce = !reset && sample_next >= CLOCK_RATE;
    logic [7:0] last_outputs;
    wire shift_edge = outputs[4] && !last_outputs[4];
    wire latch_edge = outputs[0] && !last_outputs[0];
    wire loud_edge = !outputs[1] && last_outputs[1];
    wire soft_edge = !outputs[2] && last_outputs[2];
    wire fireball_edge = latch_edge && sound_latch[0] && !shift_register[0];
    logic [2:0] pending;

    // IC2 LS164 shifts toward QH; QA receives OUT7 on rising OUT4.
    // IC3 LS377 copies all eight bits on rising OUT0. OUT5/6 are not sound.
    always_ff @(posedge clk) begin
        if (reset) begin
            last_outputs <= 0;
            shift_register <= 0;
            sound_latch <= 8'h1b; // effects off (STAR is active high)
            pending <= 0;
            sample_phase <= 0;
        end else begin
            last_outputs <= outputs;
            if (shift_edge) shift_register <= {shift_register[6:0],outputs[7]};
            if (latch_edge) sound_latch <= shift_register;
            // Preserve trigger pulses shorter than one audio sample.
            pending <= sample_ce ? 3'd0 : pending | {fireball_edge,soft_edge,loud_edge};
            sample_phase <= sample_ce ? sample_next - CLOCK_RATE : sample_next;
        end
    end

    // First-order RC update. State has eight or more fractional bits; the
    // Q24 coefficient is 1-exp(-1/(96000*R*C)). Signed 57-bit product avoids
    // wraparound during negative filter excursions.
    function automatic logic signed [31:0] rc(
        input logic signed [31:0] value, target,
        input logic [23:0] coefficient
    );
        logic signed [31:0] difference;
        logic signed [56:0] product;
        logic signed [31:0] step;
        begin
            difference = target - value;
            product = difference * $signed({1'b0,coefficient});
            step = product[55:24];
            // Do not leave a permanent DC residue when the fixed-point
            // increment becomes smaller than one state LSB.
            if (step == 0 && difference != 0) step = difference > 0 ? 32'sd1 : -32'sd1;
            rc = value + step;
        end
    endfunction

    // BL2/BL1/BL0 are QF/QG/QH, not the serial register's numerical order.
    // The resistor DAC weights are 1/1k, 1/2k and 1/3.3k. Endpoint-normalized
    // VCO fit gives the schematic's nominal 7.5..23.3 kHz background clock.
    function automatic logic signed [31:0] bg_target(input logic [2:0] level);
        case (level)
            0: bg_target = 32'sd1310720;
            1: bg_target = 32'sd1787375;
            2: bg_target = 32'sd2108111;
            3: bg_target = 32'sd2582334;
            4: bg_target = 32'sd2881007;
            5: bg_target = 32'sd3357737;
            6: bg_target = 32'sd3681171;
            7: bg_target = 32'sd4071960;
        endcase
    endfunction

    logic signed [31:0] bg_increment, laser_increment;
    logic [23:0] bg_phase, laser_phase, square_phase, star_phase;
    wire [24:0] bg_next = {1'b0,bg_phase} + {1'b0,bg_increment[23:0]};
    wire [24:0] laser_next = {1'b0,laser_phase} + {1'b0,laser_increment[23:0]};
    logic [7:0] bg_counter;
    logic [6:0] bg_div128;
    logic bg_div126;
    logic [3:0] laser_divider;
    logic noise_half;
    logic [16:0] noise_lfsr;
    wire signed [31:0] noise_source = noise_lfsr[0] ? 32'sd4194304 : -32'sd4194304;
    // IC16: 555 astable R32=2k, R33=130k, C20=.1uF (~55 Hz).
    wire signed [15:0] square_wave = square_phase[23] ? 16'sd8192 : -16'sd8192;
    logic signed [31:0] soft_env, loud_env, fireball_env, thrust_env;
    logic signed [31:0] soft_lp1, soft_lp2, loud_lp1, loud_lp2, thrust_lp1, thrust_lp2;
    logic signed [31:0] noise_dc, bg_dc, laser_dc;

    // IC23 is the ~9 Hz oscillator. IC24 is a second 555 with a control
    // voltage injected through R114/R115 and C39. Evolve its two capacitors
    // and apply the 1/3 and 2/3 Vcc thresholds rather than inventing a tune.
    logic signed [31:0] star_c39, star_c40;
    logic star_high;
    wire signed [31:0] star_source = star_phase[23] ? FULL : 32'sd0;
    wire signed [31:0] star39_a = rc(star_c39,star_source,24'd6597);
    wire signed [31:0] star39_b = rc(star_c39,star_c40,24'd5467);
    wire signed [31:0] star40_a = rc(star_c40,star_high ? FULL : 32'sd0,
                                      star_high ? 24'd193061 : 24'd442148);
    wire signed [31:0] star40_b = rc(star_c40,star_c39,24'd37142);

    // Each OTA voice multiplies its filtered source by its control envelope.
    // Q8 envelopes and reduced gains leave headroom for simultaneous effects.
    wire signed [24:0] soft_product = $signed(soft_lp2[23:8]) * $signed({1'b0,soft_env[23:16]});
    wire signed [24:0] loud_product = $signed(loud_lp2[23:8]) * $signed({1'b0,loud_env[23:16]});
    wire signed [24:0] thrust_product = $signed(thrust_lp2[23:8]) * $signed({1'b0,thrust_env[23:16]});
    wire signed [15:0] fireball_source = $signed(noise_source[23:9]) + (square_wave >>> 1);
    wire signed [24:0] fireball_product = fireball_source * $signed({1'b0,fireball_env[23:16]});
    wire signed [31:0] shield_voice = !sound_latch[1] && square_phase[23] ?
                                        (noise_source >>> 11) + ($signed({{16{square_wave[15]}},square_wave}) >>> 3) : 32'sd0;
    // The heavily low-pass-filtered explosion noise needs more gain than
    // the tonal voices. The previous shifts buried short blasts under the
    // laser/drone: soft +24 dB, loud +12 dB, with mixer headroom checked.
    wire signed [31:0] noise_mix = ($signed({{7{soft_product[24]}},soft_product}) >>> 7) +
                                    ($signed({{7{loud_product[24]}},loud_product}) >>> 8) +
                                    ($signed({{7{thrust_product[24]}},thrust_product}) >>> 9) +
                                    ($signed({{7{fireball_product[24]}},fireball_product}) >>> 11) + shield_voice;
    wire signed [31:0] bg_source = sound_latch[4] ? 32'sd0 :
                                    (bg_div126 ? 32'sd1700 : -32'sd1700) +
                                    (bg_div128[6] ? 32'sd1700 : -32'sd1700);
    // IC12 QA/QB/QD tap weights from R47=82k, R48=39k, R49=20k.
    wire signed [31:0] laser_source = outputs[3] ? 32'sd0 :
                                    (laser_divider[0] ? 32'sd310 : -32'sd310) +
                                    (laser_divider[1] ? 32'sd652 : -32'sd652) +
                                    (laser_divider[3] ? 32'sd1270 : -32'sd1270);
    wire signed [31:0] star_voice = sound_latch[2] ? (star_high ? 32'sd1100 : -32'sd1100) : 32'sd0;
    wire signed [31:0] mixed = noise_mix - (noise_dc >>> 8) + bg_source -
                                (bg_dc >>> 8) + laser_source - (laser_dc >>> 8) + star_voice;

    always_ff @(posedge clk) begin
        if (reset) begin
            bg_increment <= bg_target(0); laser_increment <= 32'sd3844779;
            bg_phase <= 0; laser_phase <= 0; square_phase <= 0; star_phase <= 0;
            bg_counter <= 8'hc1; bg_div128 <= 0; bg_div126 <= 0; laser_divider <= 0;
            noise_lfsr <= 17'h1ffff; noise_half <= 0;
            soft_env <= 0; loud_env <= 0; fireball_env <= 0; thrust_env <= 0;
            soft_lp1 <= 0; soft_lp2 <= 0; loud_lp1 <= 0; loud_lp2 <= 0;
            thrust_lp1 <= 0; thrust_lp2 <= 0;
            noise_dc <= 0; bg_dc <= 0; laser_dc <= 0;
            star_c39 <= 0; star_c40 <= 0; star_high <= 1;
            audio <= 0;
        end else if (sample_ce) begin
            bg_increment <= rc(bg_increment,bg_target({sound_latch[5],sound_latch[6],sound_latch[7]}),24'd78);
            laser_increment <= rc(laser_increment,outputs[3] ? 32'sd3844779 : 32'sd1013623,
                                    outputs[3] ? 24'd6247 : 24'd5295);
            bg_phase <= bg_next[23:0]; laser_phase <= laser_next[23:0];
            square_phase <= square_phase + 24'd9623;
            star_phase <= star_phase + 24'd1622;
            if (sound_latch[4]) begin bg_counter <= 8'hc1; bg_div128 <= 0; bg_div126 <= 0; end
            else if (bg_next[24]) begin
                bg_div128 <= bg_div128 + 7'd1;
                // IC10/11 reload C1 on the terminal carry; IC28 then clocks
                // IC12's first output. 63 VCO cycles per toggle (divide 126).
                if (bg_counter == 8'hff) begin bg_counter <= 8'hc1; bg_div126 <= !bg_div126; end
                else bg_counter <= bg_counter + 8'd1;
            end
            if (outputs[3]) laser_divider <= 0;
            else if (laser_next[24]) laser_divider <= laser_divider + 4'd1;
            noise_half <= !noise_half;
            if (noise_half) noise_lfsr <= {noise_lfsr[0]^noise_lfsr[3],noise_lfsr[16:1]};
            soft_env <= (!outputs[2] || pending[1] || soft_edge) ? FULL-1 : rc(soft_env,0,24'd794);
            loud_env <= (!outputs[1] || pending[0] || loud_edge) ? FULL-1 : rc(loud_env,0,24'd372);
            fireball_env <= (!sound_latch[0] || pending[2] || fireball_edge) ? FULL-1 : rc(fireball_env,0,24'd1285);
            thrust_env <= rc(thrust_env,sound_latch[3] ? 32'sd0 : FULL-1,
                                sound_latch[3] ? 24'd736 : 24'd1471);
            soft_lp1 <= rc(soft_lp1,noise_source,24'd44074);
            soft_lp2 <= rc(soft_lp2,soft_lp1,24'd116105);
            loud_lp1 <= rc(loud_lp1,noise_source,24'd255045);
            loud_lp2 <= rc(loud_lp2,loud_lp1,24'd943345);
            thrust_lp1 <= rc(thrust_lp1,noise_source,24'd96596);
            // R108 is loaded by R109+R110; use the parallel resistance
            // for C36 instead of an unloaded 47k/.33u pole.
            thrust_lp2 <= rc(thrust_lp2,thrust_lp1,24'd34262);
            noise_dc <= rc(noise_dc,noise_mix <<< 8,24'd64459);
            bg_dc <= rc(bg_dc,bg_source <<< 8,24'd7597);
            laser_dc <= rc(laser_dc,laser_source <<< 8,24'd145005);
            if (!sound_latch[2]) begin star_c39 <= 0; star_c40 <= 0; star_high <= 1; end
            else begin
                star_c39 <= star39_a + star39_b - star_c39;
                star_c40 <= star40_a + star40_b - star_c40;
                if (star_c40 >= 32'sd11184811) star_high <= 0;
                else if (star_c40 <= 32'sd5592405) star_high <= 1;
            end
            if (mixed > 32767) audio <= 16'sh7fff;
            else if (mixed < -32768) audio <= 16'sh8000;
            else audio <= mixed[15:0];
        end
    end
endmodule
