// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Two 512x512 physical banks, with a 512x384 visible viewport, 4 bits/pixel.
// The draw bank is cleared after a swap; scanout always reads the other bank.
module vector_framebuffer (
    input wire clk, reset,
    input wire pixel_valid,
    output wire pixel_ready,
    input wire [15:0] pixel_x, pixel_y,
    input wire [7:0] pixel_intensity,
    input wire frame_valid,
    output wire frame_ready,
    output logic frame_presented,
    input wire [8:0] scan_x, scan_y,
    output wire [7:0] scan_gray,
    output wire clearing
);
    typedef enum logic [1:0] {INITIALIZE, IDLE, WRITE_PIXEL, CLEAR_DRAW} state_t;
    state_t state;
    // Four adjacent pixels per word avoids wasting most of each M10K block.
    logic [15:0] bank0 [0:65535];
    logic [15:0] bank1 [0:65535];
    logic [16:0] clear_address, write_address;
    logic [15:0] read_word0, read_word1;
    logic [3:0] new_pixel;
    logic [1:0] write_lane, scan_lane;
    wire [3:0] old_pixel = old_word[{write_lane,2'b00} +: 4];
    wire [3:0] scan_pixel = scan_word[{scan_lane,2'b00} +: 4];
    logic draw_bank;
    logic scan_bank;
    wire [15:0] old_word = draw_bank ? read_word1 : read_word0;
    wire [15:0] scan_word = scan_bank ? read_word1 : read_word0;
    logic scan_visible;
    logic [16:0] draw_address;
    logic memory_write;
    logic [15:0] memory_data;
    wire in_view = pixel_x < 16'd512 && pixel_y < 16'd384;
    assign clearing = state == INITIALIZE || state == CLEAR_DRAW;
    assign pixel_ready = state == IDLE && !frame_valid;
    assign frame_ready = state == IDLE && !pixel_valid;
    assign scan_gray = scan_visible ? {scan_pixel,scan_pixel} : 8'd0;
    always_comb begin
        draw_address = write_address;
        memory_write = 0;
        memory_data = 0;
        if (state == INITIALIZE || state == CLEAR_DRAW) begin
            draw_address = clear_address;
            memory_write = !reset;
        end else if (state == IDLE) begin
            draw_address = {draw_bank,pixel_y[8:0],pixel_x[8:2]};
        end else if (state == WRITE_PIXEL) begin
            memory_write = !reset;
            memory_data = old_word;
            memory_data[{write_lane,2'b00} +: 4] = old_pixel > new_pixel ? old_pixel : new_pixel;
        end
    end
    wire [15:0] scan_address = {scan_y,scan_x[8:2]};
    wire [15:0] read_address0 = draw_bank ? scan_address : draw_address[15:0];
    wire [15:0] read_address1 = draw_bank ? draw_address[15:0] : scan_address;
    // Drawing and scanout use opposite banks, so each bank needs only one
    // read port. Avoid the duplicated RAM inferred for a three-port array.
    always_ff @(posedge clk) begin
        read_word0 <= bank0[read_address0];
        if (memory_write && !draw_address[16]) bank0[draw_address[15:0]] <= memory_data;
    end
    always_ff @(posedge clk) begin
        read_word1 <= bank1[read_address1];
        if (memory_write && draw_address[16]) bank1[draw_address[15:0]] <= memory_data;
    end
    // Single clock synchronous scanout, independent of the drawing port.
    always_ff @(posedge clk) begin
        scan_bank <= !draw_bank;
        scan_lane <= scan_x[1:0];
        scan_visible <= scan_y < 9'd384;
    end
    always_ff @(posedge clk) begin
        frame_presented <= 0;
        if (reset) begin
            state <= INITIALIZE; clear_address <= 0; draw_bank <= 0;
            write_address <= 0; new_pixel <= 0; write_lane <= 0;
            frame_presented <= 0;
        end else begin
            case (state)
                INITIALIZE: begin
                    if (clear_address == 17'h1ffff) state <= IDLE;
                    else clear_address <= clear_address + 17'd1;
                end
                IDLE: begin
                    if (frame_valid && frame_ready) begin
                        draw_bank <= !draw_bank;
                        // The old display bank becomes the new drawing bank.
                        clear_address <= {!draw_bank,16'd0};
                        state <= CLEAR_DRAW; frame_presented <= 1;
                    end else if (pixel_valid && pixel_ready && in_view) begin
                        write_address <= {draw_bank,pixel_y[8:0],pixel_x[8:2]};
                        write_lane <= pixel_x[1:0];
                        new_pixel <= pixel_intensity[7:4];
                        state <= WRITE_PIXEL;
                    end
                end
                WRITE_PIXEL: begin
                    state <= IDLE;
                end
                CLEAR_DRAW: begin
                    if (clear_address[15:0] == 16'd49151) state <= IDLE;
                    else clear_address <= clear_address + 17'd1;
                end
                default: state <= INITIALIZE;
            endcase
        end
    end
endmodule
