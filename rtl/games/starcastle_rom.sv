// SPDX-License-Identifier: BSD-3-Clause
// Star Castle maps 8 KiB into mirrored 4 KiB banks selected by PC bit 13.
module starcastle_rom (
    input wire clk,
    input wire [15:0] cpu_addr,
    output logic [7:0] cpu_data,
    input wire load_write,
    input wire [12:0] load_addr,
    input wire [7:0] load_data
);
    logic [7:0] memory [0:8191];
    always_ff @(posedge clk) begin
        if (load_write) memory[load_addr] <= load_data;
        cpu_data <= memory[{cpu_addr[13],cpu_addr[11:0]}];
    end
endmodule
