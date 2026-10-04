// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Small segment FIFO: four signed 16-bit coordinates and an 8-bit intensity.
module vector_queue (
    input wire clk, reset,
    input wire in_valid,
    output wire in_ready,
    input wire [71:0] in_data,
    output wire out_valid,
    input wire out_ready,
    output wire [71:0] out_data,
    output wire empty
);
    logic [71:0] memory [0:15];
    logic [3:0] write_pointer, read_pointer;
    logic [4:0] count;
    wire push = in_valid && in_ready;
    wire pop = out_valid && out_ready;
    assign in_ready = count < 5'd16;
    assign out_valid = count != 0;
    assign empty = count == 0;
    assign out_data = memory[read_pointer];
    always_ff @(posedge clk) begin
        if (reset) begin write_pointer <= 0; read_pointer <= 0; count <= 0; end
        else begin
            if (push) begin memory[write_pointer] <= in_data; write_pointer <= write_pointer + 4'd1; end
            if (pop) read_pointer <= read_pointer + 4'd1;
            case ({push,pop})
                2'b10: count <= count + 5'd1;
                2'b01: count <= count - 5'd1;
                default: count <= count;
            endcase
        end
    end
endmodule
