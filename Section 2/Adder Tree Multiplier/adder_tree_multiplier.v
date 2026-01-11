module adder_tree_multiplier(
   input [7:0] a, b, 
   input clk, ena, enb,
   output [15:0] p
);
   reg [7:0] a_reg, b_reg;
   reg [15:0] p_reg;
	
	wire [7:0] partial_product [0:7];
	wire [15:0] sum [0:6];
	
	assign partial_product[0] = a_reg & {8{b_reg[0]}};
	assign partial_product[1] = a_reg & {8{b_reg[1]}};
	assign partial_product[2] = a_reg & {8{b_reg[2]}};
	assign partial_product[3] = a_reg & {8{b_reg[3]}};
	assign partial_product[4] = a_reg & {8{b_reg[4]}};
	assign partial_product[5] = a_reg & {8{b_reg[5]}};
	assign partial_product[6] = a_reg & {8{b_reg[6]}};
	assign partial_product[7] = a_reg & {8{b_reg[7]}};
	
	
	// Level 1
	adder #(16) adder11 (.a({8'b0, partial_product[0]}), .b({7'b0, partial_product[1], 1'b0}),
								.s(sum[0]), .cin(1'b0), .co());
								
	adder #(16) adder12 (.a({6'b0, partial_product[2], 2'b0}), .b({5'b0, partial_product[3], 3'b0}),
								.s(sum[1]), .cin(1'b0), .co());
								
	adder #(16) adder13 (.a({4'b0, partial_product[4], 4'b00}), .b({3'b0, partial_product[5], 5'b0}),
								.s(sum[2]), .cin(1'b0), .co());
	
	adder #(16) adder14 (.a({2'b0, partial_product[6], 6'b0}), .b({1'b0, partial_product[7], 7'b0}),
								.s(sum[3]), .cin(1'b0), .co());
	
	// Level 2
	adder #(16) adder21 (.a(sum[0]), .b(sum[1]), .s(sum[4]), .cin(1'b0), .co());
	adder #(16) adder22 (.a(sum[2]), .b(sum[3]), .s(sum[5]), .cin(1'b0), .co());
	
	// Level 3
	adder #(16) adder31 (.a(sum[4]), .b(sum[5]), .s(sum[6]), .cin(1'b0), .co());
	
	always @(posedge clk) begin
		if (ena) a_reg <= a;
		if (enb) b_reg <= b;
		p_reg <= sum[6];
	end
	
	assign p = p_reg;
	
endmodule