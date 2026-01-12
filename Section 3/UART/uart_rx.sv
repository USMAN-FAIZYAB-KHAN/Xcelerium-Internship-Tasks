import uart_pkg::*;

module uart_rx #(
    parameter DBIT = 8, // Number of Data Bits   
    parameter SB_TICK = 16, // Number of S_Ticks for Stop Bit
    parameter PAR_MODE = 0 // 0: None, 1: Even, 2: Odd
)(
    input  logic       clk, 
    input  logic       reset,
    input  logic       rx, // Serial Data Input
    input  logic       s_tick, // Sampling Tick
    output logic       rx_done_tick, // Reception Done Flag
    output logic       parity_err, // Parity Error Flag
    output logic [7:0] dout // Parallel Data Output
);

    // State Declaration
    state_type state_reg, state_next;

    // Internal Signals
    logic [3:0] s_reg, s_next; // Sampling Tick Counter
    logic [2:0] n_reg, n_next; // Data Bit Counter
    logic [7:0] b_reg, b_next; // Data Shift Register
    logic p_err_reg, p_err_next; // Parity Error

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state_reg <= IDLE;
            s_reg     <= 0;
            n_reg     <= 0;
            b_reg     <= 0;
            p_err_reg <= 0;
        end else begin
            state_reg <= state_next;
            s_reg     <= s_next;
            n_reg     <= n_next;
            b_reg     <= b_next;
            p_err_reg <= p_err_next;
        end
    end

    // Next State Logic
    always_comb begin
        state_next   = state_reg;
        rx_done_tick = 1'b0;
        s_next       = s_reg;
        n_next       = n_reg;
        b_next       = b_reg;
        p_err_next   = p_err_reg;

        case (state_reg)
            IDLE: begin
                // Wait for Start Bit
                if (~rx) begin 
                    state_next = START;
                    s_next     = 0;
                    p_err_next = 0;
                end
            end

            START: begin
                // Validate Start Bit in Middle of Bit Period
                if (s_tick) begin
                    if (s_reg == 7) begin 
                        state_next = DATA;
                        s_next     = 0;
                        n_next     = 0;
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end

            DATA: begin
                // Sample Data Bits
                if (s_tick) begin
                    if (s_reg == 15) begin 
                        s_next = 0;
                        // Shift in Received Bit
                        b_next = {rx, b_reg[7:1]};
                        // Check if all bits received 
                        if (n_reg == (DBIT - 1))
                            // Move to PARITY or STOP based on PAR_MODE
                            state_next = (PAR_MODE > 0) ? PARITY : STOP;
                        else
                            n_next = n_reg + 1;
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end

            PARITY: begin
                if (s_tick) begin
                    if (s_reg == 15) begin
                        s_next = 0;
                        state_next = STOP;
                        // Check Parity Error
                        if (PAR_MODE == 1)
                            p_err_next = (rx != (^b_reg));
                        else if (PAR_MODE == 2)
                            p_err_next = (rx == (^b_reg));
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end

            STOP: begin
                if (s_tick) begin
                    // Sample Stop Bit
                    if (s_reg == (SB_TICK - 1)) begin
                        state_next = IDLE;
                        rx_done_tick = 1'b1;
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end
            
            default: state_next = IDLE;
        endcase
    end

    assign dout = b_reg;
    assign parity_err = p_err_reg;

endmodule