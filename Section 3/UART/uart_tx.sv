import uart_pkg::*;

module uart_tx #(
    parameter DBIT = 8, // Number of Data Bits
    parameter SB_TICK = 16, // Number of S_Ticks for Stop Bit
    parameter PAR_MODE = 0  // 0: No Parity, 1: Even Parity, 2: Odd Parity
)(
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] din, // Parallel Data Input
    input  logic       s_tick, // Sampling Tick
    input  logic       tx_en, // Transmit Enable
    output logic       tx, // Serial Data Output
    output logic       tx_done_tick // Transmission Done Flag
);

    state_type current_state, next_state;

    logic [3:0] s_reg, s_next; // Sampling Tick Counter
    logic [2:0] n_reg, n_next; // Data Bit Counter
    logic [7:0] b_reg, b_next; // Data Shift Register
    logic tx_reg, tx_next;
    logic p_reg, p_next; // Parity Bit

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
            s_reg  <= 0;
            n_reg  <= 0;
            b_reg  <= 0;
            tx_reg <= 1'b1;
            p_reg  <= 1'b0;
        end else begin
            current_state <= next_state;
            s_reg  <= s_next;
            n_reg  <= n_next;
            b_reg  <= b_next;
            tx_reg <= tx_next;
            p_reg  <= p_next;
        end
    end

    // Next State Logic
    always_comb begin
        next_state = current_state;
        s_next = s_reg;
        n_next = n_reg;
        b_next = b_reg;
        tx_next = tx_reg;
        p_next = p_reg;
        tx_done_tick = 1'b0;

        case (current_state)
            IDLE: begin
                tx_next = 1'b1;
                // Start transmission on tx_en
                if (tx_en) begin
                    next_state = START;
                    s_next = 0;
                    b_next = din;
                    // Calculate parity bit based on PAR_MODE
                    if (PAR_MODE == 1)      p_next = ^din;      // Even: XOR reduction
                    else if (PAR_MODE == 2) p_next = ~(^din);   // Odd: XNOR reduction
                end
            end

            START: begin
                // Transmit Start Bit (0)
                tx_next = 1'b0;
                if (s_tick) begin
                    if (s_reg == 15) begin
                        next_state = DATA;
                        s_next = 0;
                        n_next = 0;
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end

            DATA: begin
                tx_next = b_reg[0];
                if (s_tick) begin
                    if (s_reg == 15) begin
                        s_next = 0;
                        b_next = b_reg >> 1;
                        if (n_reg == (DBIT - 1)) begin
                            // Conditional transition based on PAR_MODE
                            if (PAR_MODE > 0) next_state = PARITY;
                            else              next_state = STOP;
                        end else begin
                            n_next = n_reg + 1;
                        end
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end

            PARITY: begin
                // Transmit Parity Bit
                tx_next = p_reg;
                if (s_tick) begin
                    if (s_reg == 15) begin
                        next_state = STOP;
                        s_next = 0;
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end

            STOP: begin
                // Transmit Stop Bit or Bits
                tx_next = 1'b1;
                if (s_tick) begin
                    if (s_reg == (SB_TICK - 1)) begin
                        // Transmission Complete
                        next_state = IDLE;
                        tx_done_tick = 1'b1;
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end
        endcase
    end

    assign tx = tx_reg;

endmodule