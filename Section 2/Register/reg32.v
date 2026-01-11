module reg32(
	output reg [31:0] q,
	input [31:0] d,
	input load, clk, rst_n
);

	always @(posedge clk, negedge rst_n) begin
		if (rst_n == 1'b0)
			q <= 32'h0000_0000;
		else if (load == 1'b1)
			q <= d;
	end
	
endmodule