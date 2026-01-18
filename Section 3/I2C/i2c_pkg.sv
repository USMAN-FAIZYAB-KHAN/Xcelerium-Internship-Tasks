package i2c_pkg;

    typedef enum logic [3:0] {
        IDLE, START, ADDR, ACK_1,
        DATA_1, ACK_2,
        DATA_2, ACK_3,
        STOP
    } state_t;

    class i2c_txn;
        rand bit [11:0] data;
        rand bit rw;
        rand bit [6:0] slave_addr;
        
      constraint addr_c { slave_addr inside {7'd50}; }

        function void display(string tag);
          $display("[%0t][%s] data=%h rw=%b slave_addr=%d", $time, tag, data, rw, slave_addr);
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
              	t.display("DRI");
                vif.slave_addr     <= t.slave_addr;
                vif.rw             <= t.rw;
              	
              	if (t.rw == 0)
                	vif.master_data_in <= t.data;
              	else
                  	vif.slave_data_in <= t.data;
              
                vif.enable         <= 1'b1;
              
             	wait(vif.master_done == 1);
              	wait(vif.master_done == 0);
              	vif.enable         <= 1'b0;
              	
              	@(posedge vif.clk);
            end
        endtask
    endclass

    class monitor;
        virtual i2c_if vif;
        mailbox #(i2c_txn) mon2scb;

      covergroup cg_i2c @(posedge vif.clk);
            option.per_instance = 1;

            cp_rw: coverpoint vif.rw {
                bins read  = {1'b1};
                bins write = {1'b0};
            }

            cp_master_state: coverpoint vif.master_state {
                bins m_states[] = {IDLE, START, ADDR, ACK_1, DATA_1, ACK_2, DATA_2, ACK_3, STOP};
            }

            cp_slave_state: coverpoint vif.slave_state {
                bins s_states[] = {IDLE, START, ADDR, ACK_1, DATA_1, ACK_2, DATA_2, ACK_3, STOP};
            }

            cp_slave_addr: coverpoint vif.slave_addr {
                bins valid_slave = {7'd76};
                bins other_addr  = {[0:127]} with (item != 7'd76);
            }

            cp_master_data: coverpoint vif.master_data_in {
                bins min_val = {12'h000};
                bins max_val = {12'hFFF};
                bins others  = {[1:4094]};
            }

            cp_master_trans: coverpoint vif.master_state {
                bins idle_to_start    = (IDLE  => START);
                bins start_to_addr    = (START => ADDR);
                bins addr_to_ack1     = (ADDR  => ACK_1);
                bins ack1_to_data1    = (ACK_1 => DATA_1);
                bins ack1_to_stop     = (ACK_1 => STOP);
                bins data1_to_ack2    = (DATA_1 => ACK_2);
                bins ack2_to_data2    = (ACK_2 => DATA_2);
                bins data2_to_ack3    = (DATA_2 => ACK_3);
                bins ack3_to_stop     = (ACK_3 => STOP);
                bins stop_to_idle     = (STOP  => IDLE);
            }

            cp_slave_trans: coverpoint vif.slave_state {
                bins idle_to_start    = (IDLE  => START);
                bins start_to_addr    = (START => ADDR);
                bins addr_to_ack1     = (ADDR  => ACK_1);
                bins addr_to_idle     = (ADDR  => IDLE);
                bins ack1_to_data1    = (ACK_1 => DATA_1);
                bins data1_to_ack2    = (DATA_1 => ACK_2);
                bins ack2_to_data2    = (ACK_2 => DATA_2);
                bins data2_to_ack3    = (DATA_2 => ACK_3);
                bins ack3_to_stop     = (ACK_3 => STOP);
            }
        endgroup

        function new(virtual i2c_if vif, mailbox #(i2c_txn) mb);
            this.vif = vif;
            this.mon2scb = mb;
            cg_i2c = new();
        endfunction

        task run();
            i2c_txn t;
            forever begin
              @(posedge vif.master_done);
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
        
        int target_addr = 76; 

        function new(mailbox #(i2c_txn) m1, m2);
            gen2scb = m1; 
            mon2scb = m2;
        endfunction

        task run(int total);
            int count = 0;
            i2c_txn t_gen, t_mon;
            
            forever begin
                gen2scb.get(t_gen);
                mon2scb.get(t_mon);
                
              if (t_gen.slave_addr == target_addr) begin
                    
                    if (t_gen.rw == 0) begin 
                        if (t_mon.data === t_gen.data)
                            $display("[SCB] WRITE MATCH: Addr %0d | Data: %h", target_addr, t_mon.data);
                        else
                            $error("[SCB] WRITE MISMATCH: Addr %0d | Exp: %h, Got: %h", target_addr, t_gen.data, t_mon.data);
                    end else begin 
                        if (t_mon.data === t_gen.data)
                            $display("[SCB] READ MATCH: Addr %0d | Data: %h", target_addr, t_mon.data);
                        else
                            $error("[SCB] READ MISMATCH: Addr %0d | Exp: %h, Got: %h", target_addr, t_gen.data, t_mon.data);
                    end
                end else begin
                    $display("[SCB] ADDR MISMATCH: Slave %0d ignored txn to %0d.", target_addr, t_gen.slave_addr);
                end

                count++;
                if(count == total) -> done;
            end
        endtask
    endclass
endpackage

