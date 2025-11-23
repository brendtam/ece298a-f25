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

  reg signed [15:0] cos_val;
  reg signed [15:0] sin_val;
  reg [6:0] angle_idx;

  reg signed [15:0] start_u;
  reg signed [15:0] start_v;

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

always @(*) begin
    case(angle_idx[6:2])
      // Quadrant 1 (approx)
      0:  begin start_u = -40960; start_v = -30720; end // cos=128, sin=0
      1:  begin start_u = -33920; start_v = -39440; end // cos=127, sin=28
      2:  begin start_u = -25840; start_v = -46880; end // cos=122, sin=55
      3:  begin start_u = -17200; start_v = -52400; end // cos=113, sin=79
      4:  begin start_u =  -7920; start_v = -55440; end // cos=99,  sin=99
      5:  begin start_u =   1840; start_v = -55120; end // cos=79,  sin=113
      6:  begin start_u =  11680; start_v = -52240; end // cos=55,  sin=122
      7:  begin start_u =  21520; start_v = -47360; end // cos=28,  sin=127
      
      // Quadrant 2
      8:  begin start_u =  30720; start_v = -40960; end // cos=0,   sin=128
      9:  begin start_u =  39440; start_v = -33920; end // cos=-28, sin=127
      10: begin start_u =  46880; start_v = -25840; end // cos=-55, sin=122
      11: begin start_u =  52400; start_v = -17200; end // cos=-79, sin=113
      12: begin start_u =  55440; start_v =  -7920; end // cos=-99, sin=99
      13: begin start_u =  55120; start_v =   1840; end // cos=-113,sin=79
      14: begin start_u =  52240; start_v =  11680; end // cos=-122,sin=55
      15: begin start_u =  47360; start_v =  21520; end // cos=-127,sin=28

      // Quadrant 3
      16: begin start_u =  40960; start_v =  30720; end // cos=-128,sin=0
      17: begin start_u =  33920; start_v =  39440; end // cos=-127,sin=-28
      18: begin start_u =  25840; start_v =  46880; end // cos=-122,sin=-55
      19: begin start_u =  17200; start_v =  52400; end // cos=-113,sin=-79
      20: begin start_u =   7920; start_v =  55440; end // cos=-99, sin=-99
      21: begin start_u =  -1840; start_v =  55120; end // cos=-79, sin=-113
      22: begin start_u = -11680; start_v =  52240; end // cos=-55, sin=-122
      23: begin start_u = -21520; start_v =  47360; end // cos=-28, sin=-127

      // Quadrant 4
      24: begin start_u = -30720; start_v =  40960; end // cos=0,   sin=-128
      25: begin start_u = -39440; start_v =  33920; end // cos=28,  sin=-127
      26: begin start_u = -46880; start_v =  25840; end // cos=55,  sin=-122
      27: begin start_u = -52400; start_v =  17200; end // cos=79,  sin=-113
      28: begin start_u = -55440; start_v =   7920; end // cos=99,  sin=-99
      29: begin start_u = -55120; start_v =  -1840; end // cos=113, sin=-79
      30: begin start_u = -52240; start_v = -11680; end // cos=122, sin=-55
      31: begin start_u = -47360; start_v = -21520; end // cos=127, sin=-28

      default: begin start_u = -40960; start_v = -30720; end
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
          row_u <= row_u - sin_val; 
          row_v <= row_v + cos_val;
          
          // Reset pixel pointer to the NEW row start
          curr_u <= row_u - sin_val;
          curr_v <= row_v + cos_val;
      end 
      // Priority 3: Pixel Step (Step X)
      else if (video_active) begin
          // Moving right in X implies adding (cos, sin)
          curr_u <= curr_u + cos_val;
          curr_v <= curr_v + sin_val;
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