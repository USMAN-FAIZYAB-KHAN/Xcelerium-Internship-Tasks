module uart_tx #(
    parameter DBIT = 8,
    parameter SB_TICK = 16 
)(
    input  logic       clk,
    input  logic       reset,
    input  logic [7:0] din,
    input  logic       s_tick,
    input  logic       tx_en,
    output logic       tx,
    output logic       tx_done_tick
);

    typedef enum logic [1:0] {IDLE, START, DATA, STOP} state_t;
    state_t current_state, next_state;

    logic [3:0] s_reg, s_next;
    logic [2:0] n_reg, n_next;
    logic [7:0] b_reg, b_next;
    logic tx_reg, tx_next;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            current_state <= IDLE;
            s_reg  <= 0;
            n_reg  <= 0;
            b_reg  <= 0;
            tx_reg <= 1'b1;
        end else begin
            current_state <= next_state;
            s_reg  <= s_next;
            n_reg  <= n_next;
            b_reg  <= b_next;
            tx_reg <= tx_next;
        end
    end

    always_comb begin
        next_state = current_state;
        s_next = s_reg;
        n_next = n_reg;
        b_next = b_reg;
        tx_next = tx_reg;
        tx_done_tick = 1'b0;

        case (current_state)
            IDLE: begin
                tx_next = 1'b1;
                if (tx_en) begin
                    next_state = START;
                    s_next = 0;
                    b_next = din;
                end
            end

            START: begin
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
                tx_next = b_reg[0]; // Send LSB first (Standard UART)
                if (s_tick) begin
                    if (s_reg == 15) begin
                        s_next = 0;
                        b_next = b_reg >> 1; // Shift right to get next bit
                        if (n_reg == (DBIT - 1))
                            next_state = STOP;
                        else
                            n_next = n_reg + 1;
                    end else begin
                        s_next = s_reg + 1;
                    end
                end
            end

            STOP: begin
                tx_next = 1'b1;
                if (s_tick) begin
                    if (s_reg == (SB_TICK - 1)) begin
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