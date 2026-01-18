`timescale 1ns/1ps
import i2c_pkg::*;

interface i2c_if(input logic clk);
    logic rst_n;
    logic [11:0] master_data_in;
    logic [11:0] master_data_out;
    logic [11:0] slave_data_in;
    logic [11:0] slave_data_out;
    logic master_done;
  	logic master_busy;
    logic slave_done;
    logic rw;
    logic [6:0] slave_addr;
    logic enable;
    logic tick_4x;

    logic [3:0] master_state;
    logic [3:0] slave_state;

    tri1 sda;
    tri1 scl;
endinterface

module i2c_tb;

    bit clk;
    always #5 clk = ~clk;

    i2c_if inf(clk);

    i2c_tick_gen TICK_GEN (
        .clk(clk),
        .rst_n(inf.rst_n),
        .tick_4x(inf.tick_4x)
    );

    i2c_master DUT_MASTER (
        .clk(clk),
        .rst_n(inf.rst_n),
        .sda(inf.sda),
        .scl(inf.scl),
        .data_in(inf.master_data_in),
        .data_out(inf.master_data_out),
        .rw(inf.rw),
        .slave_addr(inf.slave_addr),
        .enable(inf.enable),
        .tick_4x(inf.tick_4x),
      	.done(inf.master_done),
      .busy(inf.master_busy)
    );

    i2c_slave DUT_SLAVE (
        .clk(clk),
        .rst_n(inf.rst_n),
        .sda(inf.sda),
        .scl(inf.scl),
        .data_in(inf.slave_data_in),
        .data_out(inf.slave_data_out),
        .done(inf.slave_done)
    );

    mailbox #(i2c_txn) gen2drv;
    mailbox #(i2c_txn) gen2scb;
  	mailbox #(i2c_txn) mon2scb;
  
  	generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;
  
  	assign inf.master_state = DUT_MASTER.current_state;
  	assign inf.slave_state = DUT_SLAVE.state;

    initial begin
      $dumpfile("i2c_sim.vcd");
      $dumpvars(0, DUT_MASTER);
      $dumpvars(0, DUT_SLAVE);
      
        gen2drv = new();
        gen2scb = new();
        mon2scb = new();

        gen = new(gen2drv, gen2scb);
        drv = new(inf, gen2drv);
        mon = new(inf, mon2scb);
        scb = new(gen2scb, mon2scb);

        // Reset
        inf.rst_n = 0;
        #50 inf.rst_n = 1;

        fork
          gen.run('{12'hFFF, 12'hCCC, 12'h0}, '{7'd76, 7'd76, 7'd76}, '{1'b0, 1'b1, 1'b0}, 4);
          drv.run();
          mon.run();
          scb.run(7);
        join_none

        @(scb.done);
        $display("Simulation Finished Successfully at %0t", $time);
        $finish;
    end

endmodule