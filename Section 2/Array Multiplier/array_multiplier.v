module array_multiplier (
    input [7:0] a, b, 
    input clk, ena, enb,
    output [15:0] p
);
    reg [7:0] a_reg, b_reg;
    reg [15:0] p_reg;

    wire [6:0] carry;
    wire [7:0] sum [0:6];


    adder #(.N(8)) adder1 (.a({1'b0, a_reg[7:1] & {7{b_reg[0]}}}), .b(a_reg & {8{b_reg[1]}}), 
				.cin(1'b0), .co(carry[0]), .s(sum[0]));
    
    adder #(.N(8)) adder2 (.a({carry[0], sum[0][7:1]}), .b(a_reg & {8{b_reg[2]}}), .cin(1'b0),
				.co(carry[1]), .s(sum[1]));
				
    adder #(.N(8)) adder3 (.a({carry[1], sum[1][7:1]}), .b(a_reg & {8{b_reg[3]}}), .cin(1'b0),
				.co(carry[2]), .s(sum[2]));
				
    adder #(.N(8)) adder4 (.a({carry[2], sum[2][7:1]}), .b(a_reg & {8{b_reg[4]}}), .cin(1'b0),
				.co(carry[3]), .s(sum[3]));
				
    adder #(.N(8)) adder5 (.a({carry[3], sum[3][7:1]}), .b(a_reg & {8{b_reg[5]}}), .cin(1'b0),
				.co(carry[4]), .s(sum[4]));
				
    adder #(.N(8)) adder6 (.a({carry[4], sum[4][7:1]}), .b(a_reg & {8{b_reg[6]}}), .cin(1'b0),
				.co(carry[5]), .s(sum[5]));
				
    adder #(.N(8)) adder7 (.a({carry[5], sum[5][7:1]}), .b(a_reg & {8{b_reg[7]}}), .cin(1'b0),
				.co(carry[6]), .s(sum[6]));
    
    always @(posedge clk) begin
        if (ena) a_reg <= a;
        if (enb) b_reg <= b;
        p_reg <= {carry[6], sum[6], sum[5][0], sum[4][0], sum[3][0], sum[2][0], sum[1][0], sum[0][0], a_reg[0] & b_reg[0]};
    end

    assign p = p_reg;

endmodule