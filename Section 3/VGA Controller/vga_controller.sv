`include "vga_pkg.sv"
import vga_pkg::*;

module vga_controller (
    input  logic        clk_25mhz, // 25 MHz clock input
    input  logic        rst,       // asynchronous active-high reset
    input  logic        en,        // enable signal
    output logic        hsync,     // active low horizontal sync signal
    output logic        vsync,     // active low vertical sync signal
    output logic [18:0] sram_addr, // SRAM address for pixel data
    output logic        video_on   // high when pixel is in visible area  
);

    // horizontal state register
    state_t h_state_reg, h_state_next;
    // vertical state register
    state_t v_state_reg, v_state_next;

    // counters and address registers
    logic [9:0] h_cnt_reg, h_cnt_next;
    logic [9:0] v_cnt_reg, v_cnt_next;
    logic [18:0] addr_reg, addr_next;
    
    // end of line signal
    logic h_end_of_line;

    always_ff @(posedge clk_25mhz or posedge rst) begin
        if (rst) begin
            h_state_reg <= VISIBLE;
            v_state_reg <= VISIBLE;
            h_cnt_reg   <= 0;
            v_cnt_reg   <= 0;
            addr_reg    <= 0;
        end else if (en) begin
            h_state_reg <= h_state_next;
            v_state_reg <= v_state_next;
            h_cnt_reg   <= h_cnt_next;
            v_cnt_reg   <= v_cnt_next;
            addr_reg    <= addr_next;
        end
    end

    // Horizontal FSM
	always_comb begin
        h_state_next  = h_state_reg;
        h_cnt_next    = h_cnt_reg + 1;
        h_end_of_line = 1'b0;

        case (h_state_reg)
            VISIBLE: if (h_cnt_reg == H_ACTIVE - 1) begin
                h_cnt_next = 0;
                h_state_next = FRONT_PORCH;
            end
            FRONT_PORCH: if (h_cnt_reg == H_FP - 1) begin
                h_cnt_next = 0;
                h_state_next = SYNC_PULSE;
            end
            SYNC_PULSE: if (h_cnt_reg == H_SYNC - 1) begin
                h_cnt_next = 0;
                h_state_next = BACK_PORCH;
            end
            BACK_PORCH: if (h_cnt_reg == H_BP - 1) begin
                h_cnt_next = 0;
                h_state_next = VISIBLE;
                h_end_of_line = 1'b1;
            end
        endcase
    end

    // Vertical FSM
    always_comb begin
        v_state_next = v_state_reg;
        v_cnt_next   = v_cnt_reg;

        if (h_end_of_line) begin
            v_cnt_next = v_cnt_reg + 1;
            case (v_state_reg)
                VISIBLE: if (v_cnt_reg == V_ACTIVE - 1) begin
                    v_cnt_next = 0;
                    v_state_next = FRONT_PORCH;
                end
                FRONT_PORCH: if (v_cnt_reg == V_FP - 1) begin
                    v_cnt_next = 0;
                    v_state_next = SYNC_PULSE;
                end
                SYNC_PULSE: if (v_cnt_reg == V_SYNC - 1) begin
                    v_cnt_next = 0;
                    v_state_next = BACK_PORCH;
                end
                BACK_PORCH: if (v_cnt_reg == V_BP - 1) begin
                    v_cnt_next = 0;
                    v_state_next = VISIBLE;
                end
            endcase
        end
    end

    // Address Logic
    always_comb begin
        addr_next = addr_reg;
        if (h_state_reg == VISIBLE && v_state_reg == VISIBLE) begin
            addr_next = addr_reg + 1;
        // Reset address at end of frame
        end else if (v_state_reg == BACK_PORCH && v_cnt_reg == V_BP - 1 && h_end_of_line) begin
            addr_next = 0;
        end
    end

    // Output Assignments
    assign hsync    = (h_state_reg == SYNC_PULSE) ? 1'b0 : 1'b1;
    assign vsync    = (v_state_reg == SYNC_PULSE) ? 1'b0 : 1'b1;
    assign video_on = (h_state_reg == VISIBLE) && (v_state_reg == VISIBLE);
    assign sram_addr = addr_reg;

endmodule