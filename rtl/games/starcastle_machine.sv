// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Standalone synchronous machine component; MiSTer wrapper and sound follow.
module starcastle_machine (
    input wire clk, reset,
    input wire load_active, rom_loaded, load_write,
    input wire [12:0] load_addr,
    input wire [7:0] load_data,
    input wire start1, start2, left, right, thrust, fire, coin, service,
    input wire [5:0] dips,
    input wire [8:0] scan_x, scan_y,
    output wire [7:0] scan_gray,
    output wire [7:0] outputs,
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
    typedef enum logic [1:0] {STARTUP, RUN, DRAIN, CLEAR} state_t;
    state_t state;
    wire hard_reset = reset || load_active || !rom_loaded;
    wire [15:0] rom_addr;
    wire [7:0] rom_data;
    wire watchdog_clear, video_clearing;
    wire queue_valid, queue_ready, queue_empty;
    wire [71:0] queue_data;
    wire video_frame_ready;
    logic wake_pending;
    wire [7:0] intensity = outputs[6] ? 8'd128 : 8'd255;
    assign machine_ready = state == RUN && !hard_reset && !watchdog_reset;
    // Freeze the CPU while its producer slot is occupied, preserving the
    // intensity latch until the queued segment has been accepted.
    wire execute_ce = cpu_ce && machine_ready && !vector_valid && !frame_tick;
    assign cpu_frame_wake = wake_pending && machine_ready && waiting;
    starcastle_rom program_rom (
        .clk(clk), .cpu_addr(rom_addr), .cpu_data(rom_data),
        .load_write(load_write), .load_addr(load_addr), .load_data(load_data)
    );
    cinemat_timing timing (.clk(clk), .reset(hard_reset), .cpu_ce(cpu_ce), .frame_tick(frame_tick));
    cinemat_watchdog watchdog (
        .clk(clk), .reset(hard_reset), .frame_tick(frame_tick),
        .clear(watchdog_clear), .expired(watchdog_reset)
    );
    starcastle_io board_io (
        .clk(clk), .reset(hard_reset), .start1(start1), .start2(start2),
        .left(left), .right(right), .thrust(thrust), .fire(fire),
        .coin(coin), .service(service), .dips(dips), .outputs(outputs),
        .inputs(cpu_inputs), .coin_latched(coin_latched)
    );
    ccpu cpu (
        .clk(clk), .reset(hard_reset), .soft_reset(watchdog_reset),
        .ce(execute_ce), .rom_addr(rom_addr), .rom_data(rom_data), .inputs(cpu_inputs),
        .external_input(1'b0), .draw_busy(1'b0), .frame_tick(cpu_frame_wake),
        .outputs(outputs), .watchdog_clear(watchdog_clear), .waiting(waiting),
        .vector_valid(vector_valid), .vector_ready(vector_ready),
        .vector_x0(vector_x0), .vector_y0(vector_y0), .vector_x1(vector_x1), .vector_y1(vector_y1),
        .vector_shift(vector_shift), .retired(retired), .trace_opcode(trace_opcode),
        .trace_cycles(trace_cycles), .pc(pc), .a(a), .b(b), .j(j), .x(x), .y(y),
        .i(i), .p(p), .t(t), .acc_b(acc_b), .cmp_acc(cmp_acc), .cmp_val(cmp_val),
        .a0(a0), .nc(nc), .mi(mi), .mi_next(mi_next), .mi_nextnext(mi_nextnext),
        .ram_write(ram_write), .ram_write_addr(ram_write_addr), .ram_write_data(ram_write_data)
    );
    vector_queue segments (
        .clk(clk), .reset(hard_reset || watchdog_reset), .in_valid(vector_valid),
        .in_ready(vector_ready),
        .in_data({vector_x0,vector_y0,vector_x1,vector_y1,intensity}),
        .out_valid(queue_valid), .out_ready(queue_ready), .out_data(queue_data), .empty(queue_empty)
    );
    vector_video video (
        .clk(clk), .reset(hard_reset || watchdog_reset),
        .line_valid(queue_valid), .line_ready(queue_ready),
        .x0(queue_data[71:56]), .y0(queue_data[55:40]),
        .x1(queue_data[39:24]), .y1(queue_data[23:8]), .intensity(queue_data[7:0]),
        .frame_valid(state == DRAIN && queue_empty && !vector_valid),
        .frame_ready(video_frame_ready), .frame_presented(frame_presented),
        .scan_x(scan_x), .scan_y(scan_y), .scan_gray(scan_gray), .clearing(video_clearing)
    );
    always_ff @(posedge clk) begin
        if (hard_reset || watchdog_reset) begin state <= STARTUP; wake_pending <= 0; end
        else begin
            // Deliver this frame only to an existing FRM wait. A FRM which
            // starts after resuming must wait for the next hardware frame.
            if (wake_pending && machine_ready) wake_pending <= 0;
            case (state)
                STARTUP: if (!video_clearing) state <= RUN;
                RUN: if (frame_tick) state <= DRAIN;
                DRAIN: if (queue_empty && !vector_valid && video_frame_ready) state <= CLEAR;
                CLEAR: if (!video_clearing) begin state <= RUN; wake_pending <= 1; end
                default: state <= STARTUP;
            endcase
        end
        if (hard_reset) frame_overrun <= 0;
        else if (frame_tick && state != RUN) frame_overrun <= 1;
    end
endmodule
