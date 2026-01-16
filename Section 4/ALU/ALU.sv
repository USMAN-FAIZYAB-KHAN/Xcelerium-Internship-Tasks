import alu_pkg::*;

module ALU #(
    parameter N = 16
)(
    input  logic [N-1:0] A, B,
    input  alu_op_t      OP,
    output logic [N-1:0] RESULT,
    output logic         CARRY,
    output logic         ZERO
);

    always_comb begin
        CARRY  = 1'b0;
        RESULT = '0;
        
        case (OP)
            ADD:         {CARRY, RESULT} = A + B;
            SUB:         {CARRY, RESULT} = A - B;
            AND:         RESULT = A & B;
            OR:          RESULT = A | B;
            XOR:         RESULT = A ^ B;
            SHIFT_LEFT:  RESULT = A << B[3:0]; 
            SHIFT_RIGHT: RESULT = A >> B[3:0];
            default:     RESULT = '0;
        endcase
    end

    assign ZERO = (RESULT == 0);

endmodule