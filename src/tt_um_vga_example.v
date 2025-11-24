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

  reg [9:0] radius;
  parameter H_ORIGIN = 320;
  parameter V_ORIGIN = 240;
  parameter BULLET_SIZE = 6;

  wire in_pattern;
  wire border;
  wire [9:0] radius_sqrt2;
  wire [7:0] bullets;
  wire [9:0] bullet_pos_x [7:0];
  wire [9:0] bullet_pos_y [7:0];

  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;
  wire _unused_ok = &{ena, ui_in, uio_in};

  assign radius_sqrt2 = (radius >> 1) + (radius >> 3) + (radius >> 4) + (radius >> 6);

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

  reg [2:0] bullet_idx;
  wire [9:0] bx = bullet_pos_x[bullet_idx];
  wire [9:0] by = bullet_pos_y[bullet_idx];
  wire [9:0] dx = (pix_x > bx) ? (pix_x - bx) : (bx - pix_x);
  wire [9:0] dy = (pix_y > by) ? (pix_y - by) : (by - pix_y);
  assign in_pattern = ((dx + dy - ((dx + dy) >> 2)) <= BULLET_SIZE);
  
  reg [5:0] shift;
  wire [9:0] shift_y = pix_y - shift;
  assign R = in_pattern ? 2'b11 : ((pix_x[5] ^ shift_y[5]) ? 2'b00 : 
    (video_active ? 2'b01 : 2'b00));
  assign G = in_pattern ? 2'b11 : ((pix_x[5] ^ shift_y[5]) ? 2'b00 : 
    (video_active ? 2'b01 : 2'b00));
  assign B = in_pattern ? 2'b01 : ((pix_x[5] ^ shift_y[5]) ? 2'b00 : 
    (video_active ? 2'b01 : 2'b00)); 

  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      radius <= 0;
      bullet_idx <= 0;
      shift <= 0;
    end else begin
      bullet_idx <= bullet_idx + 1;
      radius <= radius + 1;
      shift <= shift + 1;
      if (radius > 400) begin
          radius <= 0;
      end
    end
  end
endmodule