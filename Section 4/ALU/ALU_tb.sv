import alu_pkg::*;

module ALU_tb;
    parameter N = 16;
    logic [N-1:0] A, B;
    alu_op_t OP;
    logic [N-1:0] RESULT;
    logic CARRY, ZERO;

	// for checking result
    logic [N-1:0] expected_result;
	logic expected_carry;
    logic expected_zero;

    ALU #(.N(N)) dut (.A(A), .B(B), .OP(OP), .RESULT(RESULT), .CARRY(CARRY), .ZERO(ZERO));

    initial begin
        $display("Time\t A		    B		       OP         		     RESULT              CARRY    ZERO       Status");
        $display("-------------------------------------------------------------------------------------------------------------");

        repeat (40) begin
            // Randomize inputs
            A = $urandom_range(0, 65535);
            OP = alu_op_t'($urandom_range(0, 6));

            // Constrain B based on the operation
            if (OP == SHIFT_LEFT || OP == SHIFT_RIGHT) 
                B = $urandom_range(0, 15); 
            else 
                B = $urandom_range(0, 65535);

            #10; // Wait for combinational logic
			
			expected_carry = 0;

            case (OP)
                ADD:         {expected_carry, expected_result} = A + B;
                SUB:         {expected_carry, expected_result} = A - B;
                AND:         expected_result = A & B;
                OR:          expected_result = A | B;
                XOR:         expected_result = A ^ B;
                SHIFT_LEFT:  expected_result = A << B;
                SHIFT_RIGHT: expected_result = A >> B;
                default:     expected_result = '0;
            endcase
			
			expected_zero = (expected_result == 0);

            // Verification Check
            if (RESULT === expected_result && CARRY === expected_carry && ZERO === expected_zero) begin
                $display("%0t\t %b\t\t %b\t\t %s\t\t\t %b\t\t\t %b\t %b\t [PASS]", 
                         $time, A, B, OP.name(), RESULT, CARRY, ZERO);
            end else begin
                $display("%0t\t %b\t\t %b\t\t %s\t\t\t %b\t\t\t %b\t %b\t [FAIL] Expected", 
                         $time, A, B, OP.name(), RESULT, CARRY, ZERO, expected_result);
            end
        end
        
        $display("-------------------------------------------------------------------------------------------------------------");
        $finish;
    end
endmodule