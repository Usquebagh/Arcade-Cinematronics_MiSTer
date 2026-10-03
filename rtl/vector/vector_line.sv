// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Usquebagh
// Integer Bresenham rasterizer. Coordinates are signed native CCPU positions;
// the default viewport is 512x384 at half the native 1024x768 resolution.
// Clipping suppresses off-screen pixels without changing the line's slope.
module vector_line #(
    parameter integer WIDTH = 512,
    parameter integer HEIGHT = 384,
    parameter integer SCALE_SHIFT = 1
) (
    input wire clk, reset,
    input wire line_valid,
    output wire line_ready,
    input wire signed [15:0] x0, y0, x1, y1,
    input wire [7:0] intensity,
    output wire pixel_valid,
    input wire pixel_ready,
    output wire [15:0] pixel_x, pixel_y,
    output wire [7:0] pixel_intensity,
    output logic busy,
    output logic done
);
    logic signed [16:0] px, py, tx, ty, dx, dy;
    logic signed [17:0] error;
    wire signed [18:0] twice_error = {error,1'b0};
    logic step_x_positive, step_y_positive;
    logic [7:0] brightness;
    wire signed [16:0] start_x = $signed({x0[15],x0}) >>> SCALE_SHIFT;
    wire signed [16:0] start_y = $signed({y0[15],y0}) >>> SCALE_SHIFT;
    wire signed [16:0] end_x = $signed({x1[15],x1}) >>> SCALE_SHIFT;
    wire signed [16:0] end_y = $signed({y1[15],y1}) >>> SCALE_SHIFT;
    wire signed [16:0] distance_x = end_x >= start_x ? end_x-start_x : start_x-end_x;
    wire signed [16:0] distance_y = end_y >= start_y ? end_y-start_y : start_y-end_y;
    localparam signed [16:0] VIEW_WIDTH = 17'(WIDTH), VIEW_HEIGHT = 17'(HEIGHT);
    wire signed [18:0] wide_dx = {{2{dx[16]}},dx};
    wire signed [18:0] wide_dy = {{2{dy[16]}},dy};
    wire visible = px >= 0 && px < VIEW_WIDTH && py >= 0 && py < VIEW_HEIGHT;
    wire rejected = (start_x < 0 && end_x < 0) ||
                    (start_y < 0 && end_y < 0) ||
                    (start_x >= VIEW_WIDTH && end_x >= VIEW_WIDTH) ||
                    (start_y >= VIEW_HEIGHT && end_y >= VIEW_HEIGHT);
    assign line_ready = !busy;
    assign pixel_valid = busy && visible;
    assign pixel_x = px[15:0];
    assign pixel_y = py[15:0];
    assign pixel_intensity = brightness;
    always_ff @(posedge clk) begin
        done <= 1'b0;
        if (reset) begin
            busy <= 0; done <= 0;
            px <= 0; py <= 0; tx <= 0; ty <= 0;
            dx <= 0; dy <= 0; error <= 0;
            step_x_positive <= 0; step_y_positive <= 0; brightness <= 0;
        end else if (line_valid && line_ready) begin
            px <= start_x; py <= start_y; tx <= end_x; ty <= end_y;
            dx <= distance_x; dy <= -distance_y;
            error <= $signed({distance_x[16],distance_x}) - $signed({distance_y[16],distance_y});
            step_x_positive <= start_x < end_x; step_y_positive <= start_y < end_y;
            brightness <= intensity;
            busy <= !rejected;
            if (rejected) done <= 1'b1;
        end else if (busy && (!visible || pixel_ready)) begin
            if (px == tx && py == ty) begin busy <= 0; done <= 1'b1; end
            else begin
                if (twice_error >= wide_dy && twice_error <= wide_dx) begin
                    error <= error + $signed(dx) + $signed(dy);
                    px <= step_x_positive ? px+17'sd1 : px-17'sd1;
                    py <= step_y_positive ? py+17'sd1 : py-17'sd1;
                end else if (twice_error >= wide_dy) begin
                    error <= error + $signed(dy);
                    px <= step_x_positive ? px+17'sd1 : px-17'sd1;
                end else if (twice_error <= wide_dx) begin
                    error <= error + $signed(dx);
                    py <= step_y_positive ? py+17'sd1 : py-17'sd1;
                end
            end
        end
    end
endmodule
