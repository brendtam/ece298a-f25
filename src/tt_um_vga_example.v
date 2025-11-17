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
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  reg [9:0] radius;
  parameter H_ORIGIN = 320;
  parameter V_ORIGIN = 240;
  parameter BULLET_SIZE = 10;

  wire in_pattern;
  wire border;
  wire [7:0] bullets;

  reg [9:0] counter;
  reg [8:0] deg;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

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

  // relative offsets from sincos8_gen (signed, centered at 0)
  wire signed [9:0] rel_x [7:0];
  wire signed [9:0] rel_y [7:0];

  // absolute screen positions (unsigned 10-bit)
  wire [9:0] bullet_pos_x [7:0];
  wire [9:0] bullet_pos_y [7:0];

  // instantiate generator (produces offsets around 0)
  sincos8_gen sincos_gen(
    .clk(clk),
    .rst_n(rst_n),
    .angle_in(deg),
    .radius(radius),
    .sin_pix(rel_y),   // sin -> Y offset
    .cos_pix(rel_x)    // cos -> X offset
  );

  // convert offsets + origin -> absolute coordinates
  genvar gi;
  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : MAKE_POS
      // X: origin + signed offset
      assign bullet_pos_x[gi] = H_ORIGIN + $signed(rel_x[gi]);

      // Y: origin - signed offset (screen Y increases downward)
      // cast to signed then add/subtract safely
      assign bullet_pos_y[gi] = V_ORIGIN - $signed(rel_y[gi]);
    end
  endgenerate

  // collision test / bullet ink
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : DRAW
      wire [9:0] dx = (pix_x > bullet_pos_x[i]) ? (pix_x - bullet_pos_x[i]) : (bullet_pos_x[i] - pix_x);
      wire [9:0] dy = (pix_y > bullet_pos_y[i]) ? (pix_y - bullet_pos_y[i]) : (bullet_pos_y[i] - pix_y);
      assign bullets[i] = ((dx + dy) + ((dx > dy ? dy : dx) >> 1) <= BULLET_SIZE);
    end
  endgenerate

  assign in_pattern = ~(bullets == 0);
  assign border = ((pix_x <= 10) || (pix_x >= 630)) || ((pix_y <= 10) || (pix_y >= 470));

  assign R = (video_active && (in_pattern || border)) ? 2'b11 : 2'b00;
  assign G = 2'b00;
  assign B = (video_active && in_pattern) ? ((border) ? 2'b00 : 2'b11) : 2'b00;

  always @(posedge vsync or negedge rst_n) begin
    if (!rst_n) begin
      radius <= 0;
      deg <= 0;
    end else begin
      radius <= radius + 1;
      deg <= deg + 1;
      if (radius > 400) radius <= 0;
      if (deg >= 9'd360) deg <= 0;
    end
  end

endmodule

module sincos8_gen (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [8:0]  angle_in,   // 0..359 degrees
    input  wire [9:0]  radius,     // 0..400 pixels
    output reg  signed [9:0] sin_pix [7:0], // Y offsets (signed)
    output reg  signed [9:0] cos_pix [7:0]  // X offsets (signed)
);

reg signed [7:0] sin_lut [0:127];

initial begin
    sin_lut[  0]=  0; sin_lut[  1]=  3; sin_lut[  2]=  6; sin_lut[  3]=  9;
    sin_lut[  4]= 12; sin_lut[  5]= 15; sin_lut[  6]= 18; sin_lut[  7]= 21;
    sin_lut[  8]= 24; sin_lut[  9]= 27; sin_lut[ 10]= 30; sin_lut[ 11]= 33;
    sin_lut[ 12]= 36; sin_lut[ 13]= 39; sin_lut[ 14]= 41; sin_lut[ 15]= 44;
    sin_lut[ 16]= 46; sin_lut[ 17]= 49; sin_lut[ 18]= 51; sin_lut[ 19]= 53;
    sin_lut[ 20]= 55; sin_lut[ 21]= 57; sin_lut[ 22]= 59; sin_lut[ 23]= 61;
    sin_lut[ 24]= 62; sin_lut[ 25]= 63; sin_lut[ 26]= 64; sin_lut[ 27]= 64;
    sin_lut[ 28]= 64; sin_lut[ 29]= 64; sin_lut[ 30]= 64; sin_lut[ 31]= 63;
    sin_lut[ 32]= 62; sin_lut[ 33]= 61; sin_lut[ 34]= 59; sin_lut[ 35]= 57;
    sin_lut[ 36]= 55; sin_lut[ 37]= 53; sin_lut[ 38]= 51; sin_lut[ 39]= 49;
    sin_lut[ 40]= 46; sin_lut[ 41]= 44; sin_lut[ 42]= 41; sin_lut[ 43]= 39;
    sin_lut[ 44]= 36; sin_lut[ 45]= 33; sin_lut[ 46]= 30; sin_lut[ 47]= 27;
    sin_lut[ 48]= 24; sin_lut[ 49]= 21; sin_lut[ 50]= 18; sin_lut[ 51]= 15;
    sin_lut[ 52]= 12; sin_lut[ 53]=  9; sin_lut[ 54]=  6; sin_lut[ 55]=  3;
    sin_lut[ 56]=  0; sin_lut[ 57]= -3; sin_lut[ 58]= -6; sin_lut[ 59]= -9;
    sin_lut[ 60]= -12; sin_lut[ 61]= -15; sin_lut[ 62]= -18; sin_lut[ 63]= -21;
    sin_lut[ 64]= -24; sin_lut[ 65]= -27; sin_lut[ 66]= -30; sin_lut[ 67]= -33;
    sin_lut[ 68]= -36; sin_lut[ 69]= -39; sin_lut[ 70]= -41; sin_lut[ 71]= -44;
    sin_lut[ 72]= -46; sin_lut[ 73]= -49; sin_lut[ 74]= -51; sin_lut[ 75]= -53;
    sin_lut[ 76]= -55; sin_lut[ 77]= -57; sin_lut[ 78]= -59; sin_lut[ 79]= -61;
    sin_lut[ 80]= -62; sin_lut[ 81]= -63; sin_lut[ 82]= -64; sin_lut[ 83]= -64;
    sin_lut[ 84]= -64; sin_lut[ 85]= -64; sin_lut[ 86]= -64; sin_lut[ 87]= -63;
    sin_lut[ 88]= -62; sin_lut[ 89]= -61; sin_lut[ 90]= -59; sin_lut[ 91]= -57;
    sin_lut[ 92]= -55; sin_lut[ 93]= -53; sin_lut[ 94]= -51; sin_lut[ 95]= -49;
    sin_lut[ 96]= -46; sin_lut[ 97]= -44; sin_lut[ 98]= -41; sin_lut[ 99]= -39;
    sin_lut[100]= -36; sin_lut[101]= -33; sin_lut[102]= -30; sin_lut[103]= -27;
    sin_lut[104]= -24; sin_lut[105]= -21; sin_lut[106]= -18; sin_lut[107]= -15;
    sin_lut[108]= -12; sin_lut[109]=  -9; sin_lut[110]=  -6; sin_lut[111]=  -3;
    sin_lut[112]=   0; sin_lut[113]=   3; sin_lut[114]=   6; sin_lut[115]=   9;
    sin_lut[116]=  12; sin_lut[117]=  15; sin_lut[118]=  18; sin_lut[119]=  21;
    sin_lut[120]=  24; sin_lut[121]=  27; sin_lut[122]=  30; sin_lut[123]=  33;
    sin_lut[124]=  36; sin_lut[125]=  39; sin_lut[126]=  41; sin_lut[127]=  44;
end

// shift–add "multiply" by radius, then divide by 64
function signed [9:0] scale;
    input signed [7:0] s;
    input [9:0] r;
    reg signed [17:0] acc;
    begin
        acc = 0;
        if (r[0]) acc = acc + s;
        if (r[1]) acc = acc + (s <<< 1);
        if (r[2]) acc = acc + (s <<< 2);
        if (r[3]) acc = acc + (s <<< 3);
        if (r[4]) acc = acc + (s <<< 4);
        if (r[5]) acc = acc + (s <<< 5);
        if (r[6]) acc = acc + (s <<< 6);
        if (r[7]) acc = acc + (s <<< 7);
        if (r[8]) acc = acc + (s <<< 8);
        if (r[9]) acc = acc + (s <<< 9);

        scale = acc >>> 6;
    end
endfunction

// 8 angle directions = input angle + 0,45,90,...315
wire [8:0] ang8 [7:0];
assign ang8[0] = angle_in +   0;
assign ang8[1] = angle_in +  45;
assign ang8[2] = angle_in +  90;
assign ang8[3] = angle_in + 135;
assign ang8[4] = angle_in + 180;
assign ang8[5] = angle_in + 225;
assign ang8[6] = angle_in + 270;
assign ang8[7] = angle_in + 315;

// Compute all 8 vectors every clock
integer i;
reg [8:0] a;
reg [15:0] prod;
reg [6:0] idx;
reg signed [7:0] s;
reg signed [7:0] c;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        for (i=0;i<8;i=i+1) begin
            sin_pix[i] <= 0;
            cos_pix[i] <= 0;
        end
    end else begin
        for (i=0;i<8;i=i+1) begin
            reg [8:0] a = ang8[i];
            if (a >= 360) begin
              a = a - 360;
            end

            // idx = (a * 91) >> 7  implemented as shift-add: (a<<6 + a<<4 + a<<3 + a<<1 + a) >> 7
            prod = (a << 6) + (a << 4) + (a << 3) + (a << 1) + a;
            idx = prod[15:7]; // equivalent to >>7

            s = sin_lut[idx];
            c = sin_lut[(idx + 32) & 7'h7F];

            // produce centered offsets (no +200)
            sin_pix[i] <= scale(s, radius);
            cos_pix[i] <= scale(c, radius);
        end
    end
end

endmodule