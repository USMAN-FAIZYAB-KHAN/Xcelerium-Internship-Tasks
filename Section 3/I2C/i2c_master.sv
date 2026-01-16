import i2c_pkg::*;

module i2c_master (
    input  logic        clk,
    input  logic        tick_4x,    // Pulse at 4x SCL frequency
    input  logic        rst_n,
    input  logic        enable,
    input  logic        rw,         // 0 for Write, 1 for Read
    input  logic [6:0]  slave_addr, // 7-bit destination address
    input  logic [11:0] data_in,    // 12-bit data to send (Write)
    output logic [11:0] data_out,   // 12-bit data received (Read)
    output logic        ack_err,    // High if slave NACKs
    inout  wire         sda,
    inout  wire         scl,
    output logic        done
);

    // FSM States
    typedef enum logic [3:0] {
        IDLE, START, ADDR, ACK1, 
        TX_DATA1, ACK2, TX_DATA2, ACK3,   // Write Path
        RX_DATA1, M_ACK, RX_DATA2, M_NACK, // Read Path
        STOP
    } master_state_t;

    master_state_t state, next_state;

    logic [1:0]  phase;
    logic [3:0]  bit_cnt, bit_cnt_next;
    logic [11:0] shift_reg, shift_reg_next;
    logic        sda_out, scl_out;
    logic        ack_err_next;

    // --- Clock Phase Generator ---
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            phase     <= 2'b00;
            bit_cnt   <= 0;
            shift_reg <= 0;
            ack_err   <= 0;
        end else if (tick_4x) begin
            if (phase == 2'b11) begin
                phase     <= 2'b00;
                state     <= next_state;
                bit_cnt   <= bit_cnt_next;
                shift_reg <= shift_reg_next;
                ack_err   <= ack_err_next;
            end else begin
                phase <= phase + 1;
            end
        end
    end

    // --- Master Logic ---
    always_comb begin
        next_state     = state;
        bit_cnt_next   = bit_cnt;
        shift_reg_next = shift_reg;
        ack_err_next   = ack_err;
        sda_out        = 1;
        scl_out        = 1;
        done           = 0;

        case (state)
            IDLE: begin
                if (enable) begin
                    next_state     = START;
                    shift_reg_next = data_in;
                    ack_err_next   = 0;
                end
            end

            START: begin
                // SCL stays High while SDA goes Low
                sda_out = (phase == 2'b00) ? 1 : 0;
                scl_out = 1;
                if (phase == 2'b11) next_state = ADDR;
            end

            ADDR: begin
                sda_out      = (bit_cnt < 7) ? slave_addr[6-bit_cnt] : rw;
                scl_out      = (phase == 2'b01 || phase == 2'b10) ? 1 : 0;
                bit_cnt_next = (phase == 2'b11) ? (bit_cnt == 7 ? 0 : bit_cnt + 1) : bit_cnt;
                if (bit_cnt == 7 && phase == 2'b11) next_state = ACK1;
            end

            ACK1: begin
                sda_out = 1; // Release bus
                scl_out = (phase == 2'b01 || phase == 2'b10) ? 1 : 0;
                // Sample ACK at middle of High pulse (Phase 2)
                if (phase == 2'b10 && sda != 0) ack_err_next = 1;
                if (phase == 2'b11) next_state = (rw) ? RX_DATA1 : TX_DATA1;
            end

            // -------- WRITE PATH --------
            TX_DATA1: begin
                sda_out      = shift_reg[11-bit_cnt];
                scl_out      = (phase == 2'b01 || phase == 2'b10) ? 1 : 0;
                bit_cnt_next = (phase == 2'b11) ? (bit_cnt == 7 ? 0 : bit_cnt + 1) : bit_cnt;
                if (bit_cnt == 7 && phase == 2'b11) next_state = ACK2;
            end

            ACK2: begin
                sda_out = 1;
                scl_out = (phase == 2'b01 || phase == 2'b10) ? 1 : 0;
                if (phase == 2'b10 && sda != 0) ack_err_next = 1;
                if (phase == 2'b11) next_state = TX_DATA2;
            end

            TX_DATA2: begin
                // Sending 4 bits + 4 padding bits to fulfill 8-bit byte protocol
                sda_out      = (bit_cnt < 4) ? shift_reg[3-bit_cnt] : 0;
                scl_out      = (phase == 2'b01 || phase == 2'b10) ? 1 : 0;
                bit_cnt_next = (phase == 2'b11) ? (bit_cnt == 7 ? 0 : bit_cnt + 1) : bit_cnt;
                if (bit_cnt == 7 && phase == 2'b11) next_state = ACK3;
            end

            ACK3: begin
                sda_out = 1;
                scl_out = (phase == 2'b01 || phase == 2'b10) ? 1 : 0;
                if (phase == 2'b10 && sda != 0) ack_err_next = 1;
                if (phase == 2'b11) next_state = STOP;
            end

            // -------- READ PATH --------
            RX_DATA1: begin
                sda_out = 1; // Input mode
                scl_out = (phase == 2'b01 || phase == 2'b10) ? 1 : 0;
                if (phase == 2'b10) shift_reg_next[11-bit_cnt] = sda;
                bit_cnt_next = (phase == 2'b11) ? (bit_cnt == 7 ? 0 : bit_cnt + 1) : bit_cnt;
                if (bit_cnt == 7 && phase == 2'b11) next_state = M_ACK;
            end

            M_ACK: begin
                sda_out = 0; // Master pulls SDA Low to ACK the byte
                scl_out = (phase == 2'b01 || phase == 2'b10) ? 1 : 0;
                if (phase == 2'b11) next_state = RX_DATA2;
            end

            RX_DATA2: begin
                sda_out = 1;
                scl_out = (phase == 2'b01 || phase == 2'b10) ? 1 : 0;
                if (phase == 2'b10 && bit_cnt < 4) shift_reg_next[3-bit_cnt] = sda;
                bit_cnt_next = (phase == 2'b11) ? (bit_cnt == 7 ? 0 : bit_cnt + 1) : bit_cnt;
                if (bit_cnt == 7 && phase == 2'b11) next_state = M_NACK;
            end

            M_NACK: begin
                sda_out = 1; // Master sends NACK (SDA High) to stop slave
                scl_out = (phase == 2'b01 || phase == 2'b10) ? 1 : 0;
                if (phase == 2'b11) next_state = STOP;
            end

            STOP: begin
                // SCL goes High while SDA is Low, then SDA goes High
                sda_out = (phase == 2'b00 || phase == 2'b01) ? 0 : 1;
                scl_out = (phase == 2'b00) ? 0 : 1;
                if (phase == 2'b11) begin
                    done       = 1;
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Tri-state buffer logic
    assign sda = (sda_out == 0) ? 1'b0 : 1'bz;
    assign scl = (scl_out == 0) ? 1'b0 : 1'bz;
    assign data_out = shift_reg;

endmodule