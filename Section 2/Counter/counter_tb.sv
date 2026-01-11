`timescale 1ns/1ps

interface counter_if #(parameter N = 8);
    logic clk;
    logic rst_n;
    logic en;
    logic up_dn;
    logic [N-1:0] count;
endinterface

class counter_txn;
    bit en;
    bit up_dn;
    bit rst_n;
endclass

class generator;
    mailbox gen2drv;

    function new(mailbox gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task run();
        counter_txn t;

        // Initial reset
        t = new(); t.rst_n = 0; t.en = 0; t.up_dn = 0; gen2drv.put(t);

        // Count UP
        repeat (4) begin
            t = new(); t.rst_n = 1; t.en = 1; t.up_dn = 1;
            gen2drv.put(t);
        end
		  
		  // Disable
        repeat (2) begin
            t = new(); t.rst_n = 1; t.en = 0; t.up_dn = 1;
            gen2drv.put(t);
        end

        // Count DOWN
        repeat (6) begin
            t = new(); t.rst_n = 1; t.en = 1; t.up_dn = 0;
            gen2drv.put(t);
        end
		  
		  t = new(); t.rst_n = 0; t.en = 0; t.up_dn = 0; gen2drv.put(t);
    endtask
endclass

class driver #(parameter N = 8);
    virtual counter_if #(N) vif;
    mailbox gen2drv;

    function new(virtual counter_if #(N) vif, mailbox gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction

    task run();
        counter_txn t;
        forever begin
            gen2drv.get(t);
            @(posedge vif.clk);
            vif.rst_n <= t.rst_n;
            vif.en    <= t.en;
            vif.up_dn <= t.up_dn;
        end
    endtask
endclass

class monitor #(parameter N = 8);
    virtual counter_if #(N) vif;
    mailbox mon2scb;

    function new(virtual counter_if #(N) vif, mailbox mon2scb);
        this.vif = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
	 	  @(negedge vif.rst_n);
		  @(posedge vif.rst_n);
        forever begin
            @(posedge vif.clk);
            mon2scb.put(vif.count);
        end
    endtask
endclass

class scoreboard #(parameter N = 8);
    mailbox mon2scb;
    logic [N-1:0] expected;

    function new(mailbox mon2scb);
        this.mon2scb = mon2scb;
        expected = '0;
    endfunction

    task run(virtual counter_if #(N) vif);
        logic [N-1:0] actual;

        forever begin
            mon2scb.get(actual);

            if (!vif.rst_n) begin
                if (actual !== 0)
                    $display("[%0t] FAIL (RESET): count should be 0 but is %0d", $time, actual);
                else
                    $display("[%0t] PASS (RESET): count correctly 0", $time);
                expected = 0;
            end else begin
                if (actual !== expected)
                    $display("[%0t] FAIL: expected=%0d actual=%0d", $time, expected, actual);
                else
                    $display("[%0t] PASS: count=%0d", $time, actual);

                if (vif.en) begin
                    if (vif.up_dn)
                        expected++;
                    else
                        expected--;
                end
            end
        end
    endtask
endclass

class environment #(parameter N = 8);
    generator           gen;
    driver #(N)         drv;
    monitor #(N)        mon;
    scoreboard #(N)     scb;

    mailbox gen2drv;
    mailbox mon2scb;

    virtual counter_if #(N) vif;

    function new(virtual counter_if #(N) vif);
        this.vif = vif;

        gen2drv = new();
        mon2scb = new();

        gen = new(gen2drv);
        drv = new(vif, gen2drv);
        mon = new(vif, mon2scb);
        scb = new(mon2scb);
    endfunction

    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run(vif);
        join_none
    endtask
endclass


module counter_tb;
    parameter N = 8;

    counter_if #(N) vif();

    counter #(N) dut (
        .clk   (vif.clk),
        .rst_n (vif.rst_n),
        .en    (vif.en),
        .up_dn (vif.up_dn),
        .count (vif.count)
    );

    environment #(N) env;

    initial begin
        vif.clk = 0;
        forever #5 vif.clk = ~vif.clk;
    end

    initial begin
        env = new(vif);
        env.run();
        #300 $finish;
    end
endmodule
