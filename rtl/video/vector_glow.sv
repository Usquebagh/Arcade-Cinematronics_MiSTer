// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Streaming monochrome beam plus a separable 3/5/7-tap binomial glow.
// Keep nine-bit beam energy until the final composite: overdrive increases
// neighbouring light even when the narrow primary has reached output white.
// Six scanline delays retain the centre pixel and its complete timing packet.
// No connection to the drawing framebuffer or CPU backpressure is required.
module vector_glow #(
    parameter integer LINE_PIXELS = 800
) (
    input wire clk, reset,
    input wire [1:0] brightness, amount, spread,
    input wire ce_in, hs_in, vs_in, hblank_in, vblank_in,
    input wire [8:0] x_in, y_in,
    input wire [7:0] gray_in,
    output logic ce_out, hs_out, vs_out, hblank_out, vblank_out,
    output logic [8:0] x_out, y_out,
    output logic [7:0] gray_out
);
    localparam integer ADDR_BITS = $clog2(LINE_PIXELS);
    localparam integer WARM_BITS = $clog2(6*LINE_PIXELS+1);
    typedef struct packed {
        logic [8:0] x, y;
        logic hs, vs, hb, vb;
        logic [8:0] beam;
    } packet_t;
    // Only the first three rows need coordinates/sync; Quartus removes the
    // unused metadata bits from the remaining row memories.
    (* ramstyle = "M10K, no_rw_check" *) packet_t row0 [0:LINE_PIXELS-1];
    (* ramstyle = "M10K, no_rw_check" *) packet_t row1 [0:LINE_PIXELS-1];
    (* ramstyle = "M10K, no_rw_check" *) packet_t row2 [0:LINE_PIXELS-1];
    (* ramstyle = "M10K, no_rw_check" *) packet_t row3 [0:LINE_PIXELS-1];
    (* ramstyle = "M10K, no_rw_check" *) packet_t row4 [0:LINE_PIXELS-1];
    (* ramstyle = "M10K, no_rw_check" *) packet_t row5 [0:LINE_PIXELS-1];
    packet_t source, r0, r1, r2, r3, r4, r5;
    packet_t centre, horizontal_packet [0:6], composite_packet;
    logic [8:0] vertical, horizontal [0:6], blurred;
    logic [ADDR_BITS-1:0] addr, write_addr;
    logic [WARM_BITS-1:0] warm;
    logic write_valid;
    logic [1:0] brightness_q, amount_q, spread_q;

    function automatic [8:0] beam_drive(input [7:0] value, input [1:0] setting);
        logic [8:0] wide;
        begin
            wide = {1'b0,value};
            case (setting)
                2'd1: beam_drive = wide - ((wide + 9'd3) >> 2); // 75%
                2'd2: beam_drive = wide + (wide >> 2);        // 125%
                2'd3: beam_drive = wide + (wide >> 1);        // 150%
                default: beam_drive = wide;                  // 100%
            endcase
        end
    endfunction
    function automatic [8:0] filter7(
        input [8:0] a,b,c,d,e,f,g, input [1:0] width
    );
        logic [15:0] aa,bb,cc,dd,ee,ff,gg,sum;
        begin
            aa={7'd0,a}; bb={7'd0,b}; cc={7'd0,c}; dd={7'd0,d};
            ee={7'd0,e}; ff={7'd0,f}; gg={7'd0,g};
            case (width)
                // Tight: [1 2 1]/4, centred within the common seven taps.
                2'd1: sum = cc + (dd << 1) + ee + 16'd2;
                // Wide: [1 6 15 20 15 6 1]/64.
                2'd2: sum = aa + gg + ((bb+ff)<<2) + ((bb+ff)<<1)
                          + ((cc+ee)<<4) - (cc+ee)
                          + (dd<<4) + (dd<<2) + 16'd32;
                // Soft: [1 4 6 4 1]/16.
                default: sum = bb + ff + ((cc+ee)<<2)
                               + (dd<<2) + (dd<<1) + 16'd8;
            endcase
            case (width)
                2'd1: filter7 = 9'(sum >> 2);
                2'd2: filter7 = 9'(sum >> 6);
                default: filter7 = 9'(sum >> 4);
            endcase
        end
    endfunction
    logic [8:0] glow;
    logic [9:0] energy;
    always_comb begin
        case (amount_q)
            2'd1: glow = 9'd0;            // Off
            2'd2: glow = blurred >> 2;    // Low
            2'd3: glow = blurred;         // High
            default: glow = blurred >> 1;// Medium
        endcase
        energy = {1'b0,composite_packet.beam} + {1'b0,glow};
    end
    // Synchronous reads, then writes on the following pixel enable. Keeping
    // addresses with the read packets avoids an extra RAM read port/bypass.
    always_ff @(posedge clk) begin
        if (ce_in) begin
            r0 <= warm >= WARM_BITS'(LINE_PIXELS)   ? row0[addr] : {18'd0,4'b0011,9'd0};
            r1 <= warm >= WARM_BITS'(2*LINE_PIXELS) ? row1[addr] : {18'd0,4'b0011,9'd0};
            r2 <= warm >= WARM_BITS'(3*LINE_PIXELS) ? row2[addr] : {18'd0,4'b0011,9'd0};
            r3 <= warm >= WARM_BITS'(4*LINE_PIXELS) ? row3[addr] : {18'd0,4'b0011,9'd0};
            r4 <= warm >= WARM_BITS'(5*LINE_PIXELS) ? row4[addr] : {18'd0,4'b0011,9'd0};
            r5 <= warm >= WARM_BITS'(6*LINE_PIXELS) ? row5[addr] : {18'd0,4'b0011,9'd0};
            if (write_valid && !reset) begin
                row0[write_addr] <= source;
                row1[write_addr] <= r0;
                row2[write_addr] <= r1;
                row3[write_addr] <= r2;
                row4[write_addr] <= r3;
                row5[write_addr] <= r4;
            end
        end
    end
    always_ff @(posedge clk) begin
        ce_out <= !reset && ce_in;
        if (reset) begin
            addr <= 0; write_addr <= 0; warm <= 0; write_valid <= 0;
            brightness_q <= 0; amount_q <= 0; spread_q <= 0;
            source <= {18'd0,4'b0011,9'd0}; centre <= {18'd0,4'b0011,9'd0};
            composite_packet <= {18'd0,4'b0011,9'd0};
            vertical <= 0; blurred <= 0;
            x_out <= 0; y_out <= 0; gray_out <= 0;
            hs_out <= 0; vs_out <= 0; hblank_out <= 1; vblank_out <= 1;
            for (integer i=0; i<7; i=i+1) begin
                horizontal[i] <= 0;
                horizontal_packet[i] <= {18'd0,4'b0011,9'd0};
            end
        end else if (ce_in) begin
            // Change settings at input frame start, during output blanking.
            if (!hblank_in && !vblank_in && x_in == 0 && y_in == 0) begin
                brightness_q <= brightness; amount_q <= amount; spread_q <= spread;
            end
            source <= {x_in,y_in,hs_in,vs_in,hblank_in,vblank_in,
                       hblank_in || vblank_in ? 9'd0 : beam_drive(gray_in,
                           x_in == 0 && y_in == 0 ? brightness : brightness_q)};
            write_addr <= addr; write_valid <= 1;
            addr <= addr == ADDR_BITS'(LINE_PIXELS-1) ? '0 : addr + 1'b1;
            if (warm < WARM_BITS'(6*LINE_PIXELS)) warm <= warm + 1'b1;
            vertical <= filter7(source.beam,r0.beam,r1.beam,r2.beam,r3.beam,r4.beam,r5.beam,spread_q);
            centre <= warm >= WARM_BITS'(3*LINE_PIXELS) ? r2 : {18'd0,4'b0011,9'd0};
            horizontal[0] <= vertical; horizontal_packet[0] <= centre;
            for (integer i=1; i<7; i=i+1) begin
                horizontal[i] <= horizontal[i-1];
                horizontal_packet[i] <= horizontal_packet[i-1];
            end
            blurred <= filter7(horizontal[0],horizontal[1],horizontal[2],horizontal[3],
                               horizontal[4],horizontal[5],horizontal[6],spread_q);
            composite_packet <= horizontal_packet[3];
            gray_out <= composite_packet.hb || composite_packet.vb ? 8'd0 :
                        energy > 10'd255 ? 8'd255 : energy[7:0];
            x_out <= composite_packet.x; y_out <= composite_packet.y;
            hs_out <= composite_packet.hs; vs_out <= composite_packet.vs;
            hblank_out <= composite_packet.hb; vblank_out <= composite_packet.vb;
        end
    end
endmodule
