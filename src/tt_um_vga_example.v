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

  always @(*) begin
    case(angle_idx[6:2])
      0:  begin cos_val =  128; sin_val =    0; end
      1:  begin cos_val =  127; sin_val =   28; end
      2:  begin cos_val =  122; sin_val =   55; end
      3:  begin cos_val =  113; sin_val =   79; end
      4:  begin cos_val =   99; sin_val =   99; end
      5:  begin cos_val =   79; sin_val =  113; end
      6:  begin cos_val =   55; sin_val =  122; end
      7:  begin cos_val =   28; sin_val =  127; end
      8:  begin cos_val =    0; sin_val =  128; end
      9:  begin cos_val =  -28; sin_val =  127; end
      10: begin cos_val =  -55; sin_val =  122; end
      11: begin cos_val =  -79; sin_val =  113; end
      12: begin cos_val =  -99; sin_val =   99; end
      13: begin cos_val = -113; sin_val =   79; end
      14: begin cos_val = -122; sin_val =   55; end
      15: begin cos_val = -127; sin_val =   28; end
      16: begin cos_val = -128; sin_val =    0; end
      17: begin cos_val = -127; sin_val =  -28; end
      18: begin cos_val = -122; sin_val =  -55; end
      19: begin cos_val = -113; sin_val =  -79; end
      20: begin cos_val =  -99; sin_val =  -99; end
      21: begin cos_val =  -79; sin_val = -113; end
      22: begin cos_val =  -55; sin_val = -122; end
      23: begin cos_val =  -28; sin_val = -127; end
      24: begin cos_val =    0; sin_val = -128; end
      25: begin cos_val =   28; sin_val = -127; end
      26: begin cos_val =   55; sin_val = -122; end
      27: begin cos_val =   79; sin_val = -113; end
      28: begin cos_val =   99; sin_val =  -99; end
      29: begin cos_val =  113; sin_val =  -79; end
      30: begin cos_val =  122; sin_val =  -55; end
      31: begin cos_val =  127; sin_val =  -28; end
      default: begin cos_val = 128; sin_val = 0; end
    endcase
  end

  reg signed [15:0] row_u, row_v;
  reg signed [15:0] curr_u, curr_v;

  wire signed [15:0] cos_320 = (cos_val << 8) + (cos_val << 6);
  wire signed [15:0] sin_320 = (sin_val << 8) + (sin_val << 6);
  wire signed [15:0] cos_240 = (cos_val << 8) - (cos_val << 4);
  wire signed [15:0] sin_240 = (sin_val << 8) - (sin_val << 4);

  wire signed [15:0] start_u = (-cos_320) + sin_240;
  wire signed [15:0] start_v = (-sin_320) - cos_240;

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

      if (pix_y == 0 && pix_x == 0) begin
          row_u <= start_u;
          row_v <= start_v;
          curr_u <= start_u;
          curr_v <= start_v;
      end
      else if (pix_x == 0) begin
          // add (-sin, cos)
          row_u <= row_u - {{7{sin_val[8]}}, sin_val};
          row_v <= row_v + {{7{cos_val[8]}}, cos_val};

          curr_u <= row_u - {{7{sin_val[8]}}, sin_val};
          curr_v <= row_v + {{7{cos_val[8]}}, cos_val};
      end
      else if (video_active) begin
          // add (cos, sin)
          curr_u <= curr_u + {{7{cos_val[8]}}, cos_val};
          curr_v <= curr_v + {{7{sin_val[8]}}, sin_val};
      end
    end
  end

  wire signed [8:0] int_u = curr_u[15:7];
  wire signed [8:0] int_v = curr_v[15:7];

  wire t_bar  = (int_u >= -40 && int_u <= 40) && (int_v >= -50 && int_v <= -30);
  wire t_stem = (int_u >= -10 && int_u <= 10) && (int_v >= -30 && int_v <= 30);
  wire in_shape = (t_bar || t_stem) && speed;

  wire [1:0] R = (video_active && in_shape) ? 2'b11 : 2'b00;
  wire [1:0] G = (video_active && in_shape) ? 2'b11 : 2'b00;
  wire [1:0] B = (video_active && in_shape) ? 2'b11 : 2'b00;

  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;
  wire _unused_ok = &{ena, ui_in, uio_in};

endmodule