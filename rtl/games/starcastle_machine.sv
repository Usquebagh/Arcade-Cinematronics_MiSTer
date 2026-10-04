// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Synchronous Star Castle machine, including its discrete sound-board model.
module starcastle_machine (
    input wire clk, reset,
    input wire load_active, rom_loaded, load_write,
    input wire [12:0] load_addr,
    input wire [7:0] load_data,
    input wire start1, start2, left, right, thrust, fire, coin, service,
    input wire [5:0] dips,
    input wire [8:0] scan_x, scan_y,
    output wire [7:0] scan_gray,
    output wire signed [15:0] audio,
    output wire audio_ce,
    output wire [7:0] outputs,
    output wire [7:0] sound_latch,
    output wire machine_ready, waiting, coin_latched, watchdog_reset,
    output wire frame_presented, cpu_ce, frame_tick,
    // Verification ports. These may be left unconnected by the MiSTer wrapper.
    output wire retired,
    output wire [7:0] trace_opcode,
    output wire [15:0] pc,
    output wire [11:0] a, b, j, x, y, cmp_acc, cmp_val,
    output wire [7:0] i,
    output wire [3:0] p,
    output wire [4:0] t, trace_cycles, vector_shift,
    output wire acc_b, a0, nc, mi, mi_next, mi_nextnext,
    output wire ram_write,
    output wire [7:0] ram_write_addr,
    output wire [11:0] ram_write_data,
    output wire [23:0] cpu_inputs,
    output wire vector_valid, vector_ready,
    output wire signed [15:0] vector_x0, vector_y0, vector_x1, vector_y1,
    output wire cpu_frame_wake,
    output logic frame_overrun
);
    // Compatibility wrapper used by the existing Star Castle regressions.
    cinemat_machine machine (.game_ripoff(1'b0), .left2(1'b0), .right2(1'b0),
                             .thrust2(1'b0), .fire2(1'b0), .*);
endmodule
