// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Byte-wide HPS transfer. Reject truncated, oversized or non-sequential images.
module starcastle_download (
    input wire clk, cold_reset,
    input wire downloading, wr,
    input wire [15:0] index,
    input wire [26:0] addr,
    input wire [7:0] data,
    output wire load_active, load_write,
    output wire [12:0] load_addr,
    output wire [7:0] load_data,
    output logic rom_loaded = 0,
    output logic load_error = 0
);
    logic active_d = 0, bad = 0;
    logic [13:0] count = 0;
    wire active = downloading && index == 0;
    // Include the final transfer edge while validating completion.
    assign load_active = active || active_d;
    assign load_write = active && wr && addr < 27'd8192;
    assign load_addr = addr[12:0];
    assign load_data = data;
    always_ff @(posedge clk) begin
        active_d <= active;
        if (cold_reset) begin
            active_d <= 0; count <= 0; bad <= 0;
            rom_loaded <= 0; load_error <= 0;
        end else if (active) begin
            rom_loaded <= 0;
            if (!active_d) begin
                count <= wr ? 14'd1 : 14'd0;
                bad <= wr && addr != 0;
                load_error <= 0;
            end else if (wr) begin
                if (count < 14'd8193) count <= count + 14'd1;
                if (addr != {13'd0,count} || count >= 14'd8192) bad <= 1;
            end
        end else if (active_d) begin
            rom_loaded <= !bad && count == 14'd8192;
            load_error <= bad || count != 14'd8192;
            count <= 0; bad <= 0;
        end
    end
endmodule
