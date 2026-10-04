// SPDX-License-Identifier: BSD-3-Clause
module mister_units_tb;
    reg clk=0;
    always #5 clk=~clk;
    reg cold_reset=1, downloading=0, wr=0;
    reg [15:0] index=0;
    reg [26:0] addr=0;
    reg [7:0] data=0;
    wire active, write_rom, loaded, error;
    wire [12:0] rom_addr;
    wire [7:0] rom_data;
    starcastle_download download(clk,cold_reset,downloading,wr,index,addr,data,
        active,write_rom,rom_addr,rom_data,loaded,error);
    task tick;
        @(posedge clk); #1;
    endtask
    task send_image(input integer length, input integer first_edge, input integer corrupt);
        @(negedge clk); downloading=1; wr=first_edge; addr=0; data=8'h5a;
        tick();
        for(integer n=first_edge;n<length;n=n+1) begin
            @(negedge clk); wr=1; addr=n==corrupt ? n+1 : n; data=n[7:0];
            #1;
            if(write_rom !== (addr<8192) || (write_rom && (rom_addr !== addr[12:0] || rom_data !== data)))
                $fatal(1,"ROM write decode");
            tick();
            if(loaded || !active) $fatal(1,"CPU released during download");
        end
        @(negedge clk); downloading=0; wr=0;
        #1; if(!active) $fatal(1,"Missing completion guard");
        tick();
    endtask
    reg controls_reset=1;
    reg [10:0] key=0;
    reg [31:0] joy0=0,joy1=0;
    wire start1,start2,left,right,thrust,fire,coin;
    wire [6:0] controls={start1,start2,left,right,thrust,fire,coin};
    starcastle_controls inputs(clk,controls_reset,key,joy0,joy1,start1,start2,left,right,thrust,fire,coin);
    task key_event(input [8:0] code,input pressed);
        @(negedge clk); key={!key[10],pressed,code}; tick();
    endtask
    reg video_reset=1;
    wire [8:0] sx,sy;
    reg [7:0] scan_gray;
    wire [7:0] gray;
    wire ce,hs,vs,hbl,vbl;
    // Distinguish all pixel boundaries and the vertical flip through a
    // synchronous read with the same latency as the real framebuffer.
    always @(posedge clk) scan_gray <= sx[7:0] ^ sy[7:0];
    vector_scanout scanout(clk,video_reset,scan_gray,sx,sy,gray,ce,hs,vs,hbl,vbl);
    integer sample,hpos,vpos,visible,hs_count,vs_count;
    initial begin
        tick(); @(negedge clk); cold_reset=0;
        send_image(8192,0,-1); if(!loaded || error) $fatal(1,"Valid ROM rejected");
        // A DIP transfer must preserve the loaded game and never write ROM.
        @(negedge clk); index=254; downloading=1; wr=1; addr=0;
        tick(); if(!loaded || active || write_rom) $fatal(1,"DIP interferes with ROM");
        @(negedge clk); downloading=0; wr=0; index=0; tick();
        send_image(8191,0,-1); if(loaded || !error) $fatal(1,"Short image accepted");
        send_image(8193,0,-1); if(loaded || !error) $fatal(1,"Oversize image accepted");
        send_image(8192,0,4032); if(loaded || !error) $fatal(1,"Out of order image accepted");
        send_image(0,0,-1); if(loaded || !error) $fatal(1,"Empty image accepted");
        send_image(8192,1,-1); if(!loaded || error) $fatal(1,"First-edge byte lost");
        @(negedge clk); cold_reset=1; tick(); if(loaded || error) $fatal(1,"Cold reset");
        @(negedge clk); controls_reset=0;
        key_event(9'h016,1); if(controls!==7'b1000000) $fatal(1,"Start key");
        key_event(9'h016,0); key_event(9'h01e,1); key_event(9'h16b,1);
        key_event(9'h174,1); key_event(9'h175,1); key_event(9'h029,1); key_event(9'h02e,1);
        if(controls!==7'b0111111) $fatal(1,"Gameplay keys");
        key_event(9'h01e,0); key_event(9'h16b,0); key_event(9'h174,0);
        key_event(9'h175,0); key_event(9'h029,0); key_event(9'h02e,0);
        if(controls!==0) $fatal(1,"Key releases");
        @(negedge clk); joy0=(1<<0)|(1<<1)|(1<<4)|(1<<5)|(1<<6)|(1<<7)|(1<<8);
        tick(); if(controls!==7'b1111111) $fatal(1,"Joystick 0 map");
        @(negedge clk); joy0=0; joy1=(1<<0)|(1<<1)|(1<<4)|(1<<5)|(1<<6)|(1<<7);
        tick(); if(controls!==7'b0111111) $fatal(1,"Joystick 1 map");
        @(negedge clk); joy1=0; video_reset=0;
        visible=0; hs_count=0; vs_count=0;
        for(sample=0;sample<800*521*2;sample=sample+1) begin
            tick(); if(ce) $fatal(1,"Pixel enable phase");
            tick(); if(!ce) $fatal(1,"Missing pixel enable");
            hpos=sample%800; vpos=(sample/800)%521;
            if(hbl !== (hpos>=512) || vbl !== (vpos>=384) ||
                hs !== (hpos>=528 && hpos<624) || vs !== (vpos>=394 && vpos<396))
                $fatal(1,"Video timing at %0d,%0d",hpos,vpos);
            if(hpos<512 && vpos<384) begin
                visible=visible+1;
                if(gray !== ((hpos^(383-vpos))&255)) $fatal(1,"Pixel/Y-flip at %0d,%0d",hpos,vpos);
            end else if(gray!==0) $fatal(1,"Unblanked border");
            if(hs) hs_count=hs_count+1;
            if(vs) vs_count=vs_count+1;
        end
        if(visible!=512*384*2 || hs_count!=96*521*2 || vs_count!=800*2*2) $fatal(1,"Frame counts");
        $display("PASS: HPS ROM validation, keyboard/controller inputs, two complete 512x384 scanout frames");
        $finish;
    end
endmodule
