// SPDX-License-Identifier: BSD-3-Clause
// Bind the staged profile's image size on ROM start, before it is consumed.
// Reject empty/truncated/oversized or nonsequential downloads of either size.
module cinemat_download (
    input wire clk, cold_reset, rom_16k,
    input wire downloading, wr,
    input wire [15:0] index,
    input wire [26:0] addr,
    input wire [7:0] data,
    output wire load_active, load_write,
    output wire [13:0] load_addr,
    output wire [7:0] load_data,
    output logic rom_loaded = 0,
    output logic load_error = 0
);
    logic active_d = 0, wide = 0, bad = 0;
    logic [14:0] count = 0;
    wire active = downloading && index == 0;
    wire [14:0] limit = (active_d ? wide : rom_16k) ? 15'd16384 : 15'd8192;
    assign load_active = active || active_d;
    assign load_write = active && wr && addr < {12'd0,limit};
    assign load_addr = addr[13:0];
    assign load_data = data;
    always_ff @(posedge clk) begin
        active_d <= active;
        if (cold_reset) begin
            active_d <= 0; wide <= 0; count <= 0; bad <= 0;
            rom_loaded <= 0; load_error <= 0;
        end else if (active) begin
            rom_loaded <= 0;
            if (!active_d) begin
                wide <= rom_16k;
                count <= wr ? 15'd1 : 15'd0;
                bad <= wr && addr != 0;
                load_error <= 0;
            end else if (wr) begin
                if (count < 15'd16385) count <= count + 15'd1;
                if (addr != {12'd0,count} || count >= limit) bad <= 1;
            end
        end else if (active_d) begin
            rom_loaded <= !bad && count == limit;
            load_error <= bad || count != limit;
            count <= 0; bad <= 0;
        end
    end
endmodule
