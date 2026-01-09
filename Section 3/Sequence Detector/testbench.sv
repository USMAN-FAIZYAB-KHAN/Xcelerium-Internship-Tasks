import seq_detector_pkg::*;
`timescale 1ns/1ps

interface seq_detector_if(input logic clk);
  
    logic rst_n;
    logic in_bit;
    logic seq_detected;
  	logic [2:0] current_state;
  
endinterface

module seq_detector_tb;

  logic clk = 0;
  always #5 clk = ~clk;

  seq_detector_if vif(clk);

  seq_detector dut (
    .clk(clk),
    .rst_n(vif.rst_n),
    .in_bit(vif.in_bit), 
    .seq_detected(vif.seq_detected)
  );
  
  assign vif.current_state = dut.current_state;

  mailbox #(seq_detector_txn) gen2drv;
  mailbox #(seq_detector_txn) mon2sb;

  generator  gen;
  driver     drv;
  monitor    mon;
  scoreboard sb;

  initial begin
    gen2drv = new();
    mon2sb = new();
    
    gen = new(gen2drv);
    drv = new(vif, gen2drv);
    mon = new(vif, mon2sb);
    sb  = new(mon2sb);

    vif.rst_n <= 0;
    vif.in_bit <= 0;
    repeat (5) @(posedge clk);
    vif.rst_n <= 1;
    repeat (1) @(posedge clk);

    fork
      gen.run(4);
      drv.run();
      mon.run();
      sb.run();
    join_none


    wait(gen2drv.num() == 0); 
    #100;
    $display("Simulation Finished Successfully at %0t", $time);
    $finish;
  end

endmodule