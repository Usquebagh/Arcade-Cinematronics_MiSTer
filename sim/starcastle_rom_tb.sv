`timescale 1ns/1ps
module starcastle_rom_tb;
    reg clk=0;
    always #5 clk=~clk;
    reg [15:0] cpu_addr=0;
    wire [7:0] cpu_data;
    reg load_write=0;
    reg [12:0] load_addr=0;
    reg [7:0] load_data=0;
    starcastle_rom dut(.*);
    integer address, physical;
    function automatic [7:0] pattern(input integer addr);
        pattern = (addr ^ (addr >> 8) ^ (addr >> 12)) & 255;
    endfunction
    initial begin
        for(address=0;address<8192;address=address+1) begin
            @(negedge clk);
            load_write=1;load_addr=address[12:0];load_data=pattern(address);
        end
        @(negedge clk);load_write=0;
        for(address=0;address<65536;address=address+1) begin
            @(negedge clk);cpu_addr=address[15:0];
            @(posedge clk);#1;
            physical=((address & 16'h2000)>>1)|(address & 16'h0fff);
            if(cpu_data!==pattern(physical))
                $fatal(1,"ROM mirror failed at %h: got %h expected %h",cpu_addr,cpu_data,pattern(physical));
        end
        $display("PASS: synchronous ROM download and all 65536 logical bank addresses");
        $finish;
    end
endmodule
