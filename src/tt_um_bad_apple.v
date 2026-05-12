`default_nettype none

module tt_um_bad_apple(
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
  wire hsync, vsync, video_active;
  wire [9:0] pix_x, pix_y;
  wire [1:0] R, G, B;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  //VGA Output
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;
  // Unused wires
  wire _unused_ok = &{ena, ui_in, uio_in};

  // State machine
  reg state;
  localparam STATE_U = 0, STATE_W = 1;

  // Bullet parameters
  parameter H_ORIGIN=320, V_ORIGIN=0, BULLET_SIZE=10;
  // fall_y is the vertical distance from V_ORIGIN, shift_side is the horizontal distance from H_ORIGIN
  reg [7:0] fall_y; reg [8:0] shift_side;

  // Store position of center of bullet
  wire [9:0] bullet_pos_x [0:5], bullet_pos_y [0:5];
  // Store the area that the entire bullet covers
  wire [5:0] bullets;

  // Base positions for U-shape, assign base_x[2]= -50; assign base_y[2]=100; 
  wire signed [9:0] base_x[0:2]; assign base_x[0]= -62; assign base_x[1]= -62; assign base_x[2]= -26;
  wire signed [9:0] base_y[0:2]; assign base_y[0]=0; assign base_y[1]=48; assign base_y[2]=90; 

  // Generate bullet positions and populate bullet_pos_x/bullet_pos_y arrays
  genvar k;
  generate
    for(k=0; k<3; k=k+1) begin
      assign bullet_pos_x[k]   = H_ORIGIN + base_x[k] + shift_side;
      assign bullet_pos_x[5-k] = H_ORIGIN - base_x[k] - shift_side;
      assign bullet_pos_y[k]   = base_y[k] + fall_y;
      assign bullet_pos_y[5-k] = base_y[k] + fall_y;
    end
  endgenerate

  // Frame count to slow translation speed
  reg [8:0] frame_count; reg [4:0] fall_speed;

  // W code: the current (x,y) coordinates are rotated by (angle_idx * 22)
  // degrees to create the transformed (u,v) plane.

  // Rotation / spin
  reg signed [5:0] cos_val, sin_val;
  reg signed [13:0] start_u, start_v, row_u, row_v, curr_u, curr_v;
  reg [3:0] angle_idx;
  reg [2:0] spin_speed;

  // Angle table
  always @(*) begin
    case(angle_idx[2:0])
      0:  begin cos_val=31;  sin_val=0;    start_u=-10240; start_v=-7680;  end
      1:  begin cos_val=30;  sin_val=13;   start_u=-6460;  start_v=-11720; end
      2:  begin cos_val=24;  sin_val=24;   start_u=-1980;  start_v=-13860; end
      3:  begin cos_val=13;  sin_val=30;   start_u=2920;   start_v=-13060; end
      4:  begin cos_val=0;   sin_val=31;   start_u=7680;   start_v=-10240; end
      5: begin cos_val=-13; sin_val=30;   start_u=11720;  start_v=-6460;  end
      6: begin cos_val=-24; sin_val=24;   start_u=13860;  start_v=-1980;  end
      7: begin cos_val=-30; sin_val=13;   start_u=13060;  start_v=2920;   end
      default: begin cos_val=31; sin_val=0; start_u=-10240; start_v=-7680; end
    endcase
  end

  // integer part of current u/v coordinates
  wire signed [8:0] int_u = curr_u[13:5];
  wire signed [8:0] int_v = curr_v[13:5];

  // W positions
  localparam pos4 = -210, pos3 = -210, pos2 = 70, pos = 70;
  localparam line_width = 20;

  wire in_shape = (state==STATE_W) &&
                  (int_u >= -60 && int_u <= 80 && pix_x >= 128 && pix_x <= 512) &&
                  (
                    (int_u + (int_v<<1) >= pos3 && int_u + (int_v<<1) <= pos3+line_width) || 
                    (int_u - (int_v<<1) >= pos2 && int_u - (int_v<<1) <= pos2+line_width) || 
                    (int_u + (int_v<<1) >= pos && int_u + (int_v<<1) <= pos+line_width) || 
                    (int_u - (int_v<<1) >= pos4 && int_u - (int_v<<1) <= pos4+line_width)
                  );

  // animations
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      angle_idx <= 4; row_u <= 0; row_v <= 0; curr_u <= 0; curr_v <= 0; spin_speed <= 1;
      frame_count <= 0; fall_y <= 0; fall_speed <= 2; shift_side <= 0;
      state <= STATE_U;
    end else if (vsync && state == STATE_U) begin   // U section
      // Increment frame count
      frame_count <= frame_count + 1;

      //Every 500 frames, add a translation
      if (frame_count == 500) begin
        // Stop falling once fall_y = 180 (roughly 1/2 of the screen vertical height)
        fall_y <= (fall_y >= 180) ? 180 : fall_y + fall_speed;

        // Start shifting horizontally once fall_y is equal to 180
        shift_side <= (fall_y < 180) ? 0 : shift_side + 1;

        // 3 layer cascading deceleration (10 to 4 to 1)
        fall_speed <= (fall_y < 25) ? 10 : ((fall_y < 125) ? 4 : 1);

        // reset the frame count for the next frame
        frame_count <= 0;
      end
      // if the U halves are outside the screen, change state to w_state
      if (shift_side > 400) begin
        frame_count <= 0; fall_y <= 0; fall_speed <= 2; shift_side <= 0;
        state <= STATE_W;
      end
    end else if (state == STATE_W) begin      // W-section
      // only update parameters per-frame
      if (pix_y == 480 && pix_x == 640) begin
        // fixed rotation mode, spin_speed is used as a counter
        if (ui_in[0]) begin
          if (angle_idx == 0) spin_speed <= spin_speed + 1;
          angle_idx <= angle_idx + 1;
        // wind-up rotation mode, every 32 frames the rotation speed will increase
        end else begin
          if (frame_count == 32) begin
            frame_count <= 0;
            spin_speed <= spin_speed + 1;
          end else begin
            frame_count <= frame_count + 1;
          end
          angle_idx <= angle_idx + spin_speed;
        end
        // stopping condition for W
        if (spin_speed == 0) begin
          angle_idx <= 4; row_u <= 0; row_v <= 0; curr_u <= 0; curr_v <= 0; spin_speed <= 1;
          frame_count <= 0;
          state <= STATE_U;
        end
      end

      // u/v coordinates are calculated by incrementing cos/sin per pixel to form the rotated plane
      if (pix_x == 0) begin
        // initial conditions of u/v, precomputed
        if (pix_y == 0) begin
          row_u <= angle_idx[3] ? -start_u : start_u;
          row_v <= angle_idx[3] ? -start_v : start_v;
          curr_u <= angle_idx[3] ? -start_u : start_u;
          curr_v <= angle_idx[3] ? -start_v : start_v;
        // move down in u/v plane
        end else begin
          row_u <= angle_idx[3] ? row_u + sin_val : row_u - sin_val;
          row_v <= angle_idx[3] ? row_v - cos_val : row_v + cos_val;
          curr_u <= angle_idx[3] ? row_u + sin_val : row_u - sin_val;
          curr_v <= angle_idx[3] ? row_v - cos_val : row_v + cos_val;
        end
      // go across in u/v plane
      end else if (video_active) begin
        curr_u <= angle_idx[3] ? curr_u - cos_val : curr_u + cos_val;
        curr_v <= angle_idx[3] ? curr_v - sin_val : curr_v + sin_val;
      end
    end
  end

  // Render bullets (square shape)
 genvar i;
  generate
    for (i = 0; i < 6; i=i+1) begin : render_bullets
      assign bullets[i] = (pix_x >= bullet_pos_x[i]-BULLET_SIZE) &&
                          (pix_x <= bullet_pos_x[i]+BULLET_SIZE) &&
                          (pix_y >= bullet_pos_y[i]-BULLET_SIZE) &&
                          (pix_y <= bullet_pos_y[i]+BULLET_SIZE);
    end
  endgenerate

  // in_pattern only checks if the pixel is in the U-shaped bullets
  wire in_pattern = (|bullets) && state==STATE_U;

  // Background + background movement
  reg [3:0] bg_shift;
  wire [9:0] shift_y = pix_y - bg_shift;
  always @(posedge vsync or negedge rst_n) begin
    if (!rst_n) bg_shift <= 0;
    else bg_shift <= bg_shift + 3;  //determines background movement speed
  end

  // Color generation
  wire valid = in_shape || in_pattern;
  wire checkerboard = pix_x[3] ^ shift_y[3];

  // Generates red-black checkerboard pattern, Waterloo-yellow bullets/lines, and black border
  assign R = (video_active) ? ((valid)?2'b11:(checkerboard?2'b00:2'b10)) : 2'b00;
  assign G = (video_active) ? ((valid)?2'b11:(checkerboard?2'b00:2'b00)) : 2'b00;
  assign B = (video_active) ? ((valid)?2'b01:(checkerboard?2'b00:2'b00)) : 2'b00;

endmodule