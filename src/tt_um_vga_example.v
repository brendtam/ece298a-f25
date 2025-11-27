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
    wire hsync, vsync;
    wire [1:0] R, G, B;
    wire video_active;
    wire [9:0] pix_x, pix_y;
    

    parameter H_ORIGIN = 320;
    parameter V_ORIGIN = 0;
    parameter BULLET_SIZE = 10;
    // parameter NUM_BULLETS = 8;

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

    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

    // Simple VGA generator
    hvsync_generator hvsync_gen (
        .clk(clk),
        .reset(~rst_n),
        .hsync(hsync),
        .vsync(vsync),
        .display_on(video_active),
        .hpos(pix_x),
        .vpos(pix_y)
    );

  genvar k;
  generate
  for (k = 0; k < 4; k = k + 1) begin
    if (k == 0) begin
      assign bullet_pos_x[k]   = H_ORIGIN + base_x0 + shift_side;
      assign bullet_pos_x[7-k] = H_ORIGIN - base_x0 - shift_side;
      assign bullet_pos_y[k]   = base_y0 + fall_y;
      assign bullet_pos_y[7-k] = base_y0 + fall_y;
    end else if (k == 1) begin
      assign bullet_pos_x[k]   = H_ORIGIN + base_x1 + shift_side;
      assign bullet_pos_x[7-k] = H_ORIGIN - base_x1 - shift_side;
      assign bullet_pos_y[k]   = base_y1 + fall_y;
      assign bullet_pos_y[7-k] = base_y1 + fall_y;
    end else if (k == 2) begin
      assign bullet_pos_x[k]   = H_ORIGIN + base_x2 + shift_side;
      assign bullet_pos_x[7-k] = H_ORIGIN - base_x2 - shift_side;
      assign bullet_pos_y[k]   = base_y2 + fall_y;
      assign bullet_pos_y[7-k] = base_y2 + fall_y;
    end else begin
      assign bullet_pos_x[k]   = H_ORIGIN + base_x3 + shift_side;
      assign bullet_pos_x[7-k] = H_ORIGIN - base_x3 - shift_side;
      assign bullet_pos_y[k]   = base_y3 + fall_y;
      assign bullet_pos_y[7-k] = base_y3 + fall_y;
    end
  end
endgenerate

    // Single fall counter, updated on vsync
   reg [9:0] frame_count; // counts vsync frames
   reg [4:0] fall_speed;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        frame_count <= 0;
        fall_y <= 0;
        fall_speed <= 2;
    end else if (vsync) begin
      
        if (frame_count == 800) begin   // update every 800 clk cycles
            shift_side <= (fall_y < 180) ? 0 : shift_side + 1;

            if (shift_side > 500)
                fall_y <= 0;
            else if (fall_y >= 180)
                fall_y <= fall_y;
            else
                fall_y <= fall_y + fall_speed;

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

    wire in_pattern = |bullets;
      reg [5:0] shift;
  wire [9:0] shift_y = pix_y - shift;
  assign R = (video_active ? (in_pattern ? 2'b11 :
    ((pix_x[5] ^ shift_y[5]) ? 2'b00 : 2'b01)) : 2'b00);
  assign G = (video_active ? (in_pattern ? 2'b10 :
    ((pix_x[5] ^ shift_y[5]) ? 2'b00 : 2'b01)) : 2'b00);
  assign B = (video_active ? (in_pattern ? 2'b00 :
    ((pix_x[5] ^ shift_y[5]) ? 2'b00 : 2'b01)) : 2'b00);

  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      shift <= 0;
    end else begin
      shift <= shift + 1;
    end
  end                                                   // blue off

endmodule