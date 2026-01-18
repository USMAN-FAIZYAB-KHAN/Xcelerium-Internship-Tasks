import i2c_pkg::*;

module i2c_master (
    input  logic        clk,        
    input  logic        tick_4x,     
    input  logic        rst_n,       
    input  logic        enable,      
    input  logic        rw,          // 0 = Write, 1 = Read
    input  logic [6:0]  slave_addr,  
    input  logic [11:0] data_in,     // 12-bit data to write
    output logic [11:0] data_out,    // 12-bit data received
    inout  wire         sda,         // I2C serial data line
    inout  wire         scl,         // I2C serial clock line
    output logic        done,        // Transaction complete flag
    output logic        busy         // Master busy flag
);

    state_t current_state, next_state;

    logic [1:0] phase; 
    logic [2:0] bit_cnt;

    logic sda_out, scl_out;
    logic sda_sampled;     
    logic ack_sampled;      

    logic [7:0] read_byte1, read_byte2; // Temporary buffers for incoming data

    assign busy     = (current_state != IDLE);
    assign data_out = {read_byte1, read_byte2[7:4]};

    // Sequential logic for state transitions and bit counting
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            phase         <= 2'b00;
            bit_cnt       <= 3'd0;
        end else if (tick_4x) begin
            if (phase == 2'b11) begin
                phase         <= 2'b00;
                current_state <= next_state; // Transition state every 4 ticks

                // Increment bit counter during data/address phases
                if (current_state == ADDR || current_state == DATA_1 || current_state == DATA_2)
                    bit_cnt <= bit_cnt + 1;
                else
                    bit_cnt <= 3'd0;
            end else begin
                phase <= phase + 1; // Increment timing phase
            end
        end
    end

    // Sample SDA line during the middle of the SCL HIGH period
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sda_sampled <= 1'b0;
            ack_sampled <= 1'b1;
        end else if (tick_4x && phase == 2'b01) begin
            sda_sampled <= sda; // Sample data for read operations
            ack_sampled <= sda; // Sample ACK (0 = ACK, 1 = NACK)
        end
    end

    // Shift sampled SDA bits into the read buffers
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_byte1 <= 8'd0;
            read_byte2 <= 8'd0;
        end else if (tick_4x && phase == 2'b11) begin
            if (rw && current_state == DATA_1)
                read_byte1 <= {read_byte1[6:0], sda_sampled}; // Shift first byte

            if (rw && current_state == DATA_2)
                read_byte2 <= {read_byte2[6:0], sda_sampled}; // Shift second byte
        end
    end

    // Combinational logic for FSM and I2C signal generation
    always_comb begin
        next_state = current_state;
        sda_out    = 1'b1; // Default SDA to high (open-drain)
        scl_out    = 1'b1; // Default SCL to high
        done       = 1'b0;

        case (current_state)
            IDLE: begin
                if (enable) next_state = START; // Wait for enable to begin
            end

            START: begin
                next_state = ADDR;
                case (phase) // Generate Start Condition (SDA falling while SCL high)
                    2'b00: begin sda_out = 1; scl_out = 1; end
                    2'b01, 2'b10: begin sda_out = 0; scl_out = 1; end
                    2'b11: begin sda_out = 0; scl_out = 0; end
                endcase
            end

            ADDR: begin
                scl_out    = (phase == 2'b01 || phase == 2'b10); // Pulse SCL
                sda_out    = (bit_cnt < 7) ? slave_addr[6 - bit_cnt] : rw; // Send Addr + R/W
                next_state = (bit_cnt == 3'd7) ? ACK_1 : ADDR;
            end

            ACK_1: begin
                scl_out = (phase == 2'b01 || phase == 2'b10);
                if (phase == 2'b11)
                    next_state = ack_sampled ? STOP : DATA_1; // Stop if NACKed
            end

            DATA_1: begin
                scl_out    = (phase == 2'b01 || phase == 2'b10);
                sda_out    = rw ? 1'b1 : data_in[11 - bit_cnt]; // Drive data if writing
                next_state = (bit_cnt == 3'd7) ? ACK_2 : DATA_1;
            end

            ACK_2: begin
                scl_out = (phase == 2'b01 || phase == 2'b10);
                if (rw) begin
                    sda_out    = 1'b0; // Master ACKs slave during read
                    next_state = DATA_2;
                end else if (phase == 2'b11) begin
                    next_state = ack_sampled ? STOP : DATA_2; // Stop if NACKed
                end
            end

            DATA_2: begin
                scl_out    = (phase == 2'b01 || phase == 2'b10);
                sda_out    = rw ? 1'b1 : (bit_cnt < 4) ? data_in[3 - bit_cnt] : 1'b0;
                next_state = (bit_cnt == 3'd7) ? ACK_3 : DATA_2;
            end

            ACK_3: begin
                scl_out    = (phase == 2'b01 || phase == 2'b10);
                sda_out    = 1'b1; // Release SDA for NACK (end of read) or Slave ACK
                next_state = STOP;
            end

            STOP: begin
                next_state = IDLE;
                case (phase) // Generate Stop Condition (SDA rising while SCL high)
                    2'b00: begin sda_out = 0; scl_out = 0; end
                    2'b01: begin sda_out = 0; scl_out = 1; end
                    default: begin sda_out = 1; scl_out = 1; end
                endcase
                if (phase == 2'b11) done = 1'b1; // Trigger done at end of STOP
            end

            default: next_state = IDLE;
        endcase
    end

    assign sda = (sda_out == 1'b0) ? 1'b0 : 1'bz; // Drive 0 or let pull-up handle 1
    assign scl = (scl_out == 1'b0) ? 1'b0 : 1'bz; // Drive 0 or let pull-up handle 1

endmodule