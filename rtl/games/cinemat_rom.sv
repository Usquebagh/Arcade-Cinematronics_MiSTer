// SPDX-License-Identifier: BSD-3-Clause
// One shared 16 KiB program RAM. Preserve the 8 KiB games' physical mirrors.
module cinemat_rom (
    input wire clk, rom_16k,
    input wire [15:0] cpu_addr,
    output logic [7:0] cpu_data,
    input wire load_write,
    input wire [13:0] load_addr,
    input wire [7:0] load_data
);
    logic [7:0] memory [0:16383];
    wire [13:0] physical = rom_16k ? cpu_addr[13:0] :
                                            {1'b0,cpu_addr[13],cpu_addr[11:0]};
    always_ff @(posedge clk) begin
        if (load_write) memory[load_addr] <= load_data;
        cpu_data <= memory[physical];
    end
endmodule
