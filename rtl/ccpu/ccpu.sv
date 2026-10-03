// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Copyright (c) Aaron Giles (MAME CCPU instruction semantics)
// Instruction semantics derived from Aaron Giles' BSD-3-Clause MAME CCPU.
// See docs/references.md and LICENSES/MAME-BSD-3-Clause.txt.
// This is an instruction-functional baseline, not a gate-level CPU replica.
module ccpu #(
    parameter JMI = 1'b1
) (
    input wire clk, reset, ce,
    // One-clock synchronous ROM: address is stable during *_ADDR states.
    output logic [15:0] rom_addr,
    input wire [7:0] rom_data,
    input wire [23:0] inputs,
    input wire external_input, draw_busy, frame_tick,
    output logic [7:0] outputs,
    output logic watchdog_clear,
    output logic waiting,
    output logic vector_valid,
    input wire vector_ready,
    output logic signed [15:0] vector_x0, vector_y0, vector_x1, vector_y1,
    output logic [4:0] vector_shift,
    // Retirement interface used for differential verification.
    output logic retired,
    output logic [7:0] trace_opcode,
    output logic [4:0] trace_cycles,
    output logic [15:0] pc,
    output logic [11:0] a, b, j, x, y,
    output logic [7:0] i,
    output logic [3:0] p,
    output logic [4:0] t,
    output logic acc_b,
    output logic [11:0] cmp_acc, cmp_val,
    output logic a0, nc, mi, mi_next, mi_nextnext,
    output logic ram_write,
    output logic [7:0] ram_write_addr,
    output logic [11:0] ram_write_data
);
    typedef enum logic [2:0] {FETCH_ADDR, FETCH_DATA, OPERAND_ADDR,
                              OPERAND_DATA, EXECUTE} state_t;
    state_t state;
    logic [7:0] opcode, operand;
    logic [4:0] cooldown;
    logic [11:0] ram [0:255];
    logic [15:0] pc_n;
    logic [11:0] a_n, b_n, j_n, x_n, y_n, ca_n, cv_n;
    logic [7:0] i_n;
    logic [3:0] p_n;
    logic [4:0] t_n, cycles;
    logic acc_b_n, a0_n, nc_n, store, standard, write_acc;
    logic out_write, do_vector, do_wait, clear_wdt, branch;
    logic [7:0] address;
    logic [11:0] acc, value;
    logic [12:0] result, carry_sum;
    logic signed [15:0] sx, sy, ex, ey, dx, dy;
    integer n;

    function automatic [11:0] asr12(input [11:0] v);
        asr12 = {v[11], v[11:1]};
    endfunction

    always_comb begin
        rom_addr = pc;
        if (state == OPERAND_ADDR || state == OPERAND_DATA) begin
            if (opcode == 8'he2 || opcode == 8'hf2)
                rom_addr = {pc[15:12], acc_b ? b : a};
            else rom_addr = pc + 16'd1;
        end
    end

    always_comb begin
        pc_n = pc + 16'd1;
        a_n = a; b_n = b; j_n = j; x_n = x; y_n = y;
        i_n = i; p_n = p; t_n = t;
        ca_n = cmp_acc; cv_n = cmp_val; a0_n = a0; nc_n = nc;
        acc_b_n = 1'b0;
        acc = acc_b ? b : a;
        address = i;
        if (opcode[7:4] == 4'h6 || opcode[7:4] == 4'h7 ||
            (opcode[7:4] >= 4'ha && opcode[7:4] <= 4'hd))
            address = {p, opcode[3:0]};
        value = ram[address];
        result = 13'd0; carry_sum = 13'd0;
        standard = 1'b0; write_acc = 1'b1; store = 1'b0;
        out_write = 1'b0; do_vector = 1'b0; do_wait = 1'b0;
        clear_wdt = 1'b0; branch = 1'b0; cycles = 5'd1;
        n = 0;
        sx = {{4{x[11]}}, x}; sy = {{4{y[11]}}, y};
        ex = {{4{a[11]}}, a}; ey = {{4{b[11]}}, b};
        dx = ex - sx; dy = ey - sy;
        ex = sx + (dx >>> t); ey = sy + (dy >>> t);
        case (opcode[7:4])
            4'h0: begin // LDA immediate high nibble
                value = {opcode[3:0], 8'h00};
                result = {1'b0,value}; standard = 1'b1;
            end
            4'h1: begin // B selects the switch input bank
                value = {11'd0, inputs[acc_b ? (5'd16 + {2'd0,opcode[2:0]}) : {1'b0,opcode[3:0]}]};
                result = {1'b0,value}; standard = 1'b1;
            end
            4'h2, 4'h3: begin
                if (opcode[3:0] == 0) begin
                    value = {4'd0, operand}; pc_n = pc + 16'd2; cycles = 5'd3;
                end else value = {8'd0, opcode[3:0]};
                if (opcode[7:4] == 4'h2) result = {1'b0,acc} + {1'b0,value};
                else result = {1'b0,acc} + {1'b0,~value} + 13'd1;
                standard = 1'b1;
            end
            4'h4: begin
                j_n = {operand[3:0],operand[7:4],opcode[3:0]};
                pc_n = pc + 16'd2; cycles = 5'd3;
            end
            4'h5: begin
                cycles = 5'd2;
                acc_b_n = !opcode[3] && !acc_b;
                case (opcode[2:0])
                    3'd0: branch = 1'b1;
                    // MI advances at instruction entry in the reference CPU.
                    3'd1: branch = JMI ? mi_next : external_input;
                    3'd2: branch = draw_busy;
                    3'd3: branch = cmp_val < cmp_acc;
                    3'd4: branch = cmp_val == cmp_acc;
                    3'd5: branch = nc;
                    3'd6: branch = a0;
                    default: branch = 1'b0;
                endcase
                if (branch) begin
                    pc_n = opcode == 8'h50 ? {p,j} : {pc[15:12],j};
                    cycles = 5'd4;
                end
            end
            4'h6, 4'h7, 4'ha, 4'hb: begin
                i_n = address; cycles = 5'd3; standard = 1'b1;
                if (opcode[7:4] == 4'h6) result = {1'b0,acc} + {1'b0,value};
                else if (opcode[7:4] == 4'ha) result = {1'b0,value};
                else result = {1'b0,acc} + {1'b0,~value} + 13'd1;
                if (opcode[7:4] == 4'hb) write_acc = 1'b0;
            end
            4'h8: p_n = opcode[3:0];
            4'h9: out_write = !acc_b;
            4'hc: begin i_n = value[7:0]; cycles = 5'd3; end
            4'hd: begin i_n = address; store = 1'b1; cycles = 5'd3; end
            default: begin
                case (opcode)
                    8'he0: begin
                        do_vector = 1'b1;
                        // MAME's post-DV accumulator behavior; QB-3 is not supported yet.
                        a_n = x; b_n = y;
                    end
                    8'hf0: begin x_n = a; y_n = b; end
                    8'he1: begin j_n = value; cycles = 5'd3; end
                    8'hf1: begin i_n = value[7:0]; cycles = 5'd3; end
                    8'he2,8'hf2: begin
                        value = {4'd0,operand}; result = {1'b0,value};
                        standard = 1'b1; pc_n = pc + 16'd2; cycles = 5'd7;
                    end
                    8'he3,8'hf3: begin
                        cycles = 5'd2; a0_n = a[0]; cv_n = value;
                        if (!acc_b) begin
                            a_n = {b[0],a[11:1]}; b_n = asr12(b);
                            if (a[0]) begin
                                ca_n = b;
                                result = {1'b0,b_n} + {1'b0,value};
                                b_n = result[11:0];
                            end else begin
                                ca_n = a;
                                result = {1'b0,a} + {1'b0,value};
                            end
                        end else begin
                            ca_n = b; b_n = asr12(b);
                            result = {1'b0,b_n} + {1'b0,value};
                            if (a[0]) b_n = result[11:0];
                        end
                        nc_n = !result[12];
                    end
                    8'he4,8'hf4: begin
                        t_n = 5'd0;
                        for (n=0; n<16; n=n+1) begin
                            if (((a_n & 12'ha00)==0 || (a_n & 12'ha00)==12'ha00) &&
                                ((b_n & 12'ha00)==0 || (b_n & 12'ha00)==12'ha00)) begin
                                a_n = {a_n[10:0],1'b0}; b_n = {b_n[10:0],1'b0};
                                t_n = t_n + 5'd1;
                            end
                        end
                        cycles = t_n + 5'd1;
                    end
                    8'he5,8'hf5: begin
                        do_wait = 1'b1;
                        if (operand == opcode) pc_n = pc + 16'd2;
                    end
                    8'he6,8'hf6: begin store = 1'b1; cycles = 5'd2; end
                    8'he7,8'hf7: begin
                        result = {1'b0,acc}+{1'b0,value}; standard = 1'b1; cycles = 5'd2;
                        clear_wdt = opcode == 8'hf7;
                    end
                    8'he8,8'hf8: begin
                        result = {1'b0,acc}+{1'b0,~value}+13'd1; standard = 1'b1; cycles = 5'd3;
                    end
                    8'he9,8'hf9: begin
                        result = {1'b0,acc & value}; standard = 1'b1; cycles = 5'd2;
                    end
                    8'hea,8'hfa: begin result={1'b0,value}; standard=1'b1; cycles=5'd2; end
                    default: begin // shift family, with hardware's comparison constants
                        standard = 1'b1;
                        case (opcode[3:0])
                            4'hb: begin value = 12'hb0b | {4'd0,opcode[7:4],4'd0};
                                result = {1'b0, acc_b ? asr12(b) : {1'b0,a[11:1]}}; end
                            4'hc: begin value = 12'hc0c | {4'd0,opcode[7:4],4'd0};
                                result = {1'b0,acc[10:0],1'b0}; end
                            4'hd: begin value = 12'hd0d | {4'd0,opcode[7:4],4'd0};
                                result = {1'b0,asr12(acc)}; end
                            4'he: begin value = 12'he0e | {4'd0,opcode[7:4],4'd0};
                                result = {1'b0,acc_b ? asr12(b) : {b[0],a[11:1]}};
                                if (!acc_b) b_n = asr12(b); end
                            default: begin value = 12'hf0f | {4'd0,opcode[7:4],4'd0};
                                result = {1'b0,acc[10:0],1'b0};
                                if (!acc_b) b_n = {b[10:0],1'b0}; end
                        endcase
                        carry_sum = {1'b0,acc}+{1'b0,value};
                        if (opcode[3:0] != 4'hd) result[12] = carry_sum[12];
                    end
                endcase
            end
        endcase
        if (standard) begin
            a0_n = a[0]; ca_n = acc; cv_n = value; nc_n = !result[12];
            if (write_acc) begin
                if (acc_b) b_n = result[11:0]; else a_n = result[11:0];
            end
        end
    end

    always_ff @(posedge clk) begin
        retired <= 1'b0; ram_write <= 1'b0; watchdog_clear <= 1'b0;
        if (vector_valid && vector_ready) vector_valid <= 1'b0;
        if (reset) begin
            pc <= 0; a <= 0; b <= 0; i <= 0; j <= 0; p <= 0;
            x <= 0; y <= 0; t <= 0; acc_b <= 0;
            cmp_acc <= 0; cmp_val <= 1; a0 <= 0; nc <= 0;
            mi <= 0; mi_next <= 0; mi_nextnext <= 0;
            outputs <= 0; waiting <= 0; vector_valid <= 0;
            vector_x0 <= 0; vector_y0 <= 0; vector_x1 <= 0; vector_y1 <= 0;
            vector_shift <= 0; cooldown <= 0; state <= FETCH_ADDR;
            opcode <= 0; operand <= 0; trace_opcode <= 0; trace_cycles <= 0;
            ram_write_addr <= 0; ram_write_data <= 0;
            // RAM deliberately not reset: match physical RAM; software initializes it.
        end else begin
            if (frame_tick) waiting <= 1'b0;
            if (ce && cooldown != 0) cooldown <= cooldown - 5'd1;
            if (!waiting) begin
                case (state)
                    FETCH_ADDR: state <= FETCH_DATA;
                    FETCH_DATA: begin
                        opcode <= rom_data;
                        if (rom_data == 8'h20 || rom_data == 8'h30 || rom_data[7:4] == 4'h4 ||
                            rom_data == 8'he2 || rom_data == 8'hf2 ||
                            rom_data == 8'he5 || rom_data == 8'hf5) state <= OPERAND_ADDR;
                        else state <= EXECUTE;
                    end
                    OPERAND_ADDR: state <= OPERAND_DATA;
                    OPERAND_DATA: begin operand <= rom_data; state <= EXECUTE; end
                    EXECUTE: if (ce && cooldown == 0 &&
                        (!do_vector || !vector_valid || vector_ready)) begin
                        pc <= pc_n; a <= a_n; b <= b_n; j <= j_n; i <= i_n;
                        p <= p_n; x <= x_n; y <= y_n; t <= t_n; acc_b <= acc_b_n;
                        cmp_acc <= ca_n; cmp_val <= cv_n; a0 <= a0_n; nc <= nc_n;
                        mi <= mi_next; mi_next <= mi_nextnext;
                        mi_nextnext <= acc_b ? b_n[11] : a_n[11];
                        if (store) begin
                            ram[address] <= acc;
                            ram_write <= 1'b1; ram_write_addr <= address; ram_write_data <= acc;
                        end
                        if (out_write) outputs[opcode[2:0]] <= !a[0];
                        if (do_vector) begin
                            vector_valid <= 1'b1;
                            vector_x0 <= sx; vector_y0 <= sy; vector_x1 <= ex; vector_y1 <= ey;
                            vector_shift <= t;
                        end
                        watchdog_clear <= clear_wdt;
                        if (do_wait && !frame_tick) waiting <= 1'b1;
                        retired <= 1'b1; trace_opcode <= opcode; trace_cycles <= cycles;
                        cooldown <= cycles - 5'd1; state <= FETCH_ADDR;
                    end
                    default: state <= FETCH_ADDR;
                endcase
            end
        end
    end
endmodule
