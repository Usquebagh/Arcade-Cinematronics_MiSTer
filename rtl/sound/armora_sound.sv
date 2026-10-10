// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Armor Attack 72-11141-02: behavioral fixed-point circuits at 96 kHz.
// Shift/add RC approximations, generated tread VCO fit; not a netlist solver.
module armora_sound #(parameter integer CLOCK_HZ=50000000)(
    input wire clk,reset,
    input wire [7:0] outputs,
    output logic signed [15:0] audio,
    output wire sample_ce,
    output logic [7:0] shift_register,sound_latch
);
    `include "rtl/sound/armora_clocks.svh"
    localparam logic [26:0] CLOCK_RATE=27'(CLOCK_HZ);
    logic [26:0] sample_phase;
    wire [26:0] sample_next=sample_phase+27'd96000;
    assign sample_ce=!reset && sample_next>=CLOCK_RATE;
    logic [7:0] last_outputs;
    wire shift_edge=outputs[4] && !last_outputs[4];
    wire latch_edge=outputs[0] && !last_outputs[0];
    wire [3:0] pulse=latch_edge ? sound_latch[3:0]&~shift_register[3:0] : 4'd0;
    logic [3:0] pending;
    logic chopper_pending;
    wire chopper_edge=!outputs[3] && last_outputs[3];
    always_ff @(posedge clk) begin
        if(reset) begin
            sample_phase<=0;last_outputs<=0;shift_register<=0;sound_latch<=8'hff;
            pending<=0;chopper_pending<=0;
        end else begin
            sample_phase<=sample_ce?sample_next-CLOCK_RATE:sample_next;
            last_outputs<=outputs;
            if(shift_edge)shift_register<={shift_register[6:0],outputs[7]};
            if(latch_edge)sound_latch<=shift_register;
            pending<=sample_ce?4'd0:pending|pulse;
            chopper_pending<=sample_ce?1'b0:chopper_pending||chopper_edge;
        end
    end
    // Two power-of-two terms approximate the schematic RC coefficient.
    function automatic signed [31:0] rc(input signed [31:0] v,target,input integer sa,sb);
        logic signed [31:0] delta,step;
        begin
            delta=target-v;step=(delta>>>sa)+(sb==0?32'sd0:(delta>>>sb));
            if(step==0 && delta!=0)step=delta>0?32'sd1:-32'sd1;
            rc=v+step;
        end
    endfunction
    logic [16:0] noise_lfsr;
    logic noise_half;
    wire signed [31:0] noise_source=noise_lfsr[0]?32'sd4194304:-32'sd4194304;
    logic signed [31:0] tank_lp1,tank_lp2,lo_lp1,lo_lp2,chop_lp1,chop_lp2,jeep_lp1,jeep_lp2;
    logic signed [31:0] tank_env,lo_env,jeep_env,hi_env,dc,motor_lp;
    logic [23:0] motor_phase,beep_phase,tread_phase;
    logic [3:0] n_counter,divide16,divide13,tread_mod,tread_div;
    logic carrier_d,gate_d,div16_d,motor_square;
    logic signed [31:0] tread_level;
    wire [3:0] reload={sound_latch[4],sound_latch[5],sound_latch[6],sound_latch[7]};
    wire tank_on=!outputs[1] && reload!=15;
    wire [24:0] motor_next={1'b0,motor_phase}+25'd1284506; // nominal 7350 Hz, manual table
    wire [24:0] tread_next={1'b0,tread_phase}+{1'b0,tread_clock(tread_level[15:11])};
    wire carrier=n_counter==15;
    wire gate=!(divide16[3] && divide13[3]);
    wire signed [24:0] tank_product=$signed(tank_lp2[23:8])*$signed({1'b0,tank_env[23:16]});
    wire signed [24:0] lo_product=$signed(lo_lp2[23:8])*$signed({1'b0,lo_env[23:16]});
    // Jeep and high explosion drive the same IC22 filter/CCA. HI has lower
    // control resistance (750k vs 910k), approximated here by 1.25x gain.
    wire [9:0] jeep_gain={2'b00,jeep_env[23:16]}+{2'b00,hi_env[23:16]}+{4'b0000,hi_env[23:18]};
    wire signed [26:0] jeep_product=$signed(jeep_lp2[23:8])*$signed({1'b0,jeep_gain});
    wire signed [31:0] chopper_voice=(!outputs[3] || chopper_pending || chopper_edge)?(chop_lp2>>>9):32'sd0;
    wire signed [31:0] beep_voice=outputs[2]?32'sd0:(beep_phase[23]?32'sd1400:-32'sd1400);
    wire signed [31:0] tread_voice=tank_on?
        (tread_div[3]?32'sd1400:-32'sd1400)+
        (tread_div[2]?32'sd140:-32'sd140)+
        (tread_div[1]?32'sd140:-32'sd140)+
        (tread_div[0]?32'sd140:-32'sd140):32'sd0;
    wire signed [31:0] motor_source=tank_on?(motor_square?32'sd1900:-32'sd1900):32'sd0;
    wire signed [31:0] mixed=($signed({{7{tank_product[24]}},tank_product})>>>7)+
        ($signed({{7{lo_product[24]}},lo_product})>>>8)+
        ($signed({{5{jeep_product[26]}},jeep_product})>>>7)+
        chopper_voice+beep_voice+tread_voice+(motor_lp>>>8);
    // Two continuously clocked stages separate the DSP/mixer and 75% master
    // gain from the DC/output arithmetic. 40 ns latency at 50 MHz; no timing
    // exceptions. The gain leaves headroom for correlated simultaneous noise.
    logic signed [31:0] mixed_pipe,mixed_scaled;
    always_ff @(posedge clk) begin
        if(reset)begin mixed_pipe<=0;mixed_scaled<=0;end
        else begin mixed_pipe<=mixed;mixed_scaled<=mixed_pipe-(mixed_pipe>>>2);end
    end
    wire signed [31:0] coupled=mixed_scaled-dc;
    always_ff @(posedge clk) begin
        if(reset)begin
            audio<=0;noise_lfsr<=17'h1ffff;noise_half<=0;
            tank_lp1<=0;tank_lp2<=0;lo_lp1<=0;lo_lp2<=0;
            chop_lp1<=0;chop_lp2<=0;jeep_lp1<=0;jeep_lp2<=0;
            tank_env<=0;lo_env<=0;jeep_env<=0;hi_env<=0;dc<=0;motor_lp<=0;
            motor_phase<=0;beep_phase<=0;tread_phase<=0;tread_level<=0;
            n_counter<=0;divide16<=0;divide13<=3;tread_mod<=0;tread_div<=0;
            carrier_d<=0;gate_d<=1;div16_d<=0;motor_square<=0;
        end else if(sample_ce)begin
            noise_half<=!noise_half;
            if(noise_half)noise_lfsr<={noise_lfsr[0]^noise_lfsr[3],noise_lfsr[16:1]};
            tank_lp1<=rc(tank_lp1,noise_source,9,11);tank_lp2<=rc(tank_lp2,tank_lp1,9,10);
            lo_lp1<=rc(lo_lp1,noise_source,8,10);lo_lp2<=rc(lo_lp2,lo_lp1,6,9);
            chop_lp1<=rc(chop_lp1,noise_source,6,8);chop_lp2<=rc(chop_lp2,chop_lp1,8,11);
            jeep_lp1<=rc(jeep_lp1,noise_source,8,9);jeep_lp2<=rc(jeep_lp2,jeep_lp1,8,10);
            tank_env<=(!sound_latch[0]||pending[0]||pulse[0])?32'sd16777215:rc(tank_env,0,16,18);
            hi_env<=(!sound_latch[1]||pending[1]||pulse[1])?32'sd16777215:rc(hi_env,0,16,0);
            jeep_env<=(!sound_latch[2]||pending[2]||pulse[2])?32'sd16777215:rc(jeep_env,0,15,16);
            lo_env<=(!sound_latch[3]||pending[3]||pulse[3])?32'sd16777215:rc(lo_env,0,16,18);
            beep_phase<=beep_phase+24'd69251; // ~396 Hz from 20k/8.2k/.1uF
            motor_phase<=motor_next[23:0];
            carrier_d<=carrier;gate_d<=gate;div16_d<=divide16[3];
            if(!tank_on)begin
                n_counter<=reload;divide16<=0;divide13<=3;tread_mod<=0;motor_square<=0;
                carrier_d<=0;gate_d<=1;div16_d<=0;
            end else begin
                if(motor_next[24])n_counter<=n_counter==15?reload:n_counter+4'd1;
                if(carrier && !carrier_d)divide13<=divide13==15?4'd3:divide13+4'd1;
                if(!carrier && carrier_d)divide16<=divide16+4'd1;
                if(!gate && gate_d)motor_square<=!motor_square;
                if(!divide16[3] && div16_d)tread_mod<=tread_mod+4'd1;
            end
            tread_level<=rc(tread_level,{16'd0,tread_target(tread_mod[3:2])},13,0);
            tread_phase<=tread_next[23:0];
            if(!tank_on)tread_div<=0;
            else if(tread_next[24])tread_div<=tread_div+4'd1;
            motor_lp<=rc(motor_lp,motor_source<<<8,6,9);
            dc<=rc(dc,mixed_scaled,10,0);
            if(coupled>32767)audio<=16'sh7fff;
            else if(coupled< -32768)audio<=16'sh8000;
            else audio<=coupled[15:0];
        end
    end
endmodule
