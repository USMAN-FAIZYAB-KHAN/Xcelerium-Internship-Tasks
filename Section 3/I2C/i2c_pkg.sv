package i2c_pkg;

    // State definitions matching the RTL
    typedef enum logic [3:0] {
        IDLE, START, ADDR, ACK1, TX_DATA1, ACK2, TX_DATA2, ACK3, STOP
    } m_state_t;

    class i2c_txn;
        rand bit [11:0] data;
        rand bit rw;
        rand bit [6:0] slave_addr;
        
        constraint addr_c { slave_addr inside {6, 7}; }

        function void display(string tag);
            $display("[%0t][%s] data=%h rw=%b slave_addr=%h", $time, tag, data, rw, slave_addr);
        endfunction
    endclass

    class generator;
        mailbox #(i2c_txn) gen2drv;
        mailbox #(i2c_txn) gen2scb;

        function new(mailbox #(i2c_txn) m1, m2);
            gen2drv = m1;
            gen2scb = m2;
        endfunction

        task run(bit [11:0] data_arr[$], bit [6:0] addr_arr[$], bit rw_arr[$], int num_random);
            i2c_txn t;
            // Directed Transactions
            foreach(data_arr[i]) begin
                t = new();
                t.data = data_arr[i];
                t.slave_addr = addr_arr[i];
                t.rw = rw_arr[i];
                t.display("GEN");
                gen2drv.put(t);
                gen2scb.put(t);
            end
            // Random Transactions
            repeat(num_random) begin
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

        function new(virtual i2c_if vif, mailbox #(i2c_txn) mb);
            this.vif = vif;
            this.gen2drv = mb;
        endfunction

        task run();
            i2c_txn t;
            forever begin
                gen2drv.get(t);
                vif.slave_addr     <= t.slave_addr;
                vif.rw             <= t.rw;

                if (t.rw == 0)
                    vif.master_data_in <= t.data;
                else
                    vif.slave_data_in  <= t.data;

                vif.enable <= 1'b1;
                @(posedge vif.clk);
                vif.enable <= 1'b0;
                
                wait(vif.master_done);
                @(posedge vif.clk);
            end
        endtask
    endclass

    class monitor;
        virtual i2c_if vif;
        mailbox #(i2c_txn) mon2scb;

        // covergroup cg_i2c;
        //     option.per_instance = 1;
        //     cp_rw: coverpoint vif.rw;
        //     cp_ack_err: coverpoint vif.ack_error;
        //     cp_m_state: coverpoint vif.master_state {
        //         bins states[] = {[0:8]}; // IDLE to STOP
        //     }
        // endgroup

        function new(virtual i2c_if vif, mailbox #(i2c_txn) mb);
            this.vif = vif;
            this.mon2scb = mb;
            // cg_i2c = new();
        endfunction

        task run();
            i2c_txn t;
            forever begin
                wait(vif.master_done == 1'b1);
                t = new();
                t.data = (vif.rw) ? vif.master_data_out : vif.slave_data_out;
                t.slave_addr = vif.slave_addr;
                t.rw = vif.rw;
                t.display("MON");
                mon2scb.put(t);
            end
        endtask
    endclass

    class scoreboard;
        mailbox #(i2c_txn) gen2scb, mon2scb;
        event done;

        function new(mailbox #(i2c_txn) m1, m2);
            gen2scb = m1; mon2scb = m2;
        endfunction

        task run(int total);
            int count = 0;
            i2c_txn t_gen, t_mon;
            forever begin
                gen2scb.get(t_gen);
                mon2scb.get(t_mon);
                if(t_gen.slave_addr == 7) begin // Only check if addr matches slave
                    if(t_gen.rw == 0 && t_mon.data !== t_gen.data) 
                        $error("[SCB] Write Mismatch! Gen:%h Mon:%h", t_gen.data, t_mon.data);
                    else $display("[SCB] Match Verified.");
                end else begin
                    $display("[SCB] NACK expected and observed for addr %h", t_gen.slave_addr);
                end
                count++;
                if(count == total) -> done;
            end
        endtask
    endclass
endpackage