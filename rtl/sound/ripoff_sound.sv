// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Rip Off sound board: schematic-informed behavioral model, not a circuit
// solver. Manual PDF page 80 (8-18), pinned MAME nl_ripoff.cpp. No samples/ROMs.
module ripoff_sound #(
    parameter integer CLOCK_HZ = 50000000
) (
    input wire clk, reset,
    input wire [7:0] outputs,
    output logic signed [15:0] audio,
    output wire sample_ce,
    output logic [7:0] shift_register, sound_latch
);
    `include "rtl/sound/ripoff_clocks.svh"
    localparam logic [26:0] CLOCK_RATE = 27'(CLOCK_HZ);
    logic [26:0] sample_phase;
    wire [26:0] sample_next = sample_phase + 27'd96000;
    assign sample_ce = !reset && sample_next >= CLOCK_RATE;
    logic [7:0] last_outputs;
    wire shift_edge = outputs[1] && !last_outputs[1];
    wire latch_edge = outputs[2] && !last_outputs[2];
    wire explosion_edge = !outputs[7] && last_outputs[7];
    logic pending;
    logic [15:0] explosion_count;
    // Unlike Star Castle: OUT0=data, OUT1=clock, OUT2=commit, OUT7=explosion.
    // IC9 D6/D7 are grounded; only QA..QF of IC8 feed latched sound controls.
    always_ff @(posedge clk) begin
        if (reset) begin
            last_outputs <= 0; shift_register <= 0; sound_latch <= 8'h38;
            pending <= 0; sample_phase <= 0; explosion_count <= 0;
        end else begin
            last_outputs <= outputs;
            if (shift_edge) shift_register <= {shift_register[6:0],outputs[0]};
            if (latch_edge) sound_latch <= {2'b00,shift_register[5:0]};
            pending <= sample_ce ? 1'b0 : pending || explosion_edge;
            sample_phase <= sample_ce ? sample_next - CLOCK_RATE : sample_next;
            // IC4 555 monostable: 1.1*470k*.68uF = .35156 seconds.
            if (!outputs[7] || explosion_edge || pending) explosion_count <= 16'd33750;
            else if (sample_ce && explosion_count != 0) explosion_count <= explosion_count - 16'd1;
        end
    end
    // Power-of-two RC approximations keep this additional board inexpensive.
    // Arithmetic is signed; rounding toward the target removes DC residue.
    function automatic [15:0] slew(input [15:0] value, target, input integer shift);
        logic signed [16:0] delta, step, result;
        begin
            delta = $signed({1'b0,target}) - $signed({1'b0,value});
            step = delta >>> shift;
            if (step == 0 && delta != 0) step = delta > 0 ? 17'sd1 : -17'sd1;
            result = $signed({1'b0,value}) + step;
            slew = result[15:0];
        end
    endfunction
    function automatic signed [31:0] filter_step(input signed [31:0] value, target, input integer shift);
        logic signed [31:0] delta, step;
        begin
            delta = target-value;
            step = delta >>> shift;
            if (step == 0 && delta != 0) step = delta > 0 ? 32'sd1 : -32'sd1;
            filter_step = value + step;
        end
    endfunction
    logic [23:0] laser_phase, torpedo_phase, bg_low_phase, bg_high_phase;
    logic [23:0] beep_phase, motor1_phase, motor2_phase;
    logic [15:0] laser_level, torpedo_level, explosion_env;
    logic [3:0] laser_divider, torpedo_divider, bg_divider;
    logic bg_previous, noise_half;
    logic [16:0] noise_lfsr;
    wire bg_clock = bg_low_phase[23] || bg_high_phase[23];
    wire [24:0] laser_next = {1'b0,laser_phase}+{1'b0,laser_clock(laser_level[15:11])};
    wire [24:0] torpedo_next = {1'b0,torpedo_phase}+{1'b0,torpedo_clock(torpedo_level[15:11])};
    logic signed [31:0] noise_lp1, noise_lp2, dc;
    wire signed [31:0] noise_source = noise_lfsr[0] ? 32'sd32768 : -32'sd32768;
    wire signed [24:0] explosion_product = $signed(noise_lp2[23:8]) * $signed({1'b0,explosion_env[15:8]});
    function automatic signed [31:0] taps(input [3:0] bits);
        taps = (bits[0] ? 32'sd1024 : -32'sd1024) +
               (bits[1] ? 32'sd512 : -32'sd512) +
               (bits[2] ? 32'sd263 : -32'sd263) +
               (bits[3] ? 32'sd125 : -32'sd125);
    endfunction
    wire signed [31:0] laser_voice = outputs[4] ? 32'sd0 : taps(laser_divider);
    wire signed [31:0] torpedo_voice = outputs[3] ? 32'sd0 : taps(torpedo_divider);
    wire signed [31:0] bg_voice = sound_latch[3] ? 32'sd0 : taps(bg_divider);
    wire signed [31:0] beep_voice = sound_latch[4] ? 32'sd0 :
                                      (beep_phase[23] ? 32'sd1600 : -32'sd1600);
    wire signed [31:0] motor_voice = sound_latch[5] ? 32'sd0 :
                        (motor1_phase[23] ? 32'sd1200 : -32'sd1200) +
                        (motor2_phase[23] ? 32'sd800 : -32'sd800);
    wire signed [31:0] mixed = ($signed({{7{explosion_product[24]}},explosion_product}) >>> 8) +
                              laser_voice + torpedo_voice + bg_voice + beep_voice + motor_voice;
    // Break the multiplier/mixer/DC-filter chain at the system clock. This
    // stage runs every clock, so it settles long before the next 96 kHz sample
    // (minimum 520 clocks). It adds one 20 ns clock of mixer latency, with no
    // timing exception on the Rip Off arithmetic or its output path.
    logic signed [31:0] mixed_pipe;
    always_ff @(posedge clk) begin
        if (reset) mixed_pipe <= 0;
        else mixed_pipe <= mixed;
    end
    wire signed [31:0] coupled = mixed_pipe - dc;
    always_ff @(posedge clk) begin
        if (reset) begin
            audio <= 0; laser_phase <= 0; torpedo_phase <= 0;
            bg_low_phase <= 0; bg_high_phase <= 0; bg_previous <= 0;
            beep_phase <= 0; motor1_phase <= 0; motor2_phase <= 0;
            laser_level <= 0; torpedo_level <= 0; explosion_env <= 0;
            laser_divider <= 0; torpedo_divider <= 0; bg_divider <= 0;
            noise_lfsr <= 17'h1ffff; noise_half <= 0;
            noise_lp1 <= 0; noise_lp2 <= 0; dc <= 0;
        end else if (sample_ce) begin
            laser_level <= slew(laser_level,outputs[4] ? 16'd0 : 16'hffff,13);
            torpedo_level <= slew(torpedo_level,outputs[3] ? 16'd0 : 16'hffff,10);
            laser_phase <= laser_next[23:0]; torpedo_phase <= torpedo_next[23:0];
            if (outputs[4]) laser_divider <= 0;
            else if (laser_next[24]) laser_divider <= laser_divider + 4'd1;
            if (outputs[3]) torpedo_divider <= 0;
            else if (torpedo_next[24]) torpedo_divider <= torpedo_divider + 4'd1;
            bg_low_phase <= bg_low_phase + background_low(sound_latch[2:0]);
            bg_high_phase <= bg_high_phase + background_high(sound_latch[2:0]);
            bg_previous <= bg_clock;
            if (sound_latch[3]) bg_divider <= 0;
            else if (bg_previous && !bg_clock) bg_divider <= bg_divider + 4'd1;
            // IC5, IC11 and IC13 555 astables from their R/C component values.
            beep_phase <= beep_phase + 24'd253764; // ~1452 Hz
            motor1_phase <= motor1_phase + 24'd8936; // ~51 Hz
            motor2_phase <= motor2_phase + 24'd24200; // ~138 Hz
            noise_half <= !noise_half;
            if (noise_half) noise_lfsr <= {noise_lfsr[0]^noise_lfsr[3],noise_lfsr[16:1]};
            noise_lp1 <= filter_step(noise_lp1,noise_source <<< 8,9);
            noise_lp2 <= filter_step(noise_lp2,noise_lp1,9);
            explosion_env <= explosion_count != 0 ? 16'hffff : slew(explosion_env,0,13);
            dc <= filter_step(dc,mixed_pipe,8);
            if (coupled > 32767) audio <= 16'sh7fff;
            else if (coupled < -32768) audio <= 16'sh8000;
            else audio <= coupled[15:0];
        end
    end
endmodule
