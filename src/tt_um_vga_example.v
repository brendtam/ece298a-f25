`default_nettype none

module tt_um_vga_example(
  input wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input wire ena,
  input wire clk,
  input wire rst_n
);

  wire hsync;
  wire vsync;
  wire video_active;
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

  reg signed [8:0] cos_val;
  reg signed [8:0] sin_val;
  reg [6:0] angle_idx;

  reg signed [15:0] start_u;
  reg signed [15:0] start_v;

always @(*) begin
    case(angle_idx[6:2])
      0:  begin cos_val =  128; sin_val =    0; start_u = 16'sh6000; start_v = 16'sh8000; end
      1:  begin cos_val =  127; sin_val =   28; start_u = 16'sh9E00; start_v = 16'shF020; end
      2:  begin cos_val =  122; sin_val =   55; start_u = 16'sh9A00; start_v = 16'shE200; end
      3:  begin cos_val =  113; sin_val =   79; start_u = 16'sh8D00; start_v = 16'shD200; end
      4:  begin cos_val =   99; sin_val =   99; start_u = 16'sh8400; start_v = 16'shC300; end
      5:  begin cos_val =   79; sin_val =  113; start_u = 16'sh6300; start_v = 16'shB400; end
      6:  begin cos_val =   55; sin_val =  122; start_u = 16'sh4500; start_v = 16'shA600; end
      7:  begin cos_val =   28; sin_val =  127; start_u = 16'shDE00; start_v = 16'sh9800; end
      8:  begin cos_val =    0; sin_val =  128; start_u = 16'sh0000; start_v = 16'sh8000; end
      9:  begin cos_val =  -28; sin_val =  127; start_u = 16'sh2200; start_v = 16'sh9800; end
      10: begin cos_val =  -55; sin_val =  122; start_u = 16'sh4E00; start_v = 16'shA600; end
      11: begin cos_val =  -79; sin_val =  113; start_u = 16'sh9D00; start_v = 16'shB400; end
      12: begin cos_val =  -99; sin_val =   99; start_u = 16'sh7C00; start_v = 16'shC300; end
      13: begin cos_val = -113; sin_val =   79; start_u = 16'sh7200; start_v = 16'shD200; end
      14: begin cos_val = -122; sin_val =   55; start_u = 16'sh5E00; start_v = 16'shE200; end
      15: begin cos_val = -127; sin_val =   28; start_u = 16'sh6200; start_v = 16'shF020; end
      16: begin cos_val = -128; sin_val =    0; start_u = 16'sh6000; start_v = 16'sh8000; end
      17: begin cos_val = -127; sin_val =  -28; start_u = 16'sh6200; start_v = 16'sh7FE0; end
      18: begin cos_val = -122; sin_val =  -55; start_u = 16'sh5E00; start_v = 16'sh1E00; end
      19: begin cos_val = -113; sin_val =  -79; start_u = 16'sh7200; start_v = 16'sh2E00; end
      20: begin cos_val =  -99; sin_val =  -99; start_u = 16'sh7C00; start_v = 16'sh3D00; end
      21: begin cos_val =  -79; sin_val = -113; start_u = 16'sh9D00; start_v = 16'sh4C00; end
      22: begin cos_val =  -55; sin_val = -122; start_u = 16'sh4E00; start_v = 16'sh5A00; end
      23: begin cos_val =  -28; sin_val = -127; start_u = 16'sh2200; start_v = 16'sh6800; end
      24: begin cos_val =    0; sin_val = -128; start_u = 16'sh0000; start_v = 16'sh8000; end
      25: begin cos_val =   28; sin_val = -127; start_u = 16'shDE00; start_v = 16'sh6800; end
      26: begin cos_val =   55; sin_val = -122; start_u = 16'sh4500; start_v = 16'sh5A00; end
      27: begin cos_val =   79; sin_val = -113; start_u = 16'sh6300; start_v = 16'sh4C00; end
      28: begin cos_val =   99; sin_val =  -99; start_u = 16'sh8400; start_v = 16'sh3D00; end
      29: begin cos_val =  113; sin_val =  -79; start_u = 16'sh8D00; start_v = 16'sh2E00; end
      30: begin cos_val =  122; sin_val =  -55; start_u = 16'sh9A00; start_v = 16'sh1E00; end
      31: begin cos_val =  127; sin_val =  -28; start_u = 16'sh9E00; start_v = 16'sh7FE0; end
      default: begin cos_val = 128; sin_val = 0; start_u = 16'sh6000; start_v = 16'sh8000; end
    endcase
end

  reg signed [15:0] row_u, row_v;
  reg signed [15:0] curr_u, curr_v;

  reg [5:0] speed;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      angle_idx <= 0;
      row_u <= 0; row_v <= 0;
      curr_u <= 0; curr_v <= 0;
      speed <= 1;
    end else begin
      if (pix_y == 479 && pix_x == 639) begin
        if (angle_idx + speed < angle_idx) begin
          speed <= speed + 1;
        end
        angle_idx <= angle_idx + speed;
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
          row_u <= row_u - {{7{sin_val[8]}}, sin_val}; 
          row_v <= row_v + {{7{cos_val[8]}}, cos_val};
          
          // Reset pixel pointer to the NEW row start
          curr_u <= row_u - {{7{sin_val[8]}}, sin_val};
          curr_v <= row_v + {{7{cos_val[8]}}, cos_val};
      end 
      // Priority 3: Pixel Step (Step X)
      else if (video_active) begin
          // Moving right in X implies adding (cos, sin)
          curr_u <= curr_u + {{7{cos_val[8]}}, cos_val};
          curr_v <= curr_v + {{7{sin_val[8]}}, sin_val};
      end
    end
  end

  wire signed [8:0] int_u = curr_u[15:7];
  wire signed [8:0] int_v = curr_v[15:7];

  wire t_bar  = (int_u >= -40 && int_u <= 40) && (int_v >= -50 && int_v <= -30);
  wire t_stem = (int_u >= -10 && int_u <= 10) && (int_v >= -30 && int_v <=  30);
  wire in_shape = (t_bar || t_stem) && speed;

  wire [1:0] R = (video_active && in_shape) ? 2'b11 : 2'b00;
  wire [1:0] G = (video_active && in_shape) ? 2'b11 : 2'b00;
  wire [1:0] B = (video_active && in_shape) ? 2'b11 : 2'b00;

  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;
  wire _unused_ok = &{ena, ui_in, uio_in};

endmodule