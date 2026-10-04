`timescale 1ns/1ps
module machine_units_tb;
    reg clk=0;
    always #5 clk=~clk;
    reg reset=1;
    wire cpu_ce,frame_tick;
    cinemat_timing timing(.*);
    reg wd_reset=1,wd_frame=0,wd_clear=0;
    wire expired;
    cinemat_watchdog watchdog(.clk(clk),.reset(wd_reset),.frame_tick(wd_frame),.clear(wd_clear),.expired(expired));
    reg start1=0,start2=0,left=0,right=0,thrust=0,fire=0,coin=0,service=0;
    reg [5:0] dips=6'h3f;
    reg [7:0] outputs=0;
    wire [23:0] inputs;
    wire coin_latched;
    starcastle_io io(.*);
    integer clocks,enables,frames,last_enable,gap,sw;
    reg sampled_ce,sampled_frame;
    task check_inputs(input [23:0] expected);
        begin #1; if(inputs!==expected) $fatal(1,"I/O got %h expected %h",inputs,expected); end
    endtask
    task watchdog_frame(input expected);
        begin
            @(negedge clk);wd_frame=1;
            @(posedge clk);#1;if(expired!==expected) $fatal(1,"Watchdog wrong frame count");
            @(negedge clk);wd_frame=0;
            @(posedge clk);#1;if(expired) $fatal(1,"Watchdog pulse exceeded one clock");
        end
    endtask
    initial begin
        @(posedge clk);#1;
        @(negedge clk);reset=0;wd_reset=0;
        check_inputs(24'hbfffff);
        start1=1;check_inputs(24'hbffffe);start1=0;
        start2=1;check_inputs(24'hbffffb);start2=0;
        left=1;check_inputs(24'hbfffbf);left=0;
        right=1;check_inputs(24'hbffeff);right=0;
        thrust=1;check_inputs(24'hbffbff);thrust=0;
        fire=1;check_inputs(24'hbfefff);fire=0;
        service=1;check_inputs(24'hffffff);service=0;
        for(sw=0;sw<6;sw=sw+1) begin
            dips=6'h3f^(6'b1<<sw);
            case(sw)
                0: check_inputs(24'hbfffff^(24'b1<<20));
                1: check_inputs(24'hbfffff^(24'b1<<21));
                2: check_inputs(24'hbfffff^(24'b1<<16));
                3: check_inputs(24'hbfffff^(24'b1<<19));
                4: check_inputs(24'hbfffff^(24'b1<<18));
                5: check_inputs(24'hbfffff^(24'b1<<17));
            endcase
        end
        dips=6'h3f;
        @(negedge clk);coin=1;
        @(posedge clk);#1;if(!coin_latched || inputs[23]) $fatal(1,"Coin was not latched");
        @(negedge clk);outputs[5]=1;
        @(posedge clk);#1;if(coin_latched) $fatal(1,"Coin acknowledge did not clear");
        repeat(3) begin @(posedge clk);#1;if(coin_latched) $fatal(1,"Held coin retriggered");end
        @(negedge clk);coin=0;outputs[5]=0;
        @(posedge clk);#1;
        @(negedge clk);coin=1;outputs[5]=1;
        @(posedge clk);#1;if(!coin_latched) $fatal(1,"Coin lost on simultaneous acknowledge");
        @(negedge clk);coin=0;
        @(posedge clk);#1;if(!coin_latched) $fatal(1,"Coin disappeared without new acknowledge edge");
        watchdog_frame(0);watchdog_frame(0);watchdog_frame(1);
        watchdog_frame(0);
        @(negedge clk);wd_clear=1;wd_frame=1;
        @(posedge clk);#1;if(expired) $fatal(1,"Clear must win on frame edge");
        @(negedge clk);wd_clear=0;wd_frame=0;
        watchdog_frame(0);watchdog_frame(0);watchdog_frame(1);
        // Restart the fractional divider for an exact finite-window count.
        @(negedge clk);reset=1;
        @(posedge clk);#1;
        @(negedge clk);reset=0;
        enables=0;frames=0;last_enable=0;
        for(clocks=1;clocks<=2700000;clocks=clocks+1) begin
            sampled_ce=cpu_ce;sampled_frame=frame_tick;
            if(sampled_ce) begin
                enables=enables+1;gap=clocks-last_enable;
                if(gap!=10 && gap!=11) $fatal(1,"Fractional enable gap %d",gap);
                last_enable=clocks;
            end
            if(sampled_frame) begin
                frames=frames+1;
                if(enables!=frames*131072) $fatal(1,"Wrong frame-divider phase");
            end
            @(posedge clk);#1;
            if(clocks==200000 && enables!=19923) $fatal(1,"Wrong exact-average clock rate");
            @(negedge clk);
        end
        if(frames!=2) $fatal(1,"Expected two hardware frame ticks");
        $display("PASS: exact CPU enable, frame divider, watchdog, controls, DIP shuffle and latched coin");
        $finish;
    end
endmodule
