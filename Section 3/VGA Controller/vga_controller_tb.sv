`timescale 1ns/1ps
import vga_pkg::*;

// interface to connect DUT and testbench components
interface vga_if(input logic clk_25mhz);
	logic rst;
    logic en;
    logic hsync;
    logic vsync;
  	logic [18:0] sram_addr;
    logic video_on;
    logic [1:0] h_state;
    logic [1:0] v_state;
endinterface

module vga_controller_tb;
  
	logic clk_25mhz = 0;
  	always #20 clk_25mhz = ~clk_25mhz;
  
  	vga_if vif(clk_25mhz);

    assign vif.h_state = dut.h_state_reg;
    assign vif.v_state = dut.v_state_reg;
  
  	int total_txn = 700;
  
    vga_controller dut (
      .clk_25mhz(clk_25mhz),
      .rst(vif.rst),
      .en(vif.en), 
      .hsync(vif.hsync),
      .vsync(vif.vsync),
      .sram_addr(vif.sram_addr),
      .video_on(vif.video_on)
    );
  
    // mailboxes for communication between components
    mailbox #(vga_txn) gen2drv;
  	mailbox #(vga_txn) mon2scb;

    // testbench components
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard sb;
  
  	initial begin
        // instantiate mailboxes
        gen2drv = new();
        mon2scb = new();

        gen = new(gen2drv);
        drv = new(vif, gen2drv);
        mon = new(vif, mon2scb);
        sb  = new(mon2scb);

         // reset DUT
        vif.rst <= 1;
      	repeat (5) @(posedge clk_25mhz);
        vif.rst <= 0;
      	repeat (1) @(posedge clk_25mhz);
      	
        // start testbench components
        fork
          gen.run(total_txn);
          drv.run();
          mon.run();
          sb.run(total_txn);
        join_none
      
        // wait for scoreboard to finish checking
        @(sb.done);
        $display("Simulation Finished Successfully at %0t", $time);
        $finish;
	end
  
endmodule