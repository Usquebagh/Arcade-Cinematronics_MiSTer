`timescale 1ns/1ps
module vector_queue_tb;
    reg clk=0;
    always #5 clk=~clk;
    reg reset=1,in_valid=0,out_ready=0;
    reg [71:0] in_data=0;
    wire in_ready,out_valid,empty;
    wire [71:0] out_data;
    vector_queue dut(.*);
    reg [71:0] model [0:10016];
    reg [31:0] random_bits=32'hfeed1234;
    integer head=0,tail=0,n;
    reg push,pop;
    initial begin
        @(posedge clk);#1;
        @(negedge clk);reset=0;
        for(n=0;n<10000;n=n+1) begin
            random_bits={random_bits[30:0],random_bits[31]^random_bits[21]^random_bits[1]^random_bits[0]};
            in_valid=n<20 ? 1'b1 : random_bits[0];
            out_ready=n<20 ? 1'b0 : random_bits[1];
            in_data={8'(n),32'(n*3),32'(n*5)};
            #1;
            if(out_valid!==(tail!=head)||empty!==(tail==head)) $fatal(1,"Wrong queue occupancy");
            if(in_ready!==((tail-head)<16)) $fatal(1,"Queue overflow readiness");
            if(out_valid && out_data!==model[head]) $fatal(1,"Queue ordering/intensity mismatch");
            push=in_valid&&in_ready;pop=out_valid&&out_ready;
            if(push) begin model[tail]=in_data;tail=tail+1;end
            if(pop) head=head+1;
            @(posedge clk);#1;
            @(negedge clk);
        end
        in_valid=0;out_ready=1;
        while(head<tail) begin
            #1;if(!out_valid||out_data!==model[head]) $fatal(1,"Queue drain mismatch");
            head=head+1;@(posedge clk);#1;@(negedge clk);
        end
        #1;if(!empty) $fatal(1,"Queue failed to drain");
        $display("PASS: segment queue full/empty, wraparound, simultaneous transfers and ordering");
        $finish;
    end
endmodule
