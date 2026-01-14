import uart_pkg::*;
`timescale 1ns/1ps

// Interface Definition
interface uart_if(input logic clk);
    logic reset;
    logic [7:0] din;
    logic tx_en;
    logic s_tick;
    logic tx;
    logic tx_done;
    logic rx;
    logic [7:0] dout;
    logic rx_done;
  	logic parity_err;
    logic [2:0] current_state_tx;
    logic [2:0] current_state_rx;
endinterface

module uart_tb;

    bit clk;
    logic [10:0] dvsr;

    uart_if inf(clk);

    always #5 clk = ~clk; // 100MHz Clock

    assign dvsr = 11'd651; // For 9600 Baud Rate with 100MHz Clock

    baud_gen BAUD_UNIT (
        .clk(clk),
        .reset(inf.reset),
        .dvsr(dvsr),
        .tick(inf.s_tick)
    );

    // connect tx to rx for loopback
    assign inf.rx = inf.tx;

    // initialize uart transmitter
    uart_tx #(8, 16) DUT_TX (
        .clk(clk),
        .reset(inf.reset),
        .din(inf.din),
        .s_tick(inf.s_tick),
        .tx_en(inf.tx_en),
        .tx(inf.tx),
        .tx_done_tick(inf.tx_done)
    );

    // initialize uart receiver
    uart_rx #(8, 16) DUT_RX (
        .clk(clk),
        .reset(inf.reset),
        .rx(inf.rx),
        .s_tick(inf.s_tick),
        .rx_done_tick(inf.rx_done),
      	.parity_err(inf.parity_err),
        .dout(inf.dout)
    );

    // additional connections for coverage
    assign inf.current_state_tx = DUT_TX.current_state;
    assign inf.current_state_rx = DUT_RX.state_reg;
  
    mailbox #(uart_txn) gen2drv;
    mailbox #(uart_txn) gen2scb;
  	mailbox #(uart_txn) mon2scb;
  
  	generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;

    initial begin
        gen2drv = new();
        gen2scb = new();
        mon2scb = new();

        gen = new(gen2drv, gen2scb);
        drv = new(inf, gen2drv);
        mon = new(inf, mon2scb);
        scb = new(mon2scb, gen2scb);

        // Reset
        inf.reset = 1;
        #50 inf.reset = 0;

        $display("[%0t][TOP] Starting UART Test...", $time);

        fork
          	gen.run('{8'h76, 8'h00, 8'hFF}, 2); 
            drv.run();
            mon.run();
          	scb.run(5);
        join_none

        @(scb.done);
        $display("Simulation Finished Successfully at %0t", $time);
        $finish;
    end
endmodule