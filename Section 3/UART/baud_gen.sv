module baud_gen (
    input  logic        clk, 
    input  logic        reset,
    input  logic [10:0] dvsr,
    output logic        tick
);
    // Declaration
    logic [10:0] r_reg;
    logic [10:0] r_next;

    // Register
    always_ff @(posedge clk, posedge reset) begin
        if (reset)
            r_reg <= 0;
        else
            r_reg <= r_next;
    end

    // Next_state logic
    assign r_next = (r_reg == dvsr) ? 0 : r_reg + 1;

    // Output logic
    assign tick = (r_reg == 1);

endmodule