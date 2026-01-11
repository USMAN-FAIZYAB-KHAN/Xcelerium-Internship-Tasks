module counter #(
	parameter N = 8
)(
	input clk, rst_n, en, up_dn,
	output reg [N-1:0] count
);
	
	always @(posedge clk, negedge rst_n) begin
		if (rst_n == 1'b0)
			count <= {N{1'b0}};
		else if (en == 1'b1) begin
			case (up_dn)
				1'b0: count <= count-1;
				1'b1: count <= count+1;
			endcase
		end
	end
	
endmodule