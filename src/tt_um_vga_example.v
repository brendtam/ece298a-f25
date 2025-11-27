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
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
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

  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;
  wire _unused_ok = &{ena, ui_in, uio_in};

  reg [2:0] state = 3'b100;
  reg [5:0] counter;

  reg signed [8:0] cos_val;
  reg signed [8:0] sin_val;
  reg signed [15:0] start_u;
  reg signed [15:0] start_v;
  reg signed [15:0] row_u, row_v;
  reg signed [15:0] curr_u, curr_v;
  reg [6:0] angle_idx;
  reg [5:0] spin_speed;

  // check switch order on board
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

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      angle_idx <= 0;
      row_u <= 0; row_v <= 0;
      curr_u <= 0; curr_v <= 0;
      spin_speed <= 1;
    end else if (state[1] && ~state[0]) begin
      if (pix_y == 480 && pix_x == 640) begin
        if (angle_idx < spin_speed) begin
          spin_speed <= spin_speed + 1;
        end
        angle_idx <= angle_idx + spin_speed;
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
    end else if (state[1] && state[0]) begin
      angle_idx <= 0;
    end
  end
  wire w_done = (spin_speed == 0);

  wire signed [8:0] int_u = curr_u[15:7];
  wire signed [8:0] int_v = curr_v[15:7];

  localparam pos4 = -210;
  localparam pos3 = -210;
  localparam pos2 = 70;
  localparam pos = 70;

  localparam line_width = 20;

  wire Lo = 
      (int_u >= -60 && int_u <= 80) &&
      (pix_x >= 128 && pix_x <= 512) &&
      (int_u + (int_v<<1) >= pos3 && int_u + (int_v<<1) <= pos3+line_width);
  wire Li =
      (int_u >= -60 && int_u <= 80) &&
      (pix_x >= 128 && pix_x <= 512) &&
      (int_u - (int_v<<1) >= pos2 && int_u - (int_v<<1) <= pos2+line_width);
  wire Ri =
      (int_u >= -60 && int_u <= 80) &&
      (pix_x >= 128 && pix_x <= 512) &&
      (int_u + (int_v<<1) >= pos && int_u + (int_v<<1) <= pos+line_width);
  wire Ro =
      (int_u >= -60 && int_u <= 80) &&
      (pix_x >= 128 && pix_x <= 512) &&
      (int_u - (int_v<<1) >= pos4 && int_u - (int_v<<1) <= pos4+line_width);
  wire in_shape = (Lo || Li || Ri || Ro) && state[1];

  // U
  parameter H_ORIGIN = 320;
  parameter V_ORIGIN = 0;
  parameter BULLET_SIZE = 10;

  reg [9:0] fall_y;
  reg [8:0] shift_side;

  wire [9:0] bullet_pos_x [0:7];
  wire [9:0] bullet_pos_y [0:7];
  wire [7:0] bullets;

  localparam signed [9:0] base_x0 = -62;
  localparam signed [9:0] base_x1 = -62;
  localparam signed [9:0] base_x2 = -50;
  localparam signed [9:0] base_x3 = -18;

  localparam signed [9:0] base_y0 = 0;
  localparam signed [9:0] base_y1 = 48;
  localparam signed [9:0] base_y2 = 100;
  localparam signed [9:0] base_y3 = 120;

  genvar k;
  generate
    for (k = 0; k < 4; k = k + 1) begin
      if (k == 0) begin
        assign bullet_pos_x[k]   = H_ORIGIN + base_x0 + shift_side;
        assign bullet_pos_x[7-k] = H_ORIGIN - base_x0 - shift_side;
        assign bullet_pos_y[k]   = base_y0 + fall_y;
        assign bullet_pos_y[7-k] = base_y0 + fall_y;
      end else if (k == 1) begin
        assign bullet_pos_x[k]   = H_ORIGIN + base_x1 + (shift_side);
        assign bullet_pos_x[7-k] = H_ORIGIN - base_x1 - (shift_side);
        assign bullet_pos_y[k]   = base_y1 + fall_y;
        assign bullet_pos_y[7-k] = base_y1 + fall_y;
      end else if (k == 2) begin
        assign bullet_pos_x[k]   = H_ORIGIN + base_x2 + shift_side;
        assign bullet_pos_x[7-k] = H_ORIGIN - base_x2 - shift_side;
        assign bullet_pos_y[k]   = base_y2 + fall_y;
        assign bullet_pos_y[7-k] = base_y2 + fall_y;
      end else begin
        assign bullet_pos_x[k]   = H_ORIGIN + base_x3 + (shift_side>>1);
        assign bullet_pos_x[7-k] = H_ORIGIN - base_x3 - (shift_side>>1);
        assign bullet_pos_y[k]   = base_y3 + fall_y;
        assign bullet_pos_y[7-k] = base_y3 + fall_y;
      end
    end
  endgenerate

  reg [9:0] frame_count;
  reg [4:0] fall_speed;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      frame_count <= 0;
      fall_y <= 0;
      fall_speed <= 2;
    end else if (vsync && state[2] && ~state[0]) begin
      if (frame_count == 500) begin
        shift_side <= (fall_y < 180) ? 0 : shift_side + 1;

        if (shift_side > 500) begin
          fall_y <= 0;
        end else if (fall_y >= 180 && shift_side <= 300) begin
          fall_y <= fall_y;
        end else begin
          fall_y <= fall_y + fall_speed;
        end

        if      (fall_y < 25) fall_speed <= 10;
        else if (fall_y < 125) fall_speed <= 4;
        else                   fall_speed <= 1;
        
        frame_count <= 0;
      end else begin
        frame_count <= frame_count + 1;
      end
    end
  end

  // Render bullets
  genvar i;
  generate
    for (i = 0; i < 8; i=i+1) begin
      wire [9:0] dx = (pix_x > bullet_pos_x[i]) ? (pix_x - bullet_pos_x[i]) : (bullet_pos_x[i] - pix_x);
      wire [9:0] dy = (pix_y > bullet_pos_y[i]) ? (pix_y - bullet_pos_y[i]) : (bullet_pos_y[i] - pix_y);
      assign bullets[i] = ((dx + dy) <= BULLET_SIZE);
    end
  endgenerate

  wire in_pattern = |bullets && state[2];
  wire u_done = (shift_side > 500);

  // background
  reg [5:0] bg_shift;
  wire [9:0] shift_y = pix_y - bg_shift;
  always @(posedge vsync or negedge rst_n) begin
    if (!rst_n) begin
      bg_shift <= 0;
    end else begin
      bg_shift <= bg_shift + 3;
    end
  end

  // state
  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      state <= 0;
      counter <= 0;
    end else begin
      case (state)
        3'b010: begin // W
          if (w_done) begin
            state <= 1;
          end
        end
        3'b001: begin // W -> U
          counter <= counter + 1;
          if (counter >= 15) begin
            counter <= 0;
            state <= 5'b100;
          end
        end
        3'b100: begin // U
          if (u_done) begin
            state <= 2;
          end
        end
      default: state <= 3'b100;
      endcase
    end
  end

  // color
  assign R = ((video_active) ?
    ((in_shape || in_pattern) && ~state[0] ? 2'b11 :
    ((pix_x[5] ^ shift_y[5]) ? 2'b00 : 2'b01)) : 2'b00);
  assign G = ((video_active) ?
    ((in_shape || in_pattern) && ~state[0] ? 2'b11 :
    ((pix_x[5] ^ shift_y[5]) ? 2'b00 : 2'b01)) : 2'b00);
  assign B = ((video_active) ?
    ((in_shape || in_pattern) && ~state[0]  ? 2'b01 :
    ((pix_x[5] ^ shift_y[5]) ? 2'b00 : 2'b01)) : 2'b00);

endmodule
