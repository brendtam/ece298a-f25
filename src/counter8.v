module counter8 (
	input clk,
	input en,
	input rst_n,
	input load,
	input [7:0] load_in,
	output [7:0] out
)

reg [7:0] bits = 0;
wire [7:0] bits1 = bits;

// tri state output
assign out = (en == 1'b1) ? bits : 1'bz;

always @(posedge clk or negedge rst_n) begin
	// async reset
	if (~rst_n) begin
		bits <= 0;
	end else begin
		// sync load
		if (load) begin
			bits <= load_in;
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
	
