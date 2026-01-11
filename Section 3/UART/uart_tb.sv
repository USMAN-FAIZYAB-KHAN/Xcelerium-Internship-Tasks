`timescale 1ns / 1ps

module uart_tb();

    // Inputs
    logic clk;
    logic reset;
    logic [7:0] din;
    logic s_tick;
    logic tx_en;
    logic [10:0] dvsr;

    // Outputs
    logic tx;
    logic tx_done_tick;

    // Instantiate Baud Generator
    baud_gen bgen_inst (
        .clk(clk),
        .reset(reset),
        .dvsr(dvsr),
        .tick(s_tick)
    );

    // Instantiate UART Transmitter
    uart_tx #(
        .DBIT(8),
        .SB_TICK(16)
    ) dut (
        .clk(clk),
        .reset(reset),
        .din(din),
        .s_tick(s_tick),
        .tx_en(tx_en),
        .tx(tx),
        .tx_done_tick(tx_done_tick)
    );

    // 1. Clock Generation (50 MHz -> 20ns period)
    always #10 clk = ~clk;

    // 2. Test Sequence
    initial begin
        // Initialize signals
        clk = 0;
        reset = 1;
        tx_en = 0;
        din = 8'h00;
        dvsr = 11'd326; // For 9600 baud with 50MHz clock

        // Reset the system
        #100;
        reset = 0;
        #100;

        // --- Transmit 0x39 (Binary: 0011 1001) ---
        // Expecting: Start(0), LSB First (1,0,0,1,1,1,0,0), Stop(1)
        wait(clk == 0); // Align with clock
        din = 8'h39; 
        tx_en = 1;
        #20;            // Pulse for one clock cycle
        tx_en = 0;

        // Wait for completion
        @(posedge tx_done_tick);
        $display("Transmission Complete at time %t", $time);

        #5000; // Extra padding to see idle state
        $stop;
    end

endmodule