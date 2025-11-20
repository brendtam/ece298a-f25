/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

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

  // --- VGA Timing ---
  wire hsync, vsync, video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // --- Trig LUT (Scale 128) ---
  // 1.0 = 128. Range: -128 to 127
  reg signed [8:0] cos_val; 
  reg signed [8:0] sin_val; 
  reg [5:0] angle_idx;
  reg [3:0] frame_counter;

  always @(*) begin
    // Using angle_idx[5:0] for 64 total steps (360/64 = 5.625 degrees per step)
    case(angle_idx) 
      // --- Quadrant 1 (0 to 90 degrees) ---
      0:  begin cos_val =  128; sin_val =    0; end // 0.00 deg
      1:  begin cos_val =  128; sin_val =   14; end // 5.63 deg
      2:  begin cos_val =  127; sin_val =   28; end // 11.25 deg
      3:  begin cos_val =  125; sin_val =   42; end // 16.88 deg
      4:  begin cos_val =  122; sin_val =   55; end // 22.50 deg
      5:  begin cos_val =  118; sin_val =   67; end // 28.13 deg
      6:  begin cos_val =  113; sin_val =   79; end // 33.75 deg
      7:  begin cos_val =  107; sin_val =   89; end // 39.38 deg
      8:  begin cos_val =   99; sin_val =   99; end // 45.00 deg
      9:  begin cos_val =   90; sin_val =  107; end // 50.63 deg
      10: begin cos_val =   79; sin_val =  113; end // 56.25 deg
      11: begin cos_val =   67; sin_val =  118; end // 61.88 deg
      12: begin cos_val =   55; sin_val =  122; end // 67.50 deg
      13: begin cos_val =   42; sin_val =  125; end // 73.13 deg
      14: begin cos_val =   28; sin_val =  127; end // 78.75 deg
      15: begin cos_val =   14; sin_val =  128; end // 84.38 deg
      16: begin cos_val =    0; sin_val =  128; end // 90.00 deg

      // --- Quadrant 2 (90 to 180 degrees) ---
      17: begin cos_val =  -14; sin_val =  128; end // 95.63 deg
      18: begin cos_val =  -28; sin_val =  127; end // 101.25 deg
      19: begin cos_val =  -42; sin_val =  125; end // 106.88 deg
      20: begin cos_val =  -55; sin_val =  122; end // 112.50 deg
      21: begin cos_val =  -67; sin_val =  118; end // 118.13 deg
      22: begin cos_val =  -79; sin_val =  113; end // 123.75 deg
      23: begin cos_val =  -89; sin_val =  107; end // 129.38 deg
      24: begin cos_val =  -99; sin_val =   99; end // 135.00 deg
      25: begin cos_val = -107; sin_val =   90; end // 140.63 deg
      26: begin cos_val = -113; sin_val =   79; end // 146.25 deg
      27: begin cos_val = -118; sin_val =   67; end // 151.88 deg
      28: begin cos_val = -122; sin_val =   55; end // 157.50 deg
      29: begin cos_val = -125; sin_val =   42; end // 163.13 deg
      30: begin cos_val = -127; sin_val =   28; end // 168.75 deg
      31: begin cos_val = -128; sin_val =   14; end // 174.38 deg
      32: begin cos_val = -128; sin_val =    0; end // 180.00 deg

      // --- Quadrant 3 (180 to 270 degrees) ---
      33: begin cos_val = -128; sin_val =  -14; end // 185.63 deg
      34: begin cos_val = -127; sin_val =  -28; end // 191.25 deg
      35: begin cos_val = -125; sin_val =  -42; end // 196.88 deg
      36: begin cos_val = -122; sin_val =  -55; end // 202.50 deg
      37: begin cos_val = -118; sin_val =  -67; end // 208.13 deg
      38: begin cos_val = -113; sin_val =  -79; end // 213.75 deg
      39: begin cos_val = -107; sin_val =  -89; end // 219.38 deg
      40: begin cos_val =  -99; sin_val =  -99; end // 225.00 deg
      41: begin cos_val =  -90; sin_val = -107; end // 230.63 deg
      42: begin cos_val =  -79; sin_val = -113; end // 236.25 deg
      43: begin cos_val =  -67; sin_val = -118; end // 241.88 deg
      44: begin cos_val =  -55; sin_val = -122; end // 247.50 deg
      45: begin cos_val =  -42; sin_val = -125; end // 253.13 deg
      46: begin cos_val =  -28; sin_val = -127; end // 258.75 deg
      47: begin cos_val =  -14; sin_val = -128; end // 264.38 deg
      48: begin cos_val =    0; sin_val = -128; end // 270.00 deg

      // --- Quadrant 4 (270 to 360 degrees) ---
      49: begin cos_val =   14; sin_val = -128; end // 275.63 deg
      50: begin cos_val =   28; sin_val = -127; end // 281.25 deg
      51: begin cos_val =   42; sin_val = -125; end // 286.88 deg
      52: begin cos_val =   55; sin_val = -122; end // 292.50 deg
      53: begin cos_val =   67; sin_val = -118; end // 298.13 deg
      54: begin cos_val =   79; sin_val = -113; end // 303.75 deg
      55: begin cos_val =   89; sin_val = -107; end // 309.38 deg
      56: begin cos_val =   99; sin_val =  -99; end // 315.00 deg
      57: begin cos_val =  107; sin_val =  -90; end // 320.63 deg
      58: begin cos_val =  113; sin_val =  -79; end // 326.25 deg
      59: begin cos_val =  118; sin_val =  -67; end // 331.88 deg
      60: begin cos_val =  122; sin_val =  -55; end // 337.50 deg
      61: begin cos_val =  125; sin_val =  -42; end // 343.13 deg
      62: begin cos_val =  127; sin_val =  -28; end // 348.75 deg
      63: begin cos_val =  128; sin_val =  -14; end // 354.38 deg
      
      default: begin cos_val = 128; sin_val = 0; end // Wraps back to 0
    endcase
end

  // --- Coordinate Mathematics ---
  // Use 24 bits to be safe. 16 integer, 8 fractional.
  reg signed [23:0] row_u, row_v;   // Position at start of current line
  reg signed [23:0] curr_u, curr_v; // Position at current pixel

  // Top-Left Corner Calculation (Frame Start)
  // We map Screen(0,0) to Texture Space relative to Center(320,240)
  // X_start = -320, Y_start = -240
  // cos_val and sin_val are signed [8:0], scale 128

  // Calculate (-320 * cos_val) and (-240 * cos_val) using shifts and adds
  // Note: We use the signed version of 320 (and 240) in the math.
  // Since we are using cos_val/sin_val directly, we use the property:
  // A * (-B) = -(A * B)

  // Helper Wires for (Value * Trig_Val) using shifts
  wire signed [17:0] cos_320 = (cos_val <<< 8) + (cos_val <<< 6); // 320 * cos_val
  wire signed [17:0] sin_320 = (sin_val <<< 8) + (sin_val <<< 6); // 320 * sin_val
  wire signed [17:0] cos_240 = (cos_val <<< 8) - (cos_val <<< 4); // 240 * cos_val
  wire signed [17:0] sin_240 = (sin_val <<< 8) - (sin_val <<< 4); // 240 * sin_val

  // start_u = (-320 * cos) - (-240 * sin) = -(320 * cos) + (240 * sin)
  wire signed [23:0] start_u = (-cos_320) + sin_240; 

  // start_v = (-320 * sin) + (-240 * cos) = -(320 * sin) - (240 * cos)
  wire signed [23:0] start_v = (-sin_320) - cos_240;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      angle_idx <= 0;
      frame_counter <= 0;
      row_u <= 0; row_v <= 0;
      curr_u <= 0; curr_v <= 0;
    end else begin

      // --- Animation Timer ---
      if (pix_y == 479 && pix_x == 639) begin
          angle_idx <= angle_idx + 1;
      end

      // --- Coordinate Updates ---
      // Priority 1: Start of Frame (Top-Left)
      if (pix_y == 0 && pix_x == 0) begin
          row_u <= start_u;
          row_v <= start_v;
          curr_u <= start_u; // Also prep current pixel
          curr_v <= start_v;
      end 
      // Priority 2: Start of Line (Reset X, Step Y)
      else if (pix_x == 0) begin
          // Calculate Next Row Start
          // Moving down in Y implies adding (-sin, cos)
          row_u <= row_u - {{15{sin_val[8]}}, sin_val}; 
          row_v <= row_v + {{15{cos_val[8]}}, cos_val};
          
          // Reset pixel pointer to the NEW row start
          curr_u <= row_u - {{15{sin_val[8]}}, sin_val};
          curr_v <= row_v + {{15{cos_val[8]}}, cos_val};
      end 
      // Priority 3: Pixel Step (Step X)
      else if (video_active) begin
          // Moving right in X implies adding (cos, sin)
          curr_u <= curr_u + {{15{cos_val[8]}}, cos_val};
          curr_v <= curr_v + {{15{sin_val[8]}}, sin_val};
      end
    end
  end

  // --- Shape Rendering ---
  // Slice bits [23:7] to get integer. (Scale 128 = 2^7)
  wire signed [16:0] int_u = curr_u[23:7];
  wire signed [16:0] int_v = curr_v[23:7];

  // T Shape Logic
  wire t_bar  = (int_u >= -40 && int_u <= 40) && (int_v >= -50 && int_v <= -30);
  wire t_stem = (int_u >= -10 && int_u <= 10) && (int_v >= -30 && int_v <=  30);
  wire in_shape = t_bar || t_stem;

  // --- Background Grid (Debug) ---
  // Draws a faint grid every 32 pixels to verify coordinate stability
  wire grid = (pix_x[4:0] == 0) || (pix_y[4:0] == 0);

  // --- Colors ---
  // Shape = White (R=11, G=11, B=11)
  // Grid  = Blue  (R=00, G=00, B=10)
  // Back  = Black
  wire [1:0] R = (video_active && in_shape) ? 2'b11 : 2'b00;
  wire [1:0] G = (video_active && in_shape) ? 2'b11 : 2'b00;
  wire [1:0] B = (video_active) ? (in_shape ? 2'b11 : (grid ? 2'b10 : 2'b00)) : 2'b00;

  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;
  wire _unused_ok = &{ena, ui_in, uio_in};

endmodule