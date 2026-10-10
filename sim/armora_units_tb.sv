// SPDX-License-Identifier: BSD-3-Clause
module armora_units_tb;
    reg clk=0; always #5 clk=~clk;
    task tick; @(posedge clk); #1; endtask
    reg cold_reset=1,downloading=0,wr=0;
    reg [15:0] index=0;
    reg [26:0] addr=0;
    reg [7:0] data=0;
    wire [1:0] game_id,load_game_id;
    wire valid,active;
    cinemat_profile profile(.*);
    wire load_active,load_write,rom_loaded,load_error;
    wire [13:0] load_addr;
    wire [7:0] load_data;
    cinemat_download download(.rom_16k(load_game_id==2),.*);
    reg [15:0] cpu_addr=0;
    wire [7:0] cpu_data;
    cinemat_rom memory(.rom_16k(game_id==2),.*);
    task configure(input [7:0] value);
        @(negedge clk);index=1;downloading=1;wr=1;addr=0;data=value;tick();
        if(valid || !active || load_write) $fatal(1,"Profile isolation");
        @(negedge clk);downloading=0;wr=0;tick();
    endtask
    function automatic [7:0] pattern(input integer a);
        pattern=(a^(a>>8)^(a>>12))&255;
    endfunction
    task transfer(input integer length,input integer first,input integer corrupt,input integer size);
        @(negedge clk);index=0;downloading=1;wr=first;addr=0;data=pattern(0);
        #1;if(load_write!== (first!=0)) $fatal(1,"First edge write");tick();
        for(integer n=first;n<length;n=n+1) begin
            @(negedge clk);wr=1;addr=n==corrupt ? n+1 : n;data=pattern(n);
            #1;if(load_write!==(addr<size) || (load_write && load_addr!==addr[13:0])) $fatal(1,"Selected ROM extent/address");
            tick();if(rom_loaded || !load_active) $fatal(1,"Released during download");
        end
        @(negedge clk);downloading=0;wr=0;#1;if(!load_active)$fatal(1,"Completion guard");tick();
    endtask
    initial begin
        tick();@(negedge clk);cold_reset=0;
        configure(2);transfer(16384,1,-1,16384);
        if(!valid || game_id!=2 || !rom_loaded || load_error) $fatal(1,"16 KiB first-edge load");
        for(integer a=0;a<65536;a=a+1) begin
            @(negedge clk);cpu_addr=a[15:0];tick();
            if(cpu_data!==pattern(a&16383)) $fatal(1,"16 KiB linear map %h",cpu_addr);
        end
        configure(0);transfer(8192,1,-1,8192);
        if(game_id!=0 || !rom_loaded || load_error) $fatal(1,"16 to 8 KiB switch");
        for(integer a=0;a<65536;a=a+1) begin
            @(negedge clk);cpu_addr=a[15:0];tick();
            if(cpu_data!==pattern(((a&8192)>>1)|(a&4095))) $fatal(1,"8 KiB mirrors changed %h",cpu_addr);
        end
        configure(2);transfer(8192,0,-1,16384);if(rom_loaded || !load_error)$fatal(1,"8 KiB accepted for Armor");
        configure(2);transfer(16383,0,-1,16384);if(rom_loaded || !load_error)$fatal(1,"Short Armor accepted");
        configure(2);transfer(16385,0,-1,16384);if(rom_loaded || !load_error)$fatal(1,"Long Armor accepted");
        configure(2);transfer(16384,0,12000,16384);if(rom_loaded || !load_error)$fatal(1,"Nonsequential Armor accepted");
        configure(1);transfer(16384,0,-1,8192);if(rom_loaded || !load_error)$fatal(1,"Armor length accepted for Rip Off");
        configure(2);transfer(16384,0,-1,16384);if(!rom_loaded || load_error)$fatal(1,"Recovery after invalid image");
        transfer(8192,1,-1,8192);if(game_id!=0 || !valid || !rom_loaded)$fatal(1,"Legacy MRA did not fall back to 8 KiB Star");
        @(negedge clk);index=254;downloading=1;wr=1;addr=0;tick();
        if(!rom_loaded || load_active || load_write)$fatal(1,"DIP transfer disturbed ROM");
        $display("PASS: atomic profile/size selection, all 65536 addresses in both maps, mixed-size switching, malformed loads and DIP isolation");
        $finish;
    end
endmodule
