// SPDX-License-Identifier: BSD-3-Clause
// MRA index 1: 00 Star Castle, 01 Rip Off, 02 Armor Attack, before index 0.
// Consume the staged profile once per ROM load. Legacy MRAs default to Star
// Castle even after Rip Off; malformed profiles keep the machine in reset.
module cinemat_profile (
    input wire clk, cold_reset, downloading, wr,
    input wire [15:0] index,
    input wire [26:0] addr,
    input wire [7:0] data,
    output logic [1:0] game_id = 0,
    output wire [1:0] load_game_id,
    output logic valid = 1,
    output wire active
);
    logic profile_d = 0, rom_d = 0;
    logic [1:0] staged = 0;
    logic staged_valid = 1, bad = 0;
    logic [1:0] count = 0;
    wire profile = downloading && index == 1;
    wire rom = downloading && index == 0;
    assign active = profile || profile_d;
    // The loader samples this before the ROM-start edge consumes the profile.
    assign load_game_id = staged;
    always_ff @(posedge clk) begin
        profile_d <= profile;
        rom_d <= rom;
        if (cold_reset) begin
            profile_d <= 0; rom_d <= 0; staged <= 0; staged_valid <= 1;
            game_id <= 0; valid <= 1; bad <= 0; count <= 0;
        end else begin
            if (profile) begin
                valid <= 0;
                if (!profile_d) begin
                    count <= wr ? 2'd1 : 2'd0;
                    bad <= wr && (addr != 0 || data > 2);
                end else if (wr) begin
                    if (count != 3) count <= count + 2'd1;
                    if (addr != 0 || count != 0 || data > 2) bad <= 1;
                end
                if (wr && addr == 0) staged <= data[1:0];
            end else if (profile_d) begin
                staged_valid <= !bad && count == 1;
                count <= 0; bad <= 0;
            end
            if (rom && !rom_d) begin
                game_id <= staged;
                valid <= staged_valid && !active;
                staged <= 0; staged_valid <= 1;
            end
        end
    end
endmodule
