module shift_reg #(
	parameter N = 8
)(
	input clk, rst_n, shift_en, dir, d_in,
	output reg [N-1:0] q_out
);
	
	always @(posedge clk, negedge rst_n) begin
		if (rst_n == 1'b0)
			q_out <= {N{1'b0}};
		else if (shift_en) begin
			case (dir)
				1'b0:
					q_out <= {q_out[N-2:0], d_in};
				1'b1:
					q_out <= {d_in, q_out[N-1:1]};
			endcase
		end
	end
	
endmodule