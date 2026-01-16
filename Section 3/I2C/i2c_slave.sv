module i2c_slave (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        scl,
    inout  wire         sda,
    input  logic [11:0] data_in,     // data slave sends
    output logic [11:0] data_out,    // data slave receives
    output logic        done
);

    typedef enum logic [3:0] {
        IDLE,
        START,
        ADDR,
        ACK_ADDR,
        RX_BYTE1,
        ACK_RX1,
        RX_BYTE2,
        ACK_RX2,
        TX_BYTE1,
        RX_ACK_TX1,
        TX_BYTE2,
        RX_ACK_TX2,
        STOP_STATE
    } state_t;

    state_t state, next_state;

    localparam [6:0] SLAVE_ADDR = 7'd7;

    logic [3:0] bit_cnt, bit_cnt_next;
    logic [7:0] shift_reg, shift_reg_next;
    logic [7:0] addr_reg, addr_next;
    logic       sda_out, sda_out_next;

    logic scl_sync, scl_prev, sda_sync, sda_prev;
    always_ff @(posedge clk) begin
        scl_sync <= scl;  scl_prev <= scl_sync;
        sda_sync <= sda;  sda_prev <= sda_sync;
    end

    wire scl_rise   =  scl_sync & ~scl_prev;
    wire scl_fall   = ~scl_sync &  scl_prev;
    wire start_cond =  scl_sync &  sda_prev & ~sda_sync;
    wire stop_cond  =  scl_sync & ~sda_prev &  sda_sync;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            bit_cnt   <= 0;
            shift_reg <= 0;
            addr_reg  <= 0;
            data_out  <= 0;
            sda_out   <= 1;
        end else begin
            state     <= next_state;
            bit_cnt   <= bit_cnt_next;
            shift_reg <= shift_reg_next;
            addr_reg  <= addr_next;
            sda_out   <= sda_out_next;
        end
    end

    always_comb begin
        next_state     = state;
        bit_cnt_next   = bit_cnt;
        shift_reg_next = shift_reg;
        addr_next      = addr_reg;
        sda_out_next   = 1;
        done           = 0;

        case (state)

            IDLE: begin
                bit_cnt_next = 0;
                if (start_cond) next_state = START;
            end

            START: if (scl_fall) next_state = ADDR;

            ADDR: begin
                if (scl_rise) begin
                    addr_next    = {addr_reg[6:0], sda_sync};
                    bit_cnt_next = bit_cnt + 1;
                end
                if (bit_cnt == 8 && scl_fall) begin
                    if (addr_reg[7:1] == SLAVE_ADDR) begin
                        sda_out_next = 0; // ACK
                        bit_cnt_next = 0;
                        next_state   = ACK_ADDR;
                    end else next_state = IDLE;
                end
            end

            ACK_ADDR: if (scl_fall) begin
                sda_out_next = 1;
                if (addr_reg[0] == 1'b0)
                    next_state = RX_BYTE1;  // WRITE
                else begin
                    shift_reg_next = data_in[11:4];
                    next_state     = TX_BYTE1; // READ
                end
            end

            // -------- RX (WRITE) --------
            RX_BYTE1: begin
                if (scl_rise) begin
                    shift_reg_next = {shift_reg[6:0], sda_sync};
                    bit_cnt_next   = bit_cnt + 1;
                end
                if (bit_cnt == 8 && scl_fall) begin
                    data_out[11:4] = shift_reg;
                    bit_cnt_next   = 0;
                    sda_out_next   = 0;
                    next_state     = ACK_RX1;
                end
            end

            ACK_RX1: if (scl_fall) begin
                sda_out_next = 1;
                next_state   = RX_BYTE2;
            end

            RX_BYTE2: begin
                if (scl_rise) begin
                    shift_reg_next = {shift_reg[6:0], sda_sync};
                    bit_cnt_next   = bit_cnt + 1;
                end
                if (bit_cnt == 8 && scl_fall) begin
                    data_out[3:0] = shift_reg[7:4];
                    bit_cnt_next  = 0;
                    sda_out_next  = 0;
                    next_state    = ACK_RX2;
                end
            end

            ACK_RX2: if (scl_fall) begin
                sda_out_next = 1;
                next_state   = STOP_STATE;
            end

            // -------- TX (READ) --------
            TX_BYTE1: begin
                if (scl_fall) begin
                    sda_out_next   = shift_reg[7];
                    shift_reg_next = {shift_reg[6:0], 1'b0};
                    bit_cnt_next   = bit_cnt + 1;
                end
                if (bit_cnt == 8 && scl_fall) begin
                    bit_cnt_next   = 0;
                    sda_out_next   = 1;
                    next_state     = RX_ACK_TX1;
                end
            end

            RX_ACK_TX1: if (scl_rise) begin
                if (!sda_sync) begin
                    shift_reg_next = {data_in[3:0], 4'b0000};
                    next_state     = TX_BYTE2;
                end else next_state = STOP_STATE;
            end

            TX_BYTE2: begin
                if (scl_fall) begin
                    sda_out_next   = shift_reg[7];
                    shift_reg_next = {shift_reg[6:0], 1'b0};
                    bit_cnt_next   = bit_cnt + 1;
                end
                if (bit_cnt == 8 && scl_fall) begin
                    sda_out_next = 1;
                    next_state   = RX_ACK_TX2;
                end
            end

            RX_ACK_TX2: if (scl_rise) next_state = STOP_STATE;

            STOP_STATE: if (stop_cond) begin
                done       = 1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Open-drain SDA
    assign sda = (sda_out == 0) ? 1'b0 : 1'bz;

endmodule
