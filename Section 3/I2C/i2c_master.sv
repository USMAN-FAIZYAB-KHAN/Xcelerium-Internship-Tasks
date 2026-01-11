//module i2c_master (
//    input  logic        clk,
//    input  logic        tick_4x,
//    input  logic        rst_n,
//    input  logic        enable,
//    input  logic        rw,
//    input  logic [6:0]  slave_addr,
//    input  logic [11:0] data_in,
//    inout  wire         sda,    
//    inout  wire         scl,
//    output logic        done
//);
//
//    typedef enum logic [3:0] {
//        IDLE, START, ADDR, ACK_1, DATA_1, ACK_2, DATA_2, ACK_3, STOP
//    } state_t;
//    
//    state_t current_state, next_state;
//    
//    logic [1:0] phase;
//    logic [2:0] bit_cnt;
//    
//    logic sda_out;
//    logic scl_out;
//	 
//    always_ff @(posedge clk or negedge rst_n) begin
//        if (!rst_n) begin
//            current_state <= IDLE;
//            phase         <= 2'b00;
//            bit_cnt       <= 3'd0;
//        end else if (tick_4x) begin
//            if (phase == 2'b11) begin
//                phase         <= 2'b00;
//                current_state <= next_state;      
//                if (current_state == ADDR || current_state == DATA_1 || current_state == DATA_2)
//                    bit_cnt <= bit_cnt + 1;
//                else
//                    bit_cnt <= 3'd0;
//            end else begin
//                phase <= phase + 1;
//            end
//        end
//    end
//
//    always_comb begin
//        next_state = current_state;
//        sda_out    = 1'b1;
//        scl_out    = 1'b1;
//        done       = 1'b0;
//
//        case (current_state)
//            IDLE: begin
//                sda_out = 1'b1;
//                scl_out = 1'b1;
//                if (enable) next_state = START;
//            end
//
//            START: begin
//                next_state = ADDR;
//                case (phase)
//                    2'b00:        begin sda_out = 1; scl_out = 1; end 
//                    2'b01, 2'b10: begin sda_out = 0; scl_out = 1; end
//                    2'b11:        begin sda_out = 0; scl_out = 0; end
//                endcase
//            end
//
//            ADDR: begin
//                next_state = (bit_cnt == 3'd7) ? ACK_1 : ADDR;
//                sda_out = (bit_cnt < 7) ? slave_addr[6 - bit_cnt] : rw;
//                scl_out = (phase == 2'b01 || phase == 2'b10) ? 1'b1 : 1'b0;
//            end
//
//            ACK_1: begin
//                next_state = DATA_1;
//                sda_out = 1'b1;
//                scl_out = (phase == 2'b01 || phase == 2'b10) ? 1'b1 : 1'b0;
//            end
//
//            DATA_1: begin
//                next_state = (bit_cnt == 3'd7) ? ACK_2 : DATA_1;
//                sda_out = data_in[11 - bit_cnt];
//                scl_out = (phase == 2'b01 || phase == 2'b10) ? 1'b1 : 1'b0;
//            end
//
//            ACK_2: begin
//                next_state = DATA_2;
//                sda_out = 1'b1;
//                scl_out = (phase == 2'b01 || phase == 2'b10) ? 1'b1 : 1'b0;
//            end
//
//            DATA_2: begin
//                next_state = (bit_cnt == 3'd7) ? ACK_3 : DATA_2;
//                sda_out = (bit_cnt < 4) ? data_in[3 - bit_cnt] : 1'b0; 
//                scl_out = (phase == 2'b01 || phase == 2'b10) ? 1'b1 : 1'b0;
//            end
//
//            ACK_3: begin
//                next_state = STOP;
//                sda_out = 1'b1;
//                scl_out = (phase == 2'b01 || phase == 2'b10) ? 1'b1 : 1'b0;
//            end
//
//            STOP: begin
//                next_state = IDLE;
//                case (phase)
//                    2'b00:        begin sda_out = 0; scl_out = 0; end
//                    2'b01:        begin sda_out = 0; scl_out = 1; end
//                    2'b10, 2'b11: begin sda_out = 1; scl_out = 1; end
//                endcase
//                if (phase == 2'b11) done = 1'b1;
//            end
//
//            default: next_state = IDLE;
//        endcase
//    end
//
//    assign sda = (sda_out == 1'b0) ? 1'b0 : 1'bz;
//    assign scl = (scl_out == 1'b0) ? 1'b0 : 1'bz;
//
//endmodule