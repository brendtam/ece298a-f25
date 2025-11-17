/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
`timescale 1ns/1ps

// ---------------------------------------------------------
// Top: tt_um_vga_example
// - uses sincos8_gen to place 8 bullets around a center
// - bullet positions are computed in this top module
// ---------------------------------------------------------
module tt_um_vga_example(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  reg [9:0] radius;
  reg [7:0] angle;
  parameter H_ORIGIN = 320;
  parameter V_ORIGIN = 240;
  parameter BULLET_SIZE = 10;

  wire in_pattern;
  wire border;
  wire [7:0] bullets;

  reg [9:0] counter;
  reg [8:0] deg;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  // hvsync generator (user-provided)
  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // sincos outputs (separate ports, not arrays)
  wire signed [9:0] sin0, sin1, sin2, sin3, sin4, sin5, sin6, sin7;
  wire signed [9:0] cos0, cos1, cos2, cos3, cos4, cos5, cos6, cos7;

  sincos8_gen sincos_inst (
    .clk(clk),
    .rst_n(rst_n),
    .angle_in(deg),
    .radius(radius),

    .sin0(sin0), .sin1(sin1), .sin2(sin2), .sin3(sin3),
    .sin4(sin4), .sin5(sin5), .sin6(sin6), .sin7(sin7),

    .cos0(cos0), .cos1(cos1), .cos2(cos2), .cos3(cos3),
    .cos4(cos4), .cos5(cos5), .cos6(cos6), .cos7(cos7)
  );

  // Compute absolute screen positions (signed intermediate, then abs for distance)
  reg signed [11:0] posx_s [7:0];
  reg signed [11:0] posy_s [7:0];

  // Assign positions by adding origin (X) and subtracting sine for Y (screen Y down)
  always @(*) begin
    posx_s[0] = $signed(H_ORIGIN) + $signed(cos0);
    posx_s[1] = $signed(H_ORIGIN) + $signed(cos1);
    posx_s[2] = $signed(H_ORIGIN) + $signed(cos2);
    posx_s[3] = $signed(H_ORIGIN) + $signed(cos3);
    posx_s[4] = $signed(H_ORIGIN) + $signed(cos4);
    posx_s[5] = $signed(H_ORIGIN) + $signed(cos5);
    posx_s[6] = $signed(H_ORIGIN) + $signed(cos6);
    posx_s[7] = $signed(H_ORIGIN) + $signed(cos7);

    posy_s[0] = $signed(V_ORIGIN) - $signed(sin0);
    posy_s[1] = $signed(V_ORIGIN) - $signed(sin1);
    posy_s[2] = $signed(V_ORIGIN) - $signed(sin2);
    posy_s[3] = $signed(V_ORIGIN) - $signed(sin3);
    posy_s[4] = $signed(V_ORIGIN) - $signed(sin4);
    posy_s[5] = $signed(V_ORIGIN) - $signed(sin5);
    posy_s[6] = $signed(V_ORIGIN) - $signed(sin6);
    posy_s[7] = $signed(V_ORIGIN) - $signed(sin7);
  end

  // For collision (pixel) test compute absolute differences using signed arithmetic
  genvar gi;
  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : PIXCHECK
      wire signed [11:0] dx_s = $signed(pix_x) - posx_s[gi];
      wire signed [11:0] dy_s = $signed(pix_y) - posy_s[gi];
      wire [11:0] dx = dx_s[11] ? -dx_s : dx_s;
      wire [11:0] dy = dy_s[11] ? -dy_s : dy_s;
      // diamond-ish distance used previously: (dx + dy) + min(dx,dy)/2 <= BULLET_SIZE
      wire [11:0] mn = (dx > dy) ? dy : dx;
      assign bullets[gi] = (((dx + dy) + (mn >> 1)) <= BULLET_SIZE) ? 1'b1 : 1'b0;
    end
  endgenerate

  assign in_pattern = |bullets;
  assign border = ((pix_x <= 10) || (pix_x >= 630)) || ((pix_y <= 10) || (pix_y >= 470));

  assign R = (video_active && (in_pattern || border)) ? 2'b11 : 2'b00;
  assign G = 2'b00;
  assign B = (video_active && in_pattern) ? ((border) ? 2'b00 : 2'b11) : 2'b00;

  // update radius and rotation once per vsync (one frame)
  always @(posedge vsync or negedge rst_n) begin
    if (!rst_n) begin
      radius <= 0;
      deg <= 0;
    end else begin
      if (radius >= 400) radius <= 0;
      else radius <= radius + 1;
      if (deg >= 359) deg <= 0;
      else deg <= deg + 1;
    end
  end

endmodule


// ============================================================
// 8-WAY SIN/COS GENERATOR (Verilog-2001 friendly)
// - exact mapping: idx = (deg * 128) / 360  (Option A)
// - outputs 8 separate signed 10-bit pixel offsets (no arrays)
// - internal scaling implemented with shift-add (no HW multiplier)
// ============================================================
module sincos8_gen (
    input  wire        clk,
    input  wire        rst_n,

    input  wire [8:0]  angle_in,   // 0..359 degrees
    input  wire [9:0]  radius,     // 0..400 pixels

    output reg signed [9:0] sin0,
    output reg signed [9:0] sin1,
    output reg signed [9:0] sin2,
    output reg signed [9:0] sin3,
    output reg signed [9:0] sin4,
    output reg signed [9:0] sin5,
    output reg signed [9:0] sin6,
    output reg signed [9:0] sin7,

    output reg signed [9:0] cos0,
    output reg signed [9:0] cos1,
    output reg signed [9:0] cos2,
    output reg signed [9:0] cos3,
    output reg signed [9:0] cos4,
    output reg signed [9:0] cos5,
    output reg signed [9:0] cos6,
    output reg signed [9:0] cos7
);

    // 128-entry sine table (amplitude = 64)
    reg signed [7:0] sin_lut [0:127];
    initial begin
        sin_lut[  0]=  0; sin_lut[  1]=  3; sin_lut[  2]=  6; sin_lut[  3]=  9;
        sin_lut[  4]= 12; sin_lut[  5]= 15; sin_lut[  6]= 18; sin_lut[  7]= 21;
        sin_lut[  8]= 24; sin_lut[  9]= 27; sin_lut[ 10]= 30; sin_lut[ 11]= 33;
        sin_lut[ 12]= 36; sin_lut[ 13]= 39; sin_lut[ 14]= 41; sin_lut[ 15]= 44;
        sin_lut[ 16]= 46; sin_lut[ 17]= 49; sin_lut[ 18]= 51; sin_lut[ 19]= 53;
        sin_lut[ 20]= 55; sin_lut[ 21]= 57; sin_lut[ 22]= 59; sin_lut[ 23]= 61;
        sin_lut[ 24]= 62; sin_lut[ 25]= 63; sin_lut[ 26]= 64; sin_lut[ 27]= 64;
        sin_lut[ 28]= 64; sin_lut[ 29]= 64; sin_lut[ 30]= 64; sin_lut[ 31]= 63;
        sin_lut[ 32]= 62; sin_lut[ 33]= 61; sin_lut[ 34]= 59; sin_lut[ 35]= 57;
        sin_lut[ 36]= 55; sin_lut[ 37]= 53; sin_lut[ 38]= 51; sin_lut[ 39]= 49;
        sin_lut[ 40]= 46; sin_lut[ 41]= 44; sin_lut[ 42]= 41; sin_lut[ 43]= 39;
        sin_lut[ 44]= 36; sin_lut[ 45]= 33; sin_lut[ 46]= 30; sin_lut[ 47]= 27;
        sin_lut[ 48]= 24; sin_lut[ 49]= 21; sin_lut[ 50]= 18; sin_lut[ 51]= 15;
        sin_lut[ 52]= 12; sin_lut[ 53]=  9; sin_lut[ 54]=  6; sin_lut[ 55]=  3;
        sin_lut[ 56]=  0; sin_lut[ 57]= -3; sin_lut[ 58]= -6; sin_lut[ 59]= -9;
        sin_lut[ 60]= -12; sin_lut[ 61]= -15; sin_lut[ 62]= -18; sin_lut[ 63]= -21;
        sin_lut[ 64]= -24; sin_lut[ 65]= -27; sin_lut[ 66]= -30; sin_lut[ 67]= -33;
        sin_lut[ 68]= -36; sin_lut[ 69]= -39; sin_lut[ 70]= -41; sin_lut[ 71]= -44;
        sin_lut[ 72]= -46; sin_lut[ 73]= -49; sin_lut[ 74]= -51; sin_lut[ 75]= -53;
        sin_lut[ 76]= -55; sin_lut[ 77]= -57; sin_lut[ 78]= -59; sin_lut[ 79]= -61;
        sin_lut[ 80]= -62; sin_lut[ 81]= -63; sin_lut[ 82]= -64; sin_lut[ 83]= -64;
        sin_lut[ 84]= -64; sin_lut[ 85]= -64; sin_lut[ 86]= -64; sin_lut[ 87]= -63;
        sin_lut[ 88]= -62; sin_lut[ 89]= -61; sin_lut[ 90]= -59; sin_lut[ 91]= -57;
        sin_lut[ 92]= -55; sin_lut[ 93]= -53; sin_lut[ 94]= -51; sin_lut[ 95]= -49;
        sin_lut[ 96]= -46; sin_lut[ 97]= -44; sin_lut[ 98]= -41; sin_lut[ 99]= -39;
        sin_lut[100]= -36; sin_lut[101]= -33; sin_lut[102]= -30; sin_lut[103]= -27;
        sin_lut[104]= -24; sin_lut[105]= -21; sin_lut[106]= -18; sin_lut[107]= -15;
        sin_lut[108]= -12; sin_lut[109]=  -9; sin_lut[110]=  -6; sin_lut[111]=  -3;
        sin_lut[112]=   0; sin_lut[113]=   3; sin_lut[114]=   6; sin_lut[115]=   9;
        sin_lut[116]=  12; sin_lut[117]=  15; sin_lut[118]=  18; sin_lut[119]=  21;
        sin_lut[120]=  24; sin_lut[121]=  27; sin_lut[122]=  30; sin_lut[123]=  33;
        sin_lut[124]=  36; sin_lut[125]=  39; sin_lut[126]=  41; sin_lut[127]=  44;
    end

    // Helper: exact linear mapping deg->index: idx = (deg * 128) / 360
    // We'll compute (a * 128) / 360 in an integer expression.
    // a is in 0..359, idx is in 0..127
    function [6:0] deg_to_idx_exact;
        input [8:0] a;
        integer tmp;
        begin
            tmp = (a * 128) / 360;
            deg_to_idx_exact = tmp[6:0];
        end
    endfunction

    // Shift-add scaling: (s * radius) >> 6  (amplitude 64)
    function signed [9:0] scale_shadd;
        input signed [7:0] s;
        input [9:0] r;
        reg signed [17:0] acc;
    begin
        acc = 0;
        if (r[0]) acc = acc + s;
        if (r[1]) acc = acc + (s <<< 1);
        if (r[2]) acc = acc + (s <<< 2);
        if (r[3]) acc = acc + (s <<< 3);
        if (r[4]) acc = acc + (s <<< 4);
        if (r[5]) acc = acc + (s <<< 5);
        if (r[6]) acc = acc + (s <<< 6);
        if (r[7]) acc = acc + (s <<< 7);
        if (r[8]) acc = acc + (s <<< 8);
        if (r[9]) acc = acc + (s <<< 9);
        // divide by 64
        scale_shadd = acc >>> 6;
    end
    endfunction

    // internal regs for angle computations
    reg [8:0] a0, a1, a2, a3, a4, a5, a6, a7;
    reg [6:0] idx0, idx1, idx2, idx3, idx4, idx5, idx6, idx7;
    reg signed [7:0] s0, s1, s2, s3, s4, s5, s6, s7;
    reg signed [7:0] c0, c1, c2, c3, c4, c5, c6, c7;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sin0 <= 0; sin1 <= 0; sin2 <= 0; sin3 <= 0;
            sin4 <= 0; sin5 <= 0; sin6 <= 0; sin7 <= 0;
            cos0 <= 0; cos1 <= 0; cos2 <= 0; cos3 <= 0;
            cos4 <= 0; cos5 <= 0; cos6 <= 0; cos7 <= 0;
        end else begin
            // compute 8 wrapped angles 0..359
            a0 = angle_in;
            if (a0 >= 360) a0 = a0 - 360;
            a1 = angle_in + 9'd45; if (a1 >= 360) a1 = a1 - 360;
            a2 = angle_in + 9'd90; if (a2 >= 360) a2 = a2 - 360;
            a3 = angle_in + 9'd135; if (a3 >= 360) a3 = a3 - 360;
            a4 = angle_in + 9'd180; if (a4 >= 360) a4 = a4 - 360;
            a5 = angle_in + 9'd225; if (a5 >= 360) a5 = a5 - 360;
            a6 = angle_in + 9'd270; if (a6 >= 360) a6 = a6 - 360;
            a7 = angle_in + 9'd315; if (a7 >= 360) a7 = a7 - 360;

            // compute exact indices
            idx0 = deg_to_idx_exact(a0);
            idx1 = deg_to_idx_exact(a1);
            idx2 = deg_to_idx_exact(a2);
            idx3 = deg_to_idx_exact(a3);
            idx4 = deg_to_idx_exact(a4);
            idx5 = deg_to_idx_exact(a5);
            idx6 = deg_to_idx_exact(a6);
            idx7 = deg_to_idx_exact(a7);

            // sine from table
            s0 = sin_lut[idx0];
            s1 = sin_lut[idx1];
            s2 = sin_lut[idx2];
            s3 = sin_lut[idx3];
            s4 = sin_lut[idx4];
            s5 = sin_lut[idx5];
            s6 = sin_lut[idx6];
            s7 = sin_lut[idx7];

            // cosine is sine shifted by +90deg: index + 32 (since 128 entries => 32 = 90deg)
            c0 = sin_lut[(idx0 + 7'd32) & 7'h7F];
            c1 = sin_lut[(idx1 + 7'd32) & 7'h7F];
            c2 = sin_lut[(idx2 + 7'd32) & 7'h7F];
            c3 = sin_lut[(idx3 + 7'd32) & 7'h7F];
            c4 = sin_lut[(idx4 + 7'd32) & 7'h7F];
            c5 = sin_lut[(idx5 + 7'd32) & 7'h7F];
            c6 = sin_lut[(idx6 + 7'd32) & 7'h7F];
            c7 = sin_lut[(idx7 + 7'd32) & 7'h7F];

            // scale to pixel offsets
            sin0 <= scale_shadd(s0, radius);
            sin1 <= scale_shadd(s1, radius);
            sin2 <= scale_shadd(s2, radius);
            sin3 <= scale_shadd(s3, radius);
            sin4 <= scale_shadd(s4, radius);
            sin5 <= scale_shadd(s5, radius);
            sin6 <= scale_shadd(s6, radius);
            sin7 <= scale_shadd(s7, radius);

            cos0 <= scale_shadd(c0, radius);
            cos1 <= scale_shadd(c1, radius);
            cos2 <= scale_shadd(c2, radius);
            cos3 <= scale_shadd(c3, radius);
            cos4 <= scale_shadd(c4, radius);
            cos5 <= scale_shadd(c5, radius);
            cos6 <= scale_shadd(c6, radius);
            cos7 <= scale_shadd(c7, radius);
        end
    end

endmodule
