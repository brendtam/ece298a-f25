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

  reg [4:0] state;
  reg [7:0] counter;

  // T
  reg signed [8:0] cos_val;
  reg signed [8:0] sin_val;
  reg signed [15:0] start_u;
  reg signed [15:0] start_v;
  reg signed [15:0] row_u, row_v;
  reg signed [15:0] curr_u, curr_v;
  reg [6:0] angle_idx;
  reg [5:0] spin_speed;

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
          //state[0] <= state[0] ^ 1;
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
  wire t_done = (spin_speed == 0);

  wire signed [8:0] int_u = curr_u[15:7];
  wire signed [8:0] int_v = curr_v[15:7];

  wire t_bar  = (int_u >= -40 && int_u <= 40) && (int_v >= -50 && int_v <= -30);
  wire t_stem = (int_u >= -10 && int_u <= 10) && (int_v >= -30 && int_v <= 30);
  wire t_active = (t_bar || t_stem) && state[1];

  // L
  parameter H_ORIGIN_L = 290;
  parameter V_ORIGIN_L = 340;

  reg [5:0] l_counter = 1;
  reg [1:0] l_state = 0;
  reg [4:0] l_thickness = 1;
  reg l_visible = 1;
  wire part1 = ((pix_x <= H_ORIGIN_L + l_thickness) && (pix_x >= H_ORIGIN_L - l_thickness)) &&
    ((pix_y <= V_ORIGIN_L + l_thickness) && (pix_y >= (V_ORIGIN_L - 200) - (l_thickness<<1)));
  wire part1_outer = ((pix_x <= H_ORIGIN_L + (l_thickness<<1)) && (pix_x >= H_ORIGIN_L - (l_thickness<<1))) &&
    ((pix_y <= V_ORIGIN_L + (l_thickness<<1)) && (pix_y >= (V_ORIGIN_L - 200) - (l_thickness<<2) + (l_thickness>>1) + (l_thickness>>2) + 2));
  wire part2 = ((pix_x <= (H_ORIGIN_L + 100) + l_thickness) && (pix_x >= H_ORIGIN_L - l_thickness)) &&
    ((pix_y <= V_ORIGIN_L + l_thickness) && (pix_y >= V_ORIGIN_L - l_thickness));
  wire part2_outer = ((pix_x <= (H_ORIGIN_L + 100) + (l_thickness<<1)) && (pix_x >= H_ORIGIN_L - l_thickness)) &&
    (((pix_y <= V_ORIGIN_L + (l_thickness<<1)) && (pix_y >= V_ORIGIN_L - (l_thickness<<1))));
  wire l_active = (part1 || part2) && l_visible && state[2];
  wire l_active_outer = (part1_outer || part2_outer) && l_visible && state[2];

  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      l_counter <= 1;
      l_state <= 0;
      l_thickness <= 1;
      l_visible <= 1;
    end else if (state[2] && ~state[0]) begin
      case (l_state)
        // thin line
        2'b00: begin
          l_counter <= l_counter + 1;
          if (l_counter == 0) begin
            l_state <= 1;
            l_thickness <= 5;
          end
        end
        // blow up
        2'b01: begin
          l_thickness <= l_thickness + 2;
          if (l_thickness >= 15) begin
            l_state <= 2;
          end
        end
        // stay
        2'b10: begin    
          l_counter <= l_counter + 1;
          if (l_counter == 0) begin
            l_state <= 3;
            l_visible <= 0;
          end
        end
        // disappear
        2'b11: begin
          l_counter <= l_counter + 1;
          if (l_counter == 0) begin
            l_state <= 0;
            l_visible <= 1;
            l_thickness <= 1;
            //state[0] <= state[0] ^ 1;
          end
        end
      endcase
    end
  end
  wire l_done = (l_counter == 0 && l_state == 3);

  // O
  reg [9:0] radius = 1;
  parameter H_ORIGIN = 320;
  parameter V_ORIGIN = 240;
  parameter BULLET_SIZE = 8;

  wire [7:0] bullets;
  wire [9:0] bullet_pos_x [7:0];
  wire [9:0] bullet_pos_y [7:0];

  wire [9:0] radius_sqrt2 = (radius >> 1) + (radius >> 3) + (radius >> 4) + (radius >> 6);

  assign bullet_pos_x[0] = H_ORIGIN + radius;
  assign bullet_pos_y[0] = V_ORIGIN;
  assign bullet_pos_x[1] = H_ORIGIN + radius_sqrt2;
  assign bullet_pos_y[1] = V_ORIGIN - radius_sqrt2;
  assign bullet_pos_x[2] = H_ORIGIN;
  assign bullet_pos_y[2] = V_ORIGIN - radius;
  assign bullet_pos_x[3] = H_ORIGIN - radius_sqrt2;
  assign bullet_pos_y[3] = V_ORIGIN - radius_sqrt2;
  assign bullet_pos_x[4] = H_ORIGIN - radius;
  assign bullet_pos_y[4] = V_ORIGIN;
  assign bullet_pos_x[5] = H_ORIGIN - radius_sqrt2;
  assign bullet_pos_y[5] = V_ORIGIN + radius_sqrt2;
  assign bullet_pos_x[6] = H_ORIGIN;
  assign bullet_pos_y[6] = V_ORIGIN + radius;
  assign bullet_pos_x[7] = H_ORIGIN + radius_sqrt2;
  assign bullet_pos_y[7] = V_ORIGIN + radius_sqrt2;

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin
      wire [9:0] dx = (pix_x > bullet_pos_x[i]) ? (pix_x - bullet_pos_x[i]) : (bullet_pos_x[i] - pix_x);
      wire [9:0] dy = (pix_y > bullet_pos_y[i]) ? (pix_y - bullet_pos_y[i]) : (bullet_pos_y[i] - pix_y);
      assign bullets[i] = ((dx + dy - ((dx + dy) >> 2)) <= BULLET_SIZE);
    end
  endgenerate

  reg [2:0] bullet_idx;
  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      radius <= 1;
      bullet_idx <= 0;
    end else if (state[3] && ~state[0]) begin // expanding O
      if (radius < 70) radius <= radius + 6;
      //else if (radius < 95) radius <= radius + 3;
      else radius <= radius + 3;
      if (radius > 400) begin
        radius <= 1;
        //state[0] <= state[0] ^ 1;
      end
    end else if (state[4] && ~state[0]) begin // spinning O
      bullet_idx <= bullet_idx + 1;
      radius <= radius + 1;
      if (radius > 400) begin
        radius <= 1;
        bullet_idx <= 0;
        //state[0] <= state[0] ^ 1;
      end
    end
  end
  wire o_done = (radius > 400);
  wire o_active = ((|bullets) && state[3]) || ((bullets[bullet_idx]) && state[4]);

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

  // color
  assign R = ((video_active) ?
    ((t_active || l_active || l_active_outer ||o_active) && ~state[0] ? 2'b11 :
    ((pix_x[5] ^ shift_y[5]) ? 2'b00 : 2'b01)) : 2'b00);
  assign G = ((video_active) ?
    ((t_active || l_active || l_active_outer || o_active) && ~state[0] ? 2'b11 :
    ((pix_x[5] ^ shift_y[5]) ? 2'b00 : 2'b01)) : 2'b00);
  assign B = ((video_active) ?
    ((t_active || l_active || o_active) && ~state[0]  ? 2'b01 :
    (l_active_outer && ~state[0] ? 2'b10 :
    ((pix_x[5] ^ shift_y[5]) ? 2'b00 : 2'b01))) : 2'b00);

  // state
  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      state <= 0;
      counter <= 0;
    end else begin
      case (state)
        5'b00010: begin // T
          if (t_done) begin
            state[0] <= 1;
          end
        end
        5'b00011: begin
          counter <= counter + 1;
          if (counter >= 15) begin
            counter <= 0;
            state <= 5'b00100;
          end
        end
        5'b00100: begin // L
          if (l_done) begin
            state[0] <= 1;
          end
        end
        5'b00101: begin
          counter <= counter + 1;
          if (counter >= 15) begin
            counter <= 0;
            state <= 5'b01000;
          end
        end
        5'b01000: begin  // expanding O
          if (o_done) begin
            state[0] <= 1;
          end
        end
        5'b01001: begin
          counter <= counter + 1;
          if (counter >= 15) begin
            counter <= 0;
            state <= 5'b10000;
          end
        end
        5'b10000: begin // spinning O
          if (o_done) begin
            state[0] <= 1;
          end
        end 
        5'b10001: begin
          counter <= counter + 1;
          if (counter >= 15) begin
            counter <= 0;
            state <= 5'b00010;
          end
        end
        default: state <= 5'b00010;
      endcase
    end
  end

  // output assignments
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;
  wire _unused_ok = &{ena, ui_in, uio_in};
endmodule