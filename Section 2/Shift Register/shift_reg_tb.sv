interface shift_if #(parameter N = 8);
    logic clk;
    logic rst_n;
    logic shift_en;
    logic dir;
    logic d_in;
    logic [N-1:0] q_out;
endinterface

class shift_txn;
    bit shift_en;
    bit dir;
    bit d_in;
    bit rst_n;
endclass

class generator;
    mailbox gen2drv;

    function new(mailbox gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task run();
        shift_txn t;

        // Initial reset
        t = new(); t.rst_n = 0; t.shift_en = 0; t.dir = 0; t.d_in = 0; gen2drv.put(t);

        // Shift left 4 times
        repeat (4) begin
            t = new(); t.rst_n = 1; t.shift_en = 1; t.dir = 0; t.d_in = 1;
            gen2drv.put(t);
        end
		  
		  // Disable shifting
        repeat (2) begin
            t = new(); t.rst_n = 1; t.shift_en = 0; t.dir = 0; t.d_in = 0;
            gen2drv.put(t);
        end

        // Shift right 4 times
        repeat (4) begin
            t = new(); t.rst_n = 1; t.shift_en = 1; t.dir = 1; t.d_in = 0;
            gen2drv.put(t);
        end
    endtask
endclass

class driver #(parameter N = 8);
    virtual shift_if #(N) vif;
    mailbox gen2drv;

    function new(virtual shift_if #(N) vif, mailbox gen2drv);
        this.vif = vif;
        this.gen2drv = gen2drv;
    endfunction

    task run();
        shift_txn t;
        forever begin
            gen2drv.get(t);
            @(posedge vif.clk);
            vif.rst_n    <= t.rst_n;
            vif.shift_en <= t.shift_en;
            vif.dir      <= t.dir;
            vif.d_in     <= t.d_in;
        end
    endtask
endclass

class monitor #(parameter N = 8);
    virtual shift_if #(N) vif;
    mailbox mon2scb;

    function new(virtual shift_if #(N) vif, mailbox mon2scb);
        this.vif = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        forever begin
            @(posedge vif.clk);
            mon2scb.put(vif.q_out);
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

    task run(virtual shift_if #(N) vif);
        logic [N-1:0] actual;

        forever begin
            mon2scb.get(actual);

            if (!vif.rst_n) begin
                expected = '0;
                if (actual !== expected)
                    $display("[%0t] FAIL (RESET): q_out=%b", $time, actual);
                else
                    $display("[%0t] PASS (RESET): q_out=%b", $time, actual);
            end else begin
                if (vif.shift_en) begin
                    if (vif.dir == 0)        
                        expected = {expected[N-2:0], vif.d_in};
                    else                 
                        expected = {vif.d_in, expected[N-1:1]};
                end

                if (actual !== expected)
                    $display("[%0t] FAIL: expected=%b actual=%b", $time, expected, actual);
                else
                    $display("[%0t] PASS: q_out=%b", $time, actual);
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

    virtual shift_if #(N) vif;

    function new(virtual shift_if #(N) vif);
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

module shift_reg_tb;
    parameter N = 8;

    shift_if #(N) vif();

    shift_reg #(N) dut (
        .clk       (vif.clk),
        .rst_n     (vif.rst_n),
        .shift_en  (vif.shift_en),
        .dir       (vif.dir),
        .d_in      (vif.d_in),
        .q_out     (vif.q_out)
    );

    environment #(N) env;

    initial begin
        vif.clk = 0;
        forever #5 vif.clk = ~vif.clk;
    end

    initial begin
        env = new(vif);
        env.run();
        #200 $finish;
    end
endmodule