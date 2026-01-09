import seq_detector_pkg::*;
`timescale 1ns/1ps

// Interrface to connect DUT and testbench components
interface seq_detector_if(input logic clk);
    logic rst_n;
    logic in_bit;
    logic seq_detected;
  	logic [2:0] current_state;
endinterface

module seq_detector_tb;

    logic clk = 0;
    always #5 clk = ~clk; // 10ns clock period (100MHz)

    seq_detector_if vif(clk);

    seq_detector dut (
        .clk(clk),
        .rst_n(vif.rst_n),
        .in_bit(vif.in_bit), 
        .seq_detected(vif.seq_detected)
    );
  
    // Connect current_state for coverage
    assign vif.current_state = dut.current_state;

    // Mailboxes for communication between components
    mailbox #(seq_detector_txn) gen2drv;
    mailbox #(seq_detector_txn) mon2sb;

    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard sb;
    
    // Directed sequence to test sequence detection
    bit directed_seq[$] = '{1,0,1,1,0,1,1}; 
    int num_random = 45;
    int total_transactions = directed_seq.size() + num_random;

    initial begin
        gen2drv = new();
        mon2sb = new();
        
        gen = new(gen2drv);
        drv = new(vif, gen2drv);
        mon = new(vif, mon2sb);
        sb  = new(mon2sb, total_transactions);

        // Reset DUT
        vif.rst_n <= 0;
        vif.in_bit <= 0;
        repeat (5) @(posedge clk);
        vif.rst_n <= 1;
        repeat (1) @(posedge clk);

        // Start testbench components
        fork
            gen.run(directed_seq, num_random);
            drv.run();
            mon.run();
            sb.run();
        join_none

        // Wait for scoreboard to finish
        @(sb.done);
        $display("Simulation Finished Successfully at %0t", $time);
        $finish;
  end
endmodule