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

  // VGA signals
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

  parameter H_ORIGIN = 290;
  parameter V_ORIGIN = 340;

  reg [4:0] thickness;
  reg visible;
  wire part1 = ((pix_x <= H_ORIGIN + thickness) && (pix_x >= H_ORIGIN - thickness)) &&
    ((pix_y <= V_ORIGIN + thickness) && (pix_y >= (V_ORIGIN - 200) - (thickness<<1)));
  wire part1_outer = ((pix_x <= H_ORIGIN + (thickness<<1)) && (pix_x >= H_ORIGIN - (thickness<<1))) &&
    ((pix_y <= V_ORIGIN + (thickness<<1)) && (pix_y >= (V_ORIGIN - 200) - (thickness<<2) + (thickness>>1) + 8));
  wire part2 = ((pix_x <= (H_ORIGIN + 100) + thickness) && (pix_x >= H_ORIGIN - thickness)) &&
    ((pix_y <= V_ORIGIN + thickness) && (pix_y >= V_ORIGIN - thickness));
  wire part2_outer = ((pix_x <= (H_ORIGIN + 100) + (thickness<<1)) && (pix_x >= H_ORIGIN - thickness)) &&
    (((pix_y <= V_ORIGIN + (thickness<<1)) && (pix_y >= V_ORIGIN - (thickness<<1))));
  wire in_pattern = (part1 || part2) && visible;
  wire in_outer = (part1_outer || part2_outer) && visible;

  wire border = ((pix_x >= 0 && pix_x <= 10) || (pix_x >= 630 && pix_x <= 640)) ||
                ((pix_y >= 0 && pix_y <= 10) || (pix_y >= 470 && pix_y <= 480));

  assign R = (video_active && (in_pattern || in_outer || border)) ? 2'b11 : 2'b00;
  assign G = 2'b00;
  assign B = (video_active && border) ? 2'b00 : (video_active && in_pattern ? 2'b11 : (video_active && in_outer ? 2'b10 : 2'b00));

  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  assign uio_out = 0;
  assign uio_oe  = 0;

  wire _unused_ok = &{ena, ui_in, uio_in};

  reg [1:0] state;
  reg [5:0] counter;

  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      thickness <= 0;
      counter <= 0;
      state <= 0;
      visible <= 1;
    end else begin
      case (state)
        // thin line
        2'b00: begin
          counter <= counter + 1;
          if (counter == 0) begin
            thickness <= 5;
            state <= 1;
          end
        end
        // blow up
        2'b01: begin
          thickness <= thickness + 2;
          if (thickness >= 15) begin
            state <= 2;
          end
        end
        // stay
        2'b10: begin    
          counter <= counter + 1;
          if (counter == 0) begin
            state <= 3;
            visible <= 0;
          end
        end
        // disappear
        2'b11: begin
          counter <= counter + 1;
          if (counter == 0) begin
            state <= 0;
            visible <= 1;
            thickness <= 0;
          end
        end
      endcase
    end
  end
endmodule
