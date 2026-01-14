package i2c_pkg;

typedef enum logic [3:0] {
   IDLE, START, ADDR, ACK_1, DATA_1, ACK_2, DATA_2, ACK_3, STOP
} state_t;

class i2x_txn;
    rand bit [11:0] data;
    rand bit rw;
    rand bit [6:0] slave_addr;
    constraint addr_c { slave_addr inside {6, 7}; }

    function void display(string tag);
        $$display("[%0t][%s] data=%h(%b) rw=%b slave_addr=%h(%b)"
                  , $time, tag, data, rw, slave_addr);
    endfunction
endclass

class generator;
    mailbox #(i2c_txn) gen2drv;
    mailbox #(i2c_txn) gen2scb;
    function new(mailbox #(i2c_txn) m1, mailbox #(i2c_txn) m2);
        gen2drv = m1;
        gen2scb = m2;
    endfunction

    task run(
        bit [11:0] data_array[$],
        bit [6:0] addr_arr[$],
        bit rw_arr[$],
        int num_random_txns
    );
        i2c_txn t;

        foreach(data_array[i]) begin
            i2c_txn t = new();
            t.data = data_array[i];
            t.rw = rw_arr[i];
            t.slave_addr = addr_arr[i];
            t.display("GEN");
            gen2drv.put(t);
            gen2scb.put(t);
        end

        repeat (num_random_txns) begin
            t = new();
            t.randomize();
            t.display("GEN");
            gen2drv.put(t);
            gen2scb.put(t);
        end
    endtask
endclass

class driver;
    virtual i2c_if vif;
    mailbox #(i2c_txn) gen2drv;

    function new(virtual i2c_vif vif, mailbox #(i2c_txn) mb);
        this.vif = vif;
        gen2drv = mb;
    endfunction

    task run();
        i2c_txn t;
        forever begin
            gen2drv.get(t);
            // drive transaction to DUT
            vif.din = t.data;
            vif.rw = t.rw;
            vif.slave_addr = t.slave_addr;
            vif.enable = 1'b1;
            @(posedge vif.clk);
            vif.enable = 1'b0;

            // wait for done signal
            wait (vif.done == 1'b1);
            @(posedge vif.clk);
        end
    endtask
endclass

class monitor;
    virtual i2c_if vif;
    mailbox #(i2c_txn) mon2scb;

    covergroup cg_i2c @(posedge vif.clk);
        option.per_instance = 1;

        cp_data: coverpoint vif.data_in {
            bins zeroes = {0};
            bins ones   = {12'hFFF};
            bins others = default;
        }
        cp_rw: coverpoint vif.rw {
            bins read  = {1'b1};
            bins write = {1'b0};
        }
        cp_done: coverpoint vif.done {
            bins done = {1'b1};
        }
        cp_master_state: coverpoint vif.master_state {
            bins states[] = {IDLE, START, ADDR, ACK_1, DATA_1, ACK_2, DATA_2, ACK_3, STOP};
        }
        cp_master_transition: coverpoint vif.master_state {
            bins complete_flow = (IDLE => START => ADDR => ACK_1 => DATA_1 => ACK_2 => DATA_2 => ACK_3 => STOP);
            bins nack_at_addr = (ADDR => ACK_1 => STOP);
            bins nack_at_data1 = (DATA_1 => ACK_2 => STOP);
            bins nack_at_data2 = (DATA_2 => ACK_3 => STOP);
        }
        cp_slave_state: coverpoint vif.slave_state {
            bins states[] = {IDLE, ADDR, ACK_1, DATA_1, ACK_2, DATA_2, ACK_3, STOP};
        }
        cp_slave_transition: coverpoint vif.slave_state {
            bins complete_flow = (IDLE => ADDR => ACK_1 => DATA_1 => ACK_2 => DATA_2 => ACK_3 => STOP);
            bins addr_mismatch = (ADDR => STOP);
        }

    endgroup

    function new(virtual i2c_if vif, mailbox #(i2c_txn) mb);
        this.vif = vif;
        mon2scb = mb;
        cg_i2c = new();
    endfunction

    task run();
        i2c_txn t;
        forever begin
            wait (vif.done == 1'b1);
            @(posedge vif.clk);
            t = new();
            t.data = vif.din;
            t.rw = vif.rw;
            t.slave_addr = vif.slave_addr;
            t.display("MON");
            mon2scb.put(t);
        end
    endtask
endclass
    
class scoreboard;
    mailbox #(i2c_txn) gen2scb;
    mailbox #(i2c_txn) mon2scb;
    event done;

    function new(mailbox #(i2c_txn) m1, mailbox #(i2c_txn) m2);
        gen2scb = m1;
        mon2scb = m2;
    endfunction

    task run(int total_txns);
        i2c_txn t_gen, t_mon;
        int count = 0;

        forever begin
            mon2scb.get(t_mon);
            gen2scb.get(t_gen);

            if ((t_gen.data !== t_mon.data) ||
                (t_gen.rw !== t_mon.rw) ||
                (t_gen.slave_addr !== t_mon.slave_addr)) begin
                $display("[%0t][SCB] Mismatch Detected!", $time);
                $display("Generated: data=%h rw=%b slave_addr=%h", t_gen.data, t_gen.rw, t_gen.slave_addr);
                $display("Monitored: data=%h rw=%b slave_addr=%h", t_mon.data, t_mon.rw, t_mon.slave_addr);
                $fatal;
            end else begin
                $display("[%0t][SCB] Match Verified.", $time);
            end

            count++;
            if (count == total_txns) begin
                $display("[%0t][SCB] All transactions completed.", $time);
                -> done; 
            end
        end
    endtask
endclass

endpackage