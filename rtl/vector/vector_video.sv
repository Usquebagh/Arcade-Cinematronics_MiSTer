// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Segment-to-framebuffer component. Request presentation after the last
// segment of a machine frame. The handshake waits for drawing to drain.
module vector_video (
    input wire clk, reset,
    input wire line_valid,
    output wire line_ready,
    input wire signed [15:0] x0, y0, x1, y1,
    input wire [7:0] intensity,
    input wire frame_valid,
    output wire frame_ready, frame_presented,
    input wire [8:0] scan_x, scan_y,
    output wire [7:0] scan_gray,
    output wire clearing
);
    wire raster_ready, raster_busy, pixel_valid, pixel_ready;
    wire [15:0] pixel_x, pixel_y;
    wire [7:0] pixel_intensity;
    wire buffer_frame_ready;
    assign line_ready = raster_ready && !clearing;
    assign frame_ready = buffer_frame_ready && !raster_busy && !line_valid;
    vector_line line_renderer (
        .clk(clk), .reset(reset), .line_valid(line_valid && line_ready),
        .line_ready(raster_ready), .x0(x0), .y0(y0), .x1(x1), .y1(y1),
        .intensity(intensity), .pixel_valid(pixel_valid), .pixel_ready(pixel_ready),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .pixel_intensity(pixel_intensity),
        .busy(raster_busy), .done()
    );
    vector_framebuffer framebuffer (
        .clk(clk), .reset(reset), .pixel_valid(pixel_valid), .pixel_ready(pixel_ready),
        .pixel_x(pixel_x), .pixel_y(pixel_y), .pixel_intensity(pixel_intensity),
        .frame_valid(frame_valid && !raster_busy && !line_valid),
        .frame_ready(buffer_frame_ready), .frame_presented(frame_presented),
        .scan_x(scan_x), .scan_y(scan_y), .scan_gray(scan_gray), .clearing(clearing)
    );
endmodule
