`include "seq_detector_pkg.sv"
import seq_detector_pkg::*;

module seq_detector (
	input logic clk, rst_n, in_bit,
	output logic seq_detected
);

	state_t current_state, next_state;
	
	always_comb begin
		case (current_state)
			S0: next_state = in_bit ? S1 : S0;
			S1: next_state = in_bit ? S1 : S2;
			S2: next_state = in_bit ? S3 : S0;
			S3: next_state = in_bit ? S4 : S2;
			S4: next_state = in_bit ? S1 : S2;
			default: next_state = S0;
		endcase
	end
	
	always_ff @(posedge clk or negedge rst_n) begin
		if (! rst_n) begin
			current_state <= S0;
		end
		else current_state <= next_state;
	end

	always_comb begin
		 if (current_state == S4)
			  seq_detected = 1'b1;
		 else
			  seq_detected = 1'b0;
	end

endmodule