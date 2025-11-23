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

    wire _unused_ok = &{ena, ui_in, uio_in};

    parameter H_ORIGIN = 320;
    parameter V_ORIGIN = 0;
    parameter BULLET_SIZE = 6;
    parameter NUM_BULLETS = 8;

    reg [9:0] fall_y;
    reg [9:0] shift_side;

    wire [9:0] bullet_pos_x [0:NUM_BULLETS-1];
    wire [9:0] bullet_pos_y [0:NUM_BULLETS-1];
    wire [NUM_BULLETS-1:0] bullets;

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

    // Horizontal positions for a W
    assign bullet_pos_x[0] = H_ORIGIN - 100 - (shift_side >> 1);  // top left
    assign bullet_pos_x[1] = H_ORIGIN - 72  - shift_side;         // middle left
    assign bullet_pos_x[3] = H_ORIGIN + 50  + (shift_side >> 1);  // bottom right
    assign bullet_pos_x[4] = H_ORIGIN + 100 + (shift_side >> 1);  // top right
    assign bullet_pos_x[5] = H_ORIGIN - 50  - (shift_side >> 1);  // bottom left
    assign bullet_pos_x[6] = H_ORIGIN;                            // middle
    assign bullet_pos_x[7] = H_ORIGIN + 72 + shift_side;          // middle right

    // Vertical positions
    assign bullet_pos_y[0] = V_ORIGIN + fall_y;           // left
    assign bullet_pos_y[1] = V_ORIGIN + 48 + fall_y;      // left mid
    assign bullet_pos_y[3] = V_ORIGIN + 100 + fall_y;     // bottom mid right
    assign bullet_pos_y[4] = V_ORIGIN + fall_y;           // right
    assign bullet_pos_y[5] = V_ORIGIN + 100 + fall_y;     // bottom mid left
    assign bullet_pos_y[6] = V_ORIGIN + 50 + fall_y;      // bottom center
    assign bullet_pos_y[7] = V_ORIGIN + 48 + fall_y;      // bottom right

    // Single fall counter
    reg [9:0] frame_count; 
    reg [9:0] fall_speed;

    always @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            frame_count <= 0;
            fall_y <= 0;
            fall_speed <= 2;
        end else if (vsync) begin
            if (frame_count == 800) begin
                shift_side <= (fall_y < 150) ? 0 : shift_side + 1;

                if      (fall_y < 25)  fall_speed <= 10;
                else if (fall_y < 100) fall_speed <= 4;
                else if (fall_y < 125) fall_speed <= 3;
                else if (fall_y < 160) fall_speed <= 2;
                else                   fall_speed <= 1;

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
        for (i = 0; i < NUM_BULLETS; i = i + 1) begin
            wire [9:0] dx = (pix_x > bullet_pos_x[i]) ? (pix_x - bullet_pos_x[i]) : (bullet_pos_x[i] - pix_x);
            wire [9:0] dy = (pix_y > bullet_pos_y[i]) ? (pix_y - bullet_pos_y[i]) : (bullet_pos_y[i] - pix_y);
            assign bullets[i] = ((dx + dy + ((dx > dy ? dy : dx) >> 1)) <= BULLET_SIZE);
        end
    endgenerate

    wire in_pattern = |bullets;
    wire border = ((pix_x <= 10) || (pix_x >= 630)) || ((pix_y <= 10) || (pix_y >= 470));

    assign R = (video_active && (in_pattern || border)) ? 2'b11 : 2'b00;
    assign G = 2'b00;
    assign B = (video_active && in_pattern) ? (border ? 2'b00 : 2'b11) : 2'b00;

endmodule
