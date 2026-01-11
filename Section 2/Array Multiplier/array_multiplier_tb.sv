`timescale 1ns/1ps

interface array_mul_if #(parameter N = 8);
    logic clk;
    logic ena, enb;
    logic [N-1:0] a, b;
    logic [2*N-1:0] p;
endinterface

class array_mul_txn;
    bit ena, enb;
    bit [7:0] a, b;
endclass

class generator;
    mailbox gen2drv;

    function new(mailbox gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task run();
        array_mul_txn t;

        t = new(); t.ena=1; t.enb=1; t.a=8'd3;   t.b=8'd5;   gen2drv.put(t);
        t = new(); t.ena=1; t.enb=1; t.a=8'd12;  t.b=8'd10;  gen2drv.put(t);
		  t = new(); t.ena=1; t.enb=1; t.a=8'd255;  t.b=8'd255;  gen2drv.put(t);

		  
		  t = new(); t.ena=1; t.enb=0; t.a=8'd7;   t.b='x;     gen2drv.put(t);
        t = new(); t.ena=0; t.enb=1; t.a='x;     t.b=8'd9;   gen2drv.put(t);
		  
		  t = new(); t.ena=0; t.enb=0; t.a='x;   t.b='x;   gen2drv.put(t);

        t = new(); t.ena=1; t.enb=1; t.a=8'd0;   t.b=8'd25;  gen2drv.put(t);
        t = new(); t.ena=1; t.enb=1; t.a=8'd15;  t.b=8'd0;   gen2drv.put(t);
        t = new(); t.ena=1; t.enb=1; t.a=8'd0;   t.b=8'd0;   gen2drv.put(t);
    endtask
endclass


class driver #(parameter N=8);
    virtual array_mul_if #(N) vif;
    mailbox gen2drv;

    function new(virtual array_mul_if #(N) vif, mailbox gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction

    task run();
        array_mul_txn t;
        forever begin
            gen2drv.get(t);
            @(posedge vif.clk);
            vif.ena <= t.ena;
            vif.enb <= t.enb;
            vif.a   <= t.a;
            vif.b   <= t.b;
        end
    endtask
endclass

class monitor #(parameter N=8);
    virtual array_mul_if #(N) vif;
    mailbox mon2scb;

    function new(virtual array_mul_if #(N) vif, mailbox mon2scb);
        this.vif = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        logic [2*N-1:0] observed;
        forever begin
            @(posedge vif.clk);
            observed = vif.p;
            mon2scb.put(observed);
        end
    endtask
endclass

class scoreboard #(parameter N = 8);
    mailbox mon2scb;

    logic [N-1:0] a_d1, b_d1;
    logic [N-1:0] a_d2, b_d2;
    bit valid_d1, valid_d2;

    logic [2*N-1:0] expected;

    function new(mailbox mon2scb);
        this.mon2scb = mon2scb;
        a_d1 = '0; b_d1 = '0;
        a_d2 = '0; b_d2 = '0;
        valid_d1 = 0; valid_d2 = 0;
        expected = '0;
    endfunction

    task run(virtual array_mul_if #(N) vif);
        logic [2*N-1:0] actual;

        forever begin
            mon2scb.get(actual);

            if (valid_d2) begin
                expected = a_d2 * b_d2;

                if (actual !== expected)
                    $display("[%0t] FAIL: expected=%0d actual=%0d",
                             $time, expected, actual);
                else
                    $display("[%0t] PASS: p=%0d", $time, actual);
            end
            else begin
                $display("[%0t] INFO: output ignored (pipeline filling)", $time);
            end

            a_d2 = a_d1;
            b_d2 = b_d1;
            valid_d2 = valid_d1;

            if (vif.ena) begin
                a_d1 = vif.a;
                valid_d1 = 1;
            end

            if (vif.enb) begin
                b_d1 = vif.b;
                valid_d1 = 1;
            end
        end
    endtask
endclass

class environment #(parameter N=8);
    generator           gen;
    driver #(N)         drv;
    monitor #(N)        mon;
    scoreboard #(N)     scb;

    mailbox gen2drv;
    mailbox mon2scb;
    virtual array_mul_if #(N) vif;

    function new(virtual array_mul_if #(N) vif);
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

module array_multiplier_tb;
    parameter N = 8;

    array_mul_if #(N) vif();
    reg clk = 0;

    array_multiplier dut (
        .clk(clk),
        .ena(vif.ena),
        .enb(vif.enb),
        .a(vif.a),
        .b(vif.b),
        .p(vif.p)
    );

    always #5 clk = ~clk;
    assign vif.clk = clk;

    environment #(N) env;

    initial begin
        env = new(vif);
        env.run();
        #200 $finish;
    end
endmodule
