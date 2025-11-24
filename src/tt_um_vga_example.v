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
    reg [9:0] shift_side;

    wire [9:0] bullet_pos_x [0:7];
    wire [9:0] bullet_pos_y [0:7];
    wire [7:0] bullets;
    
    reg rise;
    reg done;

    reg [8:0] eff_shift_x0;
    reg [8:0] eff_shift_x1;
    reg [8:0] eff_shift_x2;
    reg [8:0] eff_shift_x3;

    reg signed [9:0] cur_base_x0 = -62;
    reg signed [9:0] cur_base_x1 = -62;
    reg signed [9:0] cur_base_x2 = -50;
    reg signed [9:0] cur_base_x3 = -18;
    reg signed [9:0] cur_base_y0 = 0;
    reg signed [9:0] cur_base_y1 = 48;
    reg signed [9:0] cur_base_y2 = 100;
    reg signed [9:0] cur_base_y3 = 120;


    // U pattern
    localparam signed [9:0] u_base_x0 = -62;
    localparam signed [9:0] u_base_x1 = -62;
    localparam signed [9:0] u_base_x2 = -50;
    localparam signed [9:0] u_base_x3 = -18;

    localparam signed [9:0] u_base_y0 = 0;
    localparam signed [9:0] u_base_y1 = 48;
    localparam signed [9:0] u_base_y2 = 100;
    localparam signed [9:0] u_base_y3 = 120;

    //W pattern
    localparam signed [9:0] w_base_x0 = -100;
    localparam signed [9:0] w_base_x1 = -72;
    localparam signed [9:0] w_base_x2 = -50;
    localparam signed [9:0] w_base_x3 = 0;

    localparam signed [9:0] w_base_y0 = 0;
    localparam signed [9:0] w_base_y1 = 48;
    localparam signed [9:0] w_base_y2 = 100;
    localparam signed [9:0] w_base_y3 = 50;

    // A pattern
    localparam signed [9:0] a_base_x0 = 0;
    localparam signed [9:0] a_base_x1 = 0;
    localparam signed [9:0] a_base_x2 = -30;
    localparam signed [9:0] a_base_x3 = -75;

    localparam signed [9:0] a_base_y0 = 100;
    localparam signed [9:0] a_base_y1 = 0;
    localparam signed [9:0] a_base_y2 = 75;
    localparam signed [9:0] a_base_y3 = 150;


    // E pattern
    localparam signed [9:0] e_base_x0 = -31;
    localparam signed [9:0] e_base_x1 = -31;
    localparam signed [9:0] e_base_x2 = -31;
    localparam signed [9:0] e_base_x3 = -31;

    localparam signed [9:0] e_base_y0 = 0;
    localparam signed [9:0] e_base_y1 = 60;
    localparam signed [9:0] e_base_y2 = 120;
    localparam signed [9:0] e_base_y3 = 120;

    // R pattern
    localparam signed [9:0] r_base_x0 = -31;
    localparam signed [9:0] r_base_x1 = -31;
    localparam signed [9:0] r_base_x2 = -31;
    localparam signed [9:0] r_base_x3 = -31;

    localparam signed [9:0] r_base_y0 = 0;
    localparam signed [9:0] r_base_y1 = 48;
    localparam signed [9:0] r_base_y2 = 100;
    localparam signed [9:0] r_base_y3 = 152;

    reg [2:0] pattern_state;

    assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = 0;
  assign uio_oe  = 0;
  wire _unused_ok = &{ena, ui_in, uio_in};

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

    always @(*) begin
    case(pattern_state)
        0: begin  //U
            cur_base_x0 = u_base_x0; 
            cur_base_x1 = u_base_x1; 
            cur_base_x2 = u_base_x2; 
            cur_base_x3 = u_base_x3; 

            cur_base_y0 = u_base_y0;
            cur_base_y1 = u_base_y1;
            cur_base_y2 = u_base_y2;
            cur_base_y3 = u_base_y3;

            eff_shift_x0 = shift_side;
            eff_shift_x1 = shift_side;
            eff_shift_x2 = shift_side;
            eff_shift_x3 = shift_side;
        end
        1: begin   //W
            cur_base_x0 = w_base_x0; 
            cur_base_x1 = w_base_x1; 
            cur_base_x2 = w_base_x2; 
            cur_base_x3 = w_base_x3; 

            cur_base_y0 = w_base_y0;
            cur_base_y1 = w_base_y1;
            cur_base_y2 = w_base_y2;
            cur_base_y3 = w_base_y3;

            eff_shift_x0 = (shift_side);
            eff_shift_x1 = ((shift_side << 1));
            eff_shift_x2 = (shift_side);
            eff_shift_x3 = 0;
        end
        2: begin   //A
          cur_base_x0 = a_base_x0; 
          cur_base_x1 = a_base_x1; 
          cur_base_x2 = a_base_x2; 
          cur_base_x3 = a_base_x3; 

          cur_base_y0 = a_base_y0;
          cur_base_y1 = a_base_y1;
          cur_base_y2 = a_base_y2;
          cur_base_y3 = a_base_y3;

          eff_shift_x0 = 0;
          eff_shift_x1 = shift_side;
          eff_shift_x2 = shift_side << 1;
          eff_shift_x3 = shift_side << 1;
        end
        3: begin  //E
          cur_base_x0 = e_base_x0; 
          cur_base_x1 = e_base_x1; 
          cur_base_x2 = e_base_x2; 
          cur_base_x3 = e_base_x3; 

          cur_base_y0 = e_base_y0;
          cur_base_y1 = e_base_y1;
          cur_base_y2 = e_base_y2;
          cur_base_y3 = e_base_y3;

          eff_shift_x0 = shift_side<<1;
          eff_shift_x1 = shift_side<<2;
          eff_shift_x2 = shift_side<<1;
          eff_shift_x3 = shift_side<<2;
        end
        4: begin  //R
          cur_base_x0 = r_base_x0; 
          cur_base_x1 = r_base_x1; 
          cur_base_x2 = r_base_x2; 
          cur_base_x3 = r_base_x3; 

          cur_base_y0 = r_base_y0;
          cur_base_y1 = r_base_y1;
          cur_base_y2 = r_base_y2;
          cur_base_y3 = r_base_y3;

          eff_shift_x0 = 10;
          eff_shift_x1 = 20;
          eff_shift_x2 = 10;
          eff_shift_x3 = 60;
        end
        // Add more patterns
        default: begin
            cur_base_x0 = 0; 
            cur_base_x1 = 0; 
            cur_base_x2 = 0; 
            cur_base_x3 = 0; 

            cur_base_y0 = 0;
            cur_base_y1 = 0;
            cur_base_y2 = 0;
            cur_base_y3 = 0;

            eff_shift_x0 = 0;
            eff_shift_x1 = 0;
            eff_shift_x2 = 0;
            eff_shift_x3 = 0;
        end
    endcase
end

  
    // Single fall counter, updated on vsync
   reg [9:0] frame_count; // counts vsync frames
   reg [4:0] fall_speed;

always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
        frame_count <= 0;
        fall_y <= 0;
        fall_speed <= 2;
        rise <= 0;
        shift_side <= 0;
    end else if (vsync) begin
      
        if (frame_count == 500) begin   // update every 800 clk cycles
            // Step 1: Update fall_y according to rise/fall
            if (rise == 1) begin
                if (fall_y > 0) begin
                    done <= 1;
                    fall_y <= fall_y - 1;
                end else begin
                    rise <= 0;  // stop rising at 0
                end
            end else begin
                if (fall_y >= 180 && pattern_state == 0)
                    fall_y <= fall_y;  // freeze for U pattern
                else
                    fall_y <= fall_y + fall_speed;
            end

            // Step 2: Shift update
            shift_side <= (fall_y >= 180) ? shift_side + 1 : (rise == 1) ? shift_side + 1 : 0 ;

            // Step 3: Trigger rise if appropriate
            if ((pattern_state == 4 || pattern_state == 3) && fall_y > 200 && done == 0) begin
                rise <= 1;
            end

            // Step 4: Advance pattern only if fall_y reached bottom
            if (shift_side >= 400 || (!rise && fall_y >= 600)) begin
                done <= 0;
                fall_y <= 0;
                shift_side <= 0;
                rise <= 0;
                pattern_state <= (pattern_state == 4) ? 0 : pattern_state + 1;
            end

        

            frame_count <= 0;


        end else begin
            frame_count <= frame_count + 1;
        end
    end
end

  genvar k;
  generate
  for (k = 0; k < 4; k = k + 1) begin
    if (k == 0) begin
      assign bullet_pos_x[k]   = H_ORIGIN + cur_base_x0 - eff_shift_x0;
      assign bullet_pos_x[7-k] = H_ORIGIN - cur_base_x0 + eff_shift_x0;
      assign bullet_pos_y[k]   = cur_base_y0 + fall_y;
      assign bullet_pos_y[7-k] = cur_base_y0 + fall_y;
    end else if (k == 1) begin
      assign bullet_pos_x[k]   = H_ORIGIN + cur_base_x1 - eff_shift_x1;
      assign bullet_pos_x[7-k] = H_ORIGIN - cur_base_x1 + eff_shift_x1;
      assign bullet_pos_y[k]   = cur_base_y1 + fall_y;
      assign bullet_pos_y[7-k] = cur_base_y1 + fall_y;
    end else if (k == 2) begin
      assign bullet_pos_x[k]   = H_ORIGIN + cur_base_x2 - eff_shift_x2;
      assign bullet_pos_x[7-k] = H_ORIGIN - cur_base_x2 + eff_shift_x2;
      assign bullet_pos_y[k]   = cur_base_y2 + fall_y;
      assign bullet_pos_y[7-k] = cur_base_y2 + fall_y;
    end else begin
      assign bullet_pos_x[k]   = H_ORIGIN + cur_base_x3 - eff_shift_x3;
      assign bullet_pos_x[7-k] = H_ORIGIN - cur_base_x3 + eff_shift_x3;
      assign bullet_pos_y[k]   = cur_base_y3 + fall_y;
      assign bullet_pos_y[7-k] = cur_base_y3 + fall_y;
    end
  end
endgenerate



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
    wire border = ((pix_x <= 10) || (pix_x >= 630)) || ((pix_y <= 10) || (pix_y >= 470));

    assign R = (video_active && (in_pattern || border)) ? 2'b11 : 2'b00;  // max red
    assign G = (video_active && (in_pattern || border)) ? 2'b10 : 2'b00;  // slightly less green
    assign B = 2'b00;                                                     // blue off


endmodule

