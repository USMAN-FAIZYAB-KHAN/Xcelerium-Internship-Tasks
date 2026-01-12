package uart_pkg;

// State encoding
typedef enum {IDLE, START, DATA, PARITY, STOP} state_type;

class uart_txn;
    // data to be transmitted
    rand bit [7:0] data;

    function void display(string tag);
        $display("[%0t][%s] Data=%h (%b)", $time, tag, data, data);
	endfunction
endclass

class generator;
    // Mailboxes to send transactions to driver and scoreboard
    mailbox #(uart_txn) gen2drv;
    mailbox #(uart_txn) gen2scb;

    function new(mailbox #(uart_txn) m1, mailbox #(uart_txn) m2);
        gen2drv = m1;
        gen2scb = m2;
    endfunction

    // data_array: array of data bytes to transmit
    // num_random_txns: number of random transactions to generate
    task run(bit [7:0] data_array[$], int num_random_txns);
        uart_txn t;
 
        // Send directed data transactions
        foreach(data_array[i]) begin
            t = new();
            t.data = data_array[i];
            t.display("GEN");
            gen2drv.put(t);
            gen2scb.put(t);
        end
    
        // Send random data transactions
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
    virtual uart_if vif;
    mailbox #(uart_txn) gen2drv;

    function new(virtual uart_if vif, mailbox #(uart_txn) mb);
        this.vif = vif;
        gen2drv = mb;
    endfunction

    task run();
        uart_txn t;

        forever begin
            // drive data to DUT and pulse tx_en
            gen2drv.get(t);
            t.display("DRV");
            vif.din   <= t.data;
            vif.tx_en <= 1'b1;     
            @(posedge vif.clk);
            vif.tx_en <= 1'b0;

            // Wait for transmission to complete
            wait(vif.tx_done == 1'b1);       
            @(posedge vif.clk); 
        end
    endtask
endclass

class monitor;
    virtual uart_if vif;
    mailbox #(uart_txn) mon2scb;

    // Coverage group for UART signals and states
    covergroup cg_uart @(posedge vif.clk);
        option.per_instance = 1;

        cp_tx: coverpoint vif.tx {
            bins tx_low  = {0};
            bins tx_high = {1};
        }
        cp_rx: coverpoint vif.rx {
            bins rx_low  = {0};
            bins rx_high = {1};
        }
        cp_tx_done: coverpoint vif.tx_done {
            bins done = {1};
        }
        cp_rx_done: coverpoint vif.rx_done {
            bins done = {1};
        }
        cp_uart_tx_state: coverpoint vif.current_state_tx {
            bins states[] = {IDLE, START, DATA, PARITY, STOP};
        }
        cp_uart_rx_state: coverpoint vif.current_state_rx {
            bins states[] = {IDLE, START, DATA, PARITY, STOP};
        }
        cp_uart_tx_transition: coverpoint vif.current_state_tx {
            bins idle_to_start   = (IDLE   => START);
            bins start_to_data   = (START  => DATA);
            bins data_to_data    = (DATA   => DATA);
            bins data_to_parity  = (DATA   => PARITY);
            bins parity_to_stop  = (PARITY => STOP);
            bins stop_to_idle    = (STOP   => IDLE);
        }
        cp_uart_rx_transition: coverpoint vif.current_state_rx {
            bins idle_to_start   = (IDLE   => START);
            bins start_to_data   = (START  => DATA);
            bins data_to_data    = (DATA   => DATA);
            bins data_to_parity  = (DATA   => PARITY);
            bins parity_to_stop  = (PARITY => STOP);
            bins stop_to_idle    = (STOP   => IDLE);
        }
    endgroup

    function new(virtual uart_if vif, mailbox #(uart_txn) mb);
        this.vif = vif;
        mon2scb = mb;
        cg_uart = new();
    endfunction

    task run();
        uart_txn t;
        // Monitor received data on rx_done tick
        forever begin
            @(posedge vif.rx_done);
            t = new();
            t.data    = vif.dout;
            t.display("MON");
            mon2scb.put(t);
        end
    endtask
endclass

class scoreboard;
    mailbox #(uart_txn) mon2scb;
    mailbox #(uart_txn) gen2scb;
  	
    // Event to signal completion
    event done;

	function new(mailbox #(uart_txn) mb1, mailbox #(uart_txn) mb2);
        this.mon2scb = mb1;
        this.gen2scb = mb2;
    endfunction

    task run(int total_packets);
    	int count = 0;
        uart_txn t_gen;
        uart_txn t_mon;

        // Compare transactions from generator and monitor
        forever begin
            mon2scb.get(t_mon);
            gen2scb.get(t_gen);

            if (t_gen.data !== t_mon.data) begin
                $error("[%0t][SCB] Data Mismatch! Sent: %0h, Received: %0h",
                        $time, t_gen.data, t_mon.data);
            end else begin
                $display("[%0t][SCB] Data Matched! Data: %0h",
                        $time, t_gen.data);
            end
            count++;

            // Check if all packets have been processed
            if (count == total_packets) begin
              $display("[%0t][SCB] All %0d packets processed!", $time, count);
              -> done;
            end
        end
    endtask
endclass


endpackage