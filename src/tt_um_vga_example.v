`default_nettype none

module tt_um_vga_example(
    input  wire       clk,
    input  wire       rst_n,
    output wire [7:0] uo_out
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
    reg [9:0] shift_side;

    wire [9:0] bullet_pos_x [0:7];
    wire [9:0] bullet_pos_y [0:7];
    wire [7:0] bullets;

    localparam signed [9:0] base_x_w[0:3] = '{-100, -72, -50, 0}; //320 - 100, 320 - 72, 320 - 50, 320, 320 is the H_ORIGIN
    localparam signed [9:0] base_y_w[0:3] = '{0, 48, 100, 50};  //V_ORIGIN is 0

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
  for (k = 0; k < 4; k++) begin
    if (k != 3) begin
      if (k != 1) begin
        assign bullet_pos_x[k] = H_ORIGIN + base_x_w[k] - shift_side;
        assign bullet_pos_x[7-k] = H_ORIGIN - base_x_w[k] + shift_side;
      end else begin
        assign bullet_pos_x[k] = H_ORIGIN + base_x_w[k] - (shift_side<<1);
        assign bullet_pos_x[7-k] = H_ORIGIN - base_x_w[k] + (shift_side<<1);
      end
    end else begin
      assign bullet_pos_x[k] = H_ORIGIN + base_x_w[k];
    end
    assign bullet_pos_y[k] = base_y_w[k] + fall_y;
    assign bullet_pos_y[7-k] = base_y_w[k] + fall_y; 
  end
  endgenerate
 
    // Single fall counter, updated on vsync
   reg [9:0] frame_count; // counts vsync frames
   reg [9:0] fall_speed;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        frame_count <= 0;
        fall_y <= 0;
        fall_speed <= 2;
    end else if (vsync) begin
      
        if (frame_count == 800) begin   // update every 255 clk cycles
            shift_side <= (fall_y < 180) ? 0 : shift_side + 1;

            if      (fall_y < 25) fall_speed <= 10;
            else if (fall_y < 75) fall_speed <= 4;
            else if (fall_y < 100) fall_speed <= 3;
            else if (fall_y < 130) fall_speed <= 2;
            else                   fall_speed <= 1;

            // Apply movement
            fall_y <= (fall_y >= 600) ? 0 : fall_y + fall_speed;

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
            wire [9:0] max_d = (dx > dy) ? dx : dy;
            assign bullets[i] = ((dx + dy) <= BULLET_SIZE);
        end
    endgenerate

    wire in_pattern = |bullets;
    wire border = ((pix_x <= 10) || (pix_x >= 630)) || ((pix_y <= 10) || (pix_y >= 470));

    assign R = (video_active && (in_pattern || border)) ? 2'b11 : 2'b00;
    assign G = 2'b00;
    assign B = (video_active && in_pattern) ? ((border) ? 2'b00 : 2'b11) : 2'b00;

endmodule