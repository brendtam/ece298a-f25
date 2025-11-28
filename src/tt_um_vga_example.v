`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire ena,
  input  wire clk,
  input  wire rst_n
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R, G, B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;
  wire [9:0] screen_w;
  wire [9:0] screen_h;

  // Screen size parameters
  assign screen_w = 640;
  assign screen_h = 480;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;
  wire _unused_ok = &{ena, ui_in, uio_in};

  // State machine
  reg state;
  localparam STATE_U = 0;
  localparam STATE_W = 1;

  // U/W animation
  reg signed [8:0] cos_val;
  reg signed [8:0] sin_val;
  reg signed [15:0] start_u;
  reg signed [15:0] start_v;
  reg signed [15:0] row_u, row_v;
  reg signed [15:0] curr_u, curr_v;
  reg [6:0] angle_idx;
  reg [3:0] spin_speed;

  wire [1:0] spin_option = {ui_in[0], ui_in[1]};

  always @(*) begin
    case(angle_idx[5:2])
      0:  begin cos_val =  128; sin_val =    0; start_u = -40960; start_v = -30720; end
      1:  begin cos_val =  127; sin_val =   28; start_u = -33920; start_v = -39440; end
      2:  begin cos_val =  122; sin_val =   55; start_u = -25840; start_v = -46880; end
      3:  begin cos_val =  113; sin_val =   79; start_u = -17200; start_v = -52400; end
      4:  begin cos_val =   99; sin_val =   99; start_u =  -7920; start_v = -55440; end
      5:  begin cos_val =   79; sin_val =  113; start_u =   1840; start_v = -55120; end
      6:  begin cos_val =   55; sin_val =  122; start_u =  11680; start_v = -52240; end
      7:  begin cos_val =   28; sin_val =  127; start_u =  21520; start_v = -47360; end
      8:  begin cos_val =    0; sin_val =  128; start_u =  30720; start_v = -40960; end
      9:  begin cos_val =  -28; sin_val =  127; start_u =  39440; start_v = -33920; end
      10: begin cos_val =  -55; sin_val =  122; start_u =  46880; start_v = -25840; end
      11: begin cos_val =  -79; sin_val =  113; start_u =  52400; start_v = -17200; end
      12: begin cos_val =  -99; sin_val =   99; start_u =  55440; start_v =  -7920; end
      13: begin cos_val = -113; sin_val =   79; start_u =  55120; start_v =   1840; end
      14: begin cos_val = -122; sin_val =   55; start_u =  52240; start_v =  11680; end
      15: begin cos_val = -127; sin_val =   28; start_u =  47360; start_v =  21520; end
      default: begin cos_val = 128; sin_val = 0; start_u = -40960; start_v = -30720; end
    endcase
  end

  // W-state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      angle_idx <= 0;
      row_u <= 0; row_v <= 0;
      curr_u <= 0; curr_v <= 0;
      spin_speed <= 1;
    end else if (state == STATE_W) begin
      if (pix_y == screen_h && pix_x == screen_w) begin
        if (angle_idx < 6) spin_speed <= spin_speed + 1;
        angle_idx <= angle_idx + 6;
        if (spin_speed == 0) begin
          angle_idx <= 0;
          row_u <= 0; row_v <= 0;
          curr_u <= 0; curr_v <= 0;
          spin_speed <= 1;
        end
      end

      if (pix_y == 0 && pix_x == 0) begin
        if (angle_idx[6]) begin
          row_u <= -start_u;
          row_v <= -start_v;
          curr_u <= -start_u;
          curr_v <= -start_v;
        end else begin
          row_u <= start_u;
          row_v <= start_v;
          curr_u <= start_u;
          curr_v <= start_v;
        end
      end
      else if (pix_x == 0) begin
        if (angle_idx[6]) begin
          row_u <= row_u + sin_val;
          row_v <= row_v - cos_val;
          curr_u <= row_u + sin_val;
          curr_v <= row_v - cos_val;
        end else begin
          row_u <= row_u - sin_val;
          row_v <= row_v + cos_val;
          curr_u <= row_u - sin_val;
          curr_v <= row_v + cos_val;
        end
      end
      else if (video_active) begin
        if (angle_idx[6]) begin
          curr_u <= curr_u - cos_val;
          curr_v <= curr_v - sin_val;
        end else begin
          curr_u <= curr_u + cos_val;
          curr_v <= curr_v + sin_val;
        end
      end
    end
  end

  wire w_done = (spin_speed == 0);
  wire signed [8:0] int_u = curr_u[15:7];
  wire signed [8:0] int_v = curr_v[15:7];

  // Adaptive scaling factors
  wire [9:0] scale_x = screen_w / 320;
  wire [9:0] scale_y = screen_h / 240;

  // Edge lines (scaled)
  localparam pos4_0 = -105;
  localparam pos3_0 = -105;
  localparam pos2_0 = 35;
  localparam pos_0  = 35;
  localparam line_width_0 = 10;

  wire Lo = 
      (int_u >= -30 && int_u <= 40) &&
      (pix_x >= (64*scale_x) && pix_x <= (256*scale_x)) &&
      (int_u + (int_v<<1) >= pos3_0 && int_u + (int_v<<1) <= pos3_0+line_width_0);
  wire Li =
      (int_u >= -30 && int_u <= 40) &&
      (pix_x >= (64*scale_x) && pix_x <= (256*scale_x)) &&
      (int_u - (int_v<<1) >= pos2_0 && int_u - (int_v<<1) <= pos2_0+line_width_0);
  wire Ri =
      (int_u >= -30 && int_u <= 40) &&
      (pix_x >= (64*scale_x) && pix_x <= (256*scale_x)) &&
      (int_u + (int_v<<1) >= pos_0 && int_u + (int_v<<1) <= pos_0+line_width_0);
  wire Ro =
      (int_u >= -30 && int_u <= 40) &&
      (pix_x >= (64*scale_x) && pix_x <= (256*scale_x)) &&
      (int_u - (int_v<<1) >= pos4_0 && int_u - (int_v<<1) <= pos4_0+line_width_0);
  wire in_shape = (Lo || Li || Ri || Ro) && state == STATE_W;

  // U-state bullets
  wire [9:0] H_ORIGIN = screen_w / 2;
  localparam BULLET_SIZE = 5;

  wire [9:0] bullet_pos_x [0:7];
  wire [9:0] bullet_pos_y [0:7];
  wire [7:0] bullets;

  localparam signed [9:0] base_x0 = -31;
  localparam signed [9:0] base_x1 = -31;
  localparam signed [9:0] base_x2 = -25;
  localparam signed [9:0] base_x3 = -9;

  localparam signed [9:0] base_y0 = 0;
  localparam signed [9:0] base_y1 = 24;
  localparam signed [9:0] base_y2 = 50;
  localparam signed [9:0] base_y3 = 60;

  genvar k;
  generate
    for (k = 0; k < 4; k = k + 1) begin : bullets_gen
      if (k == 0) begin
        assign bullet_pos_x[k]   = H_ORIGIN + base_x0*scale_x + shift_side;
        assign bullet_pos_x[7-k] = H_ORIGIN - base_x0*scale_x - shift_side;
        assign bullet_pos_y[k]   = base_y0*scale_y + fall_y;
        assign bullet_pos_y[7-k] = base_y0*scale_y + fall_y;
      end else if (k == 1) begin
        assign bullet_pos_x[k]   = H_ORIGIN + base_x1*scale_x + shift_side;
        assign bullet_pos_x[7-k] = H_ORIGIN - base_x1*scale_x - shift_side;
        assign bullet_pos_y[k]   = base_y1*scale_y + fall_y;
        assign bullet_pos_y[7-k] = base_y1*scale_y + fall_y;
      end else if (k == 2) begin
        assign bullet_pos_x[k]   = H_ORIGIN + base_x2*scale_x + shift_side;
        assign bullet_pos_x[7-k] = H_ORIGIN - base_x2*scale_x - shift_side;
        assign bullet_pos_y[k]   = base_y2*scale_y + fall_y;
        assign bullet_pos_y[7-k] = base_y2*scale_y + fall_y;
      end else begin
        assign bullet_pos_x[k]   = H_ORIGIN + base_x3*scale_x + shift_side;
        assign bullet_pos_x[7-k] = H_ORIGIN - base_x3*scale_x - shift_side;
        assign bullet_pos_y[k]   = base_y3*scale_y + fall_y;
        assign bullet_pos_y[7-k] = base_y3*scale_y + fall_y;
      end
    end
  endgenerate

  // Frame counter for U-state
  reg [9:0] frame_count;
  reg [4:0] fall_speed;
  reg [8:0] shift_side;
  reg [9:0] fall_y;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      frame_count <= 0;
      fall_y <= 0;
      fall_speed <= 2;
      shift_side <= 0;
    end else if (vsync) begin
      frame_count <= frame_count + 1;
      if (frame_count >= 800) begin
        frame_count <= 0;

        if (fall_y < screen_h/2) fall_y <= fall_y + fall_speed;
        if (fall_y >= screen_h/4) shift_side <= shift_side + 1;

        if      (fall_y < screen_h/10) fall_speed <= 5;
        else if (fall_y < screen_h/2)  fall_speed <= 2;
        else                             fall_speed <= 1;
      end
    end
  end

  // Render bullets
  genvar i;
  generate
    for (i = 0; i < 8; i=i+1) begin : render_bullets
      wire [9:0] dx = (pix_x > bullet_pos_x[i]) ? (pix_x - bullet_pos_x[i]) : (bullet_pos_x[i] - pix_x);
      wire [9:0] dy = (pix_y > bullet_pos_y[i]) ? (pix_y - bullet_pos_y[i]) : (bullet_pos_y[i] - pix_y);
      assign bullets[i] = ((dx + dy) <= BULLET_SIZE);
    end
  endgenerate

  wire in_pattern = |bullets && state == STATE_U;
  wire u_done = (shift_side > (screen_w/2 + 100));

  // Background scroll
  reg [5:0] bg_shift;
  wire [9:0] shift_y = pix_y - bg_shift;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) bg_shift <= 0;
    else if (vsync) bg_shift <= bg_shift + 1;
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) state <= STATE_U;
    else begin
      case (state)
        STATE_U: if (u_done) state <= STATE_W;
        STATE_W: if (w_done) state <= STATE_U;
      endcase
    end
  end

  // Color output
  wire valid = in_shape || in_pattern;
  wire checkerboard = pix_x[4] ^ shift_y[4];
  assign R = ((video_active) ?
    ((valid) ? 2'b11 :
    ((checkerboard) ? 2'b00 : 2'b01)) : 2'b00);
  assign G = ((video_active) ?
    ((valid) ? 2'b11 :
    ((checkerboard) ? 2'b00 : 2'b01)) : 2'b00);
  assign B = ((video_active) ?
    ((valid) ? 2'b01 :
    ((checkerboard) ? 2'b00 : 2'b01)) : 2'b00);

endmodule
