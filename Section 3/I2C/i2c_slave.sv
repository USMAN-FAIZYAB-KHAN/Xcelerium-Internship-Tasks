module i2c_slave (
    input  logic clk,
    input  logic rst_n,
    input  logic scl,
    inout  wire  sda,
    output logic [11:0] rx_data,
    output logic done
);

    typedef enum logic [3:0] {IDLE, START, ADDR, ACK_1, DATA_1, ACK_2, DATA_2, ACK_3, STOP} state_t;
    localparam [6:0] slave_addr_val = 7'd52;
    state_t state, next_state;
    
    logic [3:0] bit_cnt, bit_cnt_next;
    logic [7:0] addr_reg, addr_next;
    logic [11:0] shift_reg, shift_reg_next;
    logic sda_out, sda_out_next;

    logic scl_sync, scl_prev, sda_sync, sda_prev;
    always_ff @(posedge clk) begin
        scl_sync <= scl; scl_prev <= scl_sync;
        sda_sync <= sda; sda_prev <= sda_sync;
    end

    wire start_cond = (scl_sync && sda_prev && !sda_sync);
    wire scl_rise = (!scl_prev && scl_sync);
    wire scl_fall = (scl_prev && !scl_sync);
    wire stop_cond = (scl_sync && !sda_prev && sda_sync);
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            bit_cnt   <= 0;
            shift_reg <= 0;
            addr_reg  <= 0;
            sda_out   <= 1;
        end else if (start_cond) begin
            state     <= START;
            bit_cnt   <= 0;
            sda_out   <= 1;
        end else if (stop_cond) begin
            state     <= IDLE;
            bit_cnt   <= 0;
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
        sda_out_next   = sda_out;
        done           = 0;

        case (state)
            IDLE: begin
                sda_out_next = 1;
                bit_cnt_next = 0;
            end
            
            START: begin
                if (scl_fall) next_state = ADDR;
            end

            ADDR: begin
                if (scl_rise) begin
                    addr_next = {addr_reg[6:0], sda_sync};
                    bit_cnt_next = bit_cnt + 1;
                end
                if (bit_cnt == 8 && scl_fall) begin
                    if (addr_reg[7:1] == slave_addr_val && addr_reg[0] == 1'b0) begin
                        next_state   = ACK_1;
                        sda_out_next = 0;
                        bit_cnt_next = 0;
                    end else begin
                        next_state   = IDLE;
                    end
                end
            end

            ACK_1: begin
                if (scl_fall) begin
                    sda_out_next = 1;
                    next_state   = DATA_1;
                end
            end

            DATA_1: begin
                if (scl_rise) begin
                    shift_reg_next = {shift_reg[10:0], sda_sync};
                    bit_cnt_next = bit_cnt + 1;
                end
                if (bit_cnt == 8 && scl_fall) begin
                    next_state   = ACK_2;
                    sda_out_next = 0;
                    bit_cnt_next = 0;
                end
            end

            ACK_2: begin
                if (scl_fall) begin
                    sda_out_next = 1;
                    next_state   = DATA_2;
                end
            end

            DATA_2: begin
                if (scl_rise) begin
                    if (bit_cnt < 4) begin
                        shift_reg_next = {shift_reg[10:0], sda_sync};
                    end
                    bit_cnt_next = bit_cnt + 1;
                end
                if (bit_cnt == 8 && scl_fall) begin
                    next_state   = ACK_3;
                    sda_out_next = 0;
                    bit_cnt_next = 0;
                end
            end

            ACK_3: begin
                if (scl_fall) begin
                    sda_out_next = 1;
                    next_state   = STOP;
                end
            end

            STOP: begin
                if (stop_det) begin
                    next_state = IDLE;
                    done       = 1;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    assign rx_data = shift_reg;
    assign sda = (sda_out == 0) ? 1'b0 : 1'bz;

endmodule