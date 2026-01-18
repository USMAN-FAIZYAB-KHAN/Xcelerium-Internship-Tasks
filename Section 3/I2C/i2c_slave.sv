import i2c_pkg::*;

module i2c_slave #(
    parameter SLAVE_ADDR = 76
)(
    input  logic clk,
    input  logic rst_n,
    input  logic scl,
    inout  wire  sda,
    input  logic [11:0] data_in, 
    output logic [11:0] data_out,
    output logic done
);

    state_t state, next_state;
    logic [3:0] bit_cnt, bit_cnt_next;
    logic [7:0] addr_reg, addr_next;
    logic [11:0] shift_reg, shift_reg_next;
    logic sda_out, sda_out_next;

    // Signal synchronization and edge detection
    logic scl_sync, scl_prev, sda_sync, sda_prev;
    always_ff @(posedge clk) begin
        scl_sync <= scl; scl_prev <= scl_sync; // Sync SCL to local clock
        sda_sync <= sda; sda_prev <= sda_sync; // Sync SDA to local clock
    end

    // Detect I2C protocol specific conditions
    wire start_cond = (scl_sync && sda_prev && !sda_sync); // SDA falls while SCL high
    wire stop_cond  = (scl_sync && !sda_prev && sda_sync); // SDA rises while SCL high
    wire scl_rise   = (!scl_prev && scl_sync);            // SCL rising edge
    wire scl_fall   = (scl_prev && !scl_sync);            // SCL falling edge

    // Sequential state and register updates
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            bit_cnt <= 0;
            shift_reg <= 0;
            addr_reg <= 0;
            sda_out <= 1;
        end else begin
            state <= next_state;
            bit_cnt <= bit_cnt_next;
            shift_reg <= shift_reg_next;
            addr_reg <= addr_next;
            sda_out <= sda_out_next;
        end
    end

    // Combinational logic for FSM transitions
    always_comb begin
        next_state = state;
        bit_cnt_next = bit_cnt;
        shift_reg_next = shift_reg;
        addr_next = addr_reg;
        sda_out_next = sda_out;
        done = 0;

        case (state)
            IDLE: begin
                sda_out_next = 1;
                bit_cnt_next = 0;
                if (start_cond) next_state = START;
            end

            START: if (scl_fall) next_state = ADDR; // Wait for first clock fall

            ADDR: begin
                if (scl_rise) begin
                    addr_next = {addr_reg[6:0], sda_sync}; // Shift in address bits
                    bit_cnt_next = bit_cnt + 1;
                end
                if (bit_cnt == 8 && scl_fall) begin
                    if (addr_reg[7:1] == SLAVE_ADDR) begin
                        next_state = ACK_1;
                        sda_out_next = 0; // Drive SDA low to ACK
                    end else next_state = IDLE; // Address mismatch
                    bit_cnt_next = 0;
                end
            end

            ACK_1: if (scl_fall) begin
                bit_cnt_next = 0;
                next_state = DATA_1;
                sda_out_next = (addr_reg[0]) ? data_in[11] : 1'b1; // Setup first bit if Read
            end

            DATA_1: begin
                if (scl_rise && !addr_reg[0]) // Capture SDA on write
                    shift_reg_next = {shift_reg[10:0], sda_sync};
                
                if (scl_fall) begin
                    bit_cnt_next = bit_cnt + 1;
                    if (bit_cnt == 7) begin
                        next_state = ACK_2;
                        sda_out_next = (addr_reg[0]) ? 1'b1 : 1'b0; // Master NACK/ACK or Slave ACK
                    end else if (addr_reg[0]) begin
                        sda_out_next = data_in[10 - bit_cnt]; // Shift out next read bit
                    end
                end
            end

            ACK_2: if (scl_fall) begin
                bit_cnt_next = 0;
                if (addr_reg[0] && sda_sync) next_state = IDLE; // Exit if Master NACKs Read
                else begin
                    next_state = DATA_2;
                    sda_out_next = (addr_reg[0]) ? data_in[3] : 1'b1; // Start next byte
                end
            end

            DATA_2: begin
                if (scl_rise && !addr_reg[0] && bit_cnt < 4) // Capture remaining 4 write bits
                    shift_reg_next = {shift_reg[10:0], sda_sync};

                if (scl_fall) begin
                    bit_cnt_next = bit_cnt + 1;
                    if (bit_cnt == 7) begin
                        next_state = ACK_3;
                        sda_out_next = (addr_reg[0]) ? 1'b1 : 1'b0;
                    end else if (addr_reg[0]) begin
                        sda_out_next = (bit_cnt < 3) ? data_in[2 - bit_cnt] : 1'b0; // Shift remaining bits
                    end
                end
            end

            ACK_3: if (scl_fall) begin
                sda_out_next = 1; // Release SDA bus
                next_state = STOP;
            end

            STOP: if (stop_cond) begin
                done = 1; // Pulse transaction complete
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    assign data_out = shift_reg;
    assign sda = (sda_out == 0) ? 1'b0 : 1'bz; // Drive 0 or high-impedance

endmodule