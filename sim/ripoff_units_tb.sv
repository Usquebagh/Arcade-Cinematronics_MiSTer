// SPDX-License-Identifier: BSD-3-Clause
module ripoff_units_tb;
    reg clk=0;
    always #5 clk=~clk;
    task tick; @(posedge clk); #1; endtask
    reg cold_reset=1,downloading=0,wr=0;
    reg [15:0] index=0;
    reg [26:0] addr=0;
    reg [7:0] data=0;
    wire game_ripoff,valid,active;
    cinemat_profile profile(.*);
    task configure(input integer count,input [7:0] value,input integer first);
        @(negedge clk); index=1;downloading=1;wr=first;addr=0;data=value;
        tick(); if(valid || !active) $fatal(1,"Profile did not hold machine reset");
        for(integer n=first;n<count;n=n+1) begin
            @(negedge clk);wr=1;addr=n;tick();
        end
        @(negedge clk); downloading=0;wr=0;tick();
    endtask
    task load_rom;
        @(negedge clk);index=0;downloading=1;wr=1;addr=0;tick();
        @(negedge clk);downloading=0;wr=0;tick();
    endtask
    reg reset=1,start1=0,start2=0,left=0,right=0,thrust=0,fire=0,coin=0,service=0;
    reg left2=0,right2=0,thrust2=0,fire2=0;
    reg [5:0] dips=6'h13;
    reg [7:0] outputs=0;
    wire [23:0] inputs;
    wire coin_latched;
    cinemat_io board(.*);
    reg [10:0] ps2_key=0;
    reg [31:0] joy0=0,joy1=0;
    wire cs1,cs2,cl,cr,ct,cf,cc,cl2,cr2,ct2,cf2;
    cinemat_controls controls(.clk(clk),.reset(reset),.game_ripoff(game_ripoff),
        .ps2_key(ps2_key),.joy0(joy0),.joy1(joy1),.start1(cs1),.start2(cs2),
        .left(cl),.right(cr),.thrust(ct),.fire(cf),.coin(cc),
        .left2(cl2),.right2(cr2),.thrust2(ct2),.fire2(cf2));
    task key(input [8:0] code,input pressed);
        @(negedge clk);ps2_key={!ps2_key[10],pressed,code};tick();
    endtask
    initial begin
        tick();@(negedge clk);cold_reset=0;
        configure(1,1,1);load_rom();if(!valid || !game_ripoff) $fatal(1,"Rip Off profile");
        @(negedge clk);reset=0;dips=63;tick();
        if(inputs!==24'hffffff) $fatal(1,"Rip Off idle/service polarity");
        service=1;#1;if(inputs[22]!==0) $fatal(1,"Rip Off service assertion");service=0;
        for(integer n=0;n<10;n=n+1) begin
            {thrust,right,fire,left,fire2,thrust2,start2,right2,start1,left2}=10'b1<<n;
            #1;
            case(n)
                0: if(inputs[15:0]!==16'hfffe) $fatal(1,"P2 left");
                1: if(inputs[15:0]!==16'hfffd) $fatal(1,"Start1");
                2: if(inputs[15:0]!==16'hfffb) $fatal(1,"P2 right");
                3: if(inputs[15:0]!==16'hfff7) $fatal(1,"Start2");
                4: if(inputs[15:0]!==16'hffef) $fatal(1,"P2 thrust");
                5: if(inputs[15:0]!==16'hffdf) $fatal(1,"P2 fire");
                6: if(inputs[15:0]!==16'hefff) $fatal(1,"P1 left");
                7: if(inputs[15:0]!==16'hdfff) $fatal(1,"P1 fire");
                8: if(inputs[15:0]!==16'hbfff) $fatal(1,"P1 right");
                9: if(inputs[15:0]!==16'h7fff) $fatal(1,"P1 thrust");
            endcase
        end
        {thrust,right,fire,left,fire2,thrust2,start2,right2,start1,left2}=0;
        joy1=(1<<0)|(1<<1)|(1<<4)|(1<<5)|(1<<6);tick();
        if(cl || cr || ct || cf || !cl2 || !cr2 || !ct2 || !cf2 || !cs2) $fatal(1,"P2 leaks into P1");
        joy1=0;joy0=(1<<0)|(1<<1)|(1<<4)|(1<<5);tick();
        if(!cl || !cr || !ct || !cf || cl2 || cr2 || ct2 || cf2) $fatal(1,"P1 leaks into P2");
        joy0=0;key(9'h01c,1);key(9'h023,1);key(9'h01d,1);key(9'h02b,1);
        if(!cl2 || !cr2 || !ct2 || !cf2 || cl || cr || ct || cf) $fatal(1,"P2 keyboard");
        key(9'h01c,0);key(9'h023,0);key(9'h01d,0);key(9'h02b,0);
        if(cl2 || cr2 || ct2 || cf2) $fatal(1,"P2 releases");
        load_rom();if(!valid || game_ripoff) $fatal(1,"Legacy MRA inherited Rip Off profile");
        joy1=(1<<1)|(1<<4);tick();if(!cl || !cf) $fatal(1,"Star Castle joy merge changed");joy1=0;
        if(inputs[22]!==0) $fatal(1,"Star Castle service polarity");
        configure(1,1,0);load_rom();if(!valid || !game_ripoff) $fatal(1,"Delayed profile byte");
        configure(0,0,0);load_rom();if(valid) $fatal(1,"Empty profile accepted");
        configure(2,0,0);load_rom();if(valid) $fatal(1,"Long profile accepted");
        configure(1,2,1);load_rom();if(valid) $fatal(1,"Unknown game accepted");
        @(negedge clk);index=1;downloading=1;wr=1;addr=9;data=1;tick();
        @(negedge clk);downloading=0;wr=0;tick();load_rom();
        if(valid) $fatal(1,"Wrong first profile address accepted");
        configure(1,0,1);load_rom();if(!valid || game_ripoff) $fatal(1,"Recovery/Star Castle selection");
        $display("PASS: profile switching, legacy fallback, malformed profile rejection, game I/O/service polarity, independent two-player keyboard/controllers");
        $finish;
    end
endmodule
