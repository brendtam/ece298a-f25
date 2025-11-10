`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);

  // VGA signals
  wire hsync, vsync;
  wire [1:0] R, G, B;
  wire video_active;
  wire [9:0] pix_x, pix_y;

  reg [9:0] radius;
  parameter H_ORIGIN = 320;
  parameter V_ORIGIN = 240;
  parameter BULLET_SIZE = 6;

  wire in_pattern;
  wire border;
  wire [7:0] bullets;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  wire _unused_ok = &{ena, ui_in, uio_in};

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  // -----------------------------
  // Simplified bullet positions
  // -----------------------------
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin
      wire [9:0] bullet_x;
      wire [9:0] bullet_y;

      // Compute positions on-the-fly
      assign bullet_x = (i==0) ? H_ORIGIN + radius :
                        (i==1) ? H_ORIGIN + (radius>>1) :
                        (i==2) ? H_ORIGIN :
                        (i==3) ? H_ORIGIN - (radius>>1) :
                        (i==4) ? H_ORIGIN - radius :
                        (i==5) ? H_ORIGIN - (radius>>1) :
                        (i==6) ? H_ORIGIN :
                        H_ORIGIN + (radius>>1);

      assign bullet_y = (i==0) ? V_ORIGIN :
                        (i==1) ? V_ORIGIN - (radius>>1) :
                        (i==2) ? V_ORIGIN - radius :
                        (i==3) ? V_ORIGIN - (radius>>1) :
                        (i==4) ? V_ORIGIN :
                        (i==5) ? V_ORIGIN + (radius>>1) :
                        (i==6) ? V_ORIGIN + radius :
                        V_ORIGIN + (radius>>1);

      // Bounding-box check (tiny)
      assign bullets[i] = (pix_x >= bullet_x - BULLET_SIZE) &&
                          (pix_x <= bullet_x + BULLET_SIZE) &&
                          (pix_y >= bullet_y - BULLET_SIZE) &&
                          (pix_y <= bullet_y + BULLET_SIZE);
    end
  endgenerate

  assign in_pattern = |bullets;  // Any bullet active?

  // Simplified border: use top 6 bits only
  assign border = (pix_x[9:4]==0) || (pix_x[9:4]==39) || (pix_y[9:4]==0) || (pix_y[9:4]==29);

  // Color assignment (simple)
  assign R = (video_active && (in_pattern || border)) ? 2'b11 : 2'b00;
  assign G = 2'b00;
  assign B = (video_active && in_pattern && !border) ? 2'b11 : 2'b00;

  // -----------------------------
  // Simple radius counter (powers of 2)
  // -----------------------------
  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n)
      radius <= 0;
    else begin
      radius <= radius + 8;        // cheap increment
      if (radius > 456) radius <= 0;
    end
  end

endmodule
