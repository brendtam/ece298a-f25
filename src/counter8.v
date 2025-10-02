module tt_um_counter8 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

assign uio_out[7:1] = 0;
assign uio_oe  = 0;

reg [7:0] bits = 0;
wire [7:0] bits1 = bits;
assign uo_out = bits;

// tri state output
assign uio_out[0] = uio_in[1];

wire _unused = &{ena, clk, rst_n, 1'b0};

always @(posedge clk or negedge rst_n) begin
	// async reset
	if (~rst_n) begin
		bits <= 0;
	end else begin
		// sync load
		if (uio_in[0]) begin
			bits <= ui_in;
		end else begin
			// 8 bit counter
			bits[0] <= ~bits1[0];
			bits[1] <= (bits1[0]) ^ bits[1];
			bits[2] <= (bits1[0] & bits1[1]) ^ bits[2];
			bits[3] <= (bits1[0] & bits1[1] & bits1[2]) ^ bits[3];
			bits[4] <= (bits1[0] & bits1[1] & bits1[2] & bits1[3]) ^ bits[4];
			bits[5] <= (bits1[0] & bits1[1] & bits1[2] & bits1[3] & bits1[4]) ^ bits[5];
			bits[6] <= (bits1[0] & bits1[1] & bits1[2] & bits1[3] & bits1[4] & bits1[5]) ^ bits[6];
			bits[7] <= (bits1[0] & bits1[1] & bits1[2] & bits1[3] & bits1[4] & bits1[5] & bits1[6]) ^ bits[7];
		end
	end
end

endmodule
	
