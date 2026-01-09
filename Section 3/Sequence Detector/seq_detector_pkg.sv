package seq_detector_pkg;

// State encoding
typedef enum logic [2:0] {S0, S1, S2, S3, S4} state_t;

class seq_detector_txn;
    bit in_bit;
    bit seq_detected;

    function new(bit val1 = 1'b0, bit val2 = 1'b0);
        in_bit       = val1;
        seq_detected = val2;
    endfunction

    // Generate random input bit
    function void gen_random();
        in_bit = $urandom_range(0, 1);
    endfunction

    // Display transaction details
    function void display(string tag, bit show_seq = 0);
        if (show_seq)
            $display("[%0t][%s] in_bit=%b seq_detected=%b",
                        $time, tag, in_bit, seq_detected);
        else
            $display("[%0t][%s] in_bit=%b",
                        $time, tag, in_bit);
    endfunction
endclass

class generator;
    // Mailbox to send transactions to driver
    mailbox #(seq_detector_txn) gen2drv;

    function new(mailbox #(seq_detector_txn) mb);
        gen2drv = mb;
    endfunction

    task run(bit directed_seq[$], int num_random_txns);
        seq_detector_txn t;
 
        // put directed sequence transactions into mailbox
        foreach(directed_seq[i]) begin
            t = new(directed_seq[i]);
            t.display("GEN");
            gen2drv.put(t);
        end

        // put random transactions into mailbox
        repeat(num_random_txns) begin
            t = new();
            t.gen_random();
            t.display("GEN");
            gen2drv.put(t);
        end
    endtask
endclass

class driver;
    virtual seq_detector_if vif;
    // Mailbox to receive transactions from generator
    mailbox #(seq_detector_txn) gen2drv;

    function new(virtual seq_detector_if vif, mailbox #(seq_detector_txn) mb);
        this.vif = vif;
        this.gen2drv = mb;
    endfunction

    task run();
        seq_detector_txn t;
        // Drive input bits to DUT before clock edge
        forever begin
            gen2drv.get(t);
            vif.in_bit <= t.in_bit;
            t.display("DRV");
            @(posedge vif.clk);
        end
    endtask
endclass

class monitor;
    virtual seq_detector_if vif;
    // Mailbox to send transactions to scoreboard
    mailbox #(seq_detector_txn) mon2scb;
    
    // Coverage group for functional coverage
    covergroup cg_seq_detector;
      	option.per_instance = 1;
      
        cp_in_bit: coverpoint vif.in_bit {
            bins zero = {0};
            bins one  = {1};
        }
        cp_state: coverpoint vif.current_state {
            bins states[] = {S0, S1, S2, S3, S4};
        }
        cp_transition: coverpoint vif.current_state {
            bins t_s0_s1 = (S0 => S1);
            bins t_s1_s2 = (S1 => S2);
            bins t_s2_s3 = (S2 => S3);
            bins t_s3_s4 = (S3 => S4);
            bins t_any_reset = (S1, S2, S3, S4 => S0);	
        }
        cp_in_bit_seq: coverpoint vif.in_bit {
            bins target_seq = (1 => 0 => 1 => 1);
            bins target_seq_overlap = (1 => 0 => 1 => 1 => 0 => 1 => 1);
        }
    endgroup

    function new(virtual seq_detector_if vif, mailbox #(seq_detector_txn) mb);
        this.vif = vif;
        this.mon2scb = mb;
        // Instantiate coverage group
        cg_seq_detector = new();
    endfunction

    task run();
        seq_detector_txn t;
        // Sample DUT inputs and outputs after clock edge
        forever begin
            @(posedge vif.clk);
            cg_seq_detector.sample();
            t = new(vif.in_bit, vif.seq_detected);
            t.display("MON", 1);
            mon2scb.put(t);
        end
    endtask
endclass

class scoreboard;
    // Mailbox to receive transactions from monitor
    mailbox #(seq_detector_txn) mon2scb;
    // To keep track of last 4 input bits for expected output calculation
    bit [3:0] last4;
    bit expect_seq_detected;
    int count = 0; // transaction counter
    event done; // event to signal completion
    int total_txns; // total number of transactions

    function new(mailbox #(seq_detector_txn) mb, int total);
        this.mon2scb = mb;
        this.total_txns = total;
        this.last4 = 4'b0000;
        this.expect_seq_detected = 1'b0;
    endfunction

    task run();
        seq_detector_txn t;
        forever begin
                mon2scb.get(t);
                count++; // increment transaction counter

                // Check if actual output matches expected output
                if (t.seq_detected !== expect_seq_detected)
                $error("[%0t][SC] Error! Actual:%b Expected:%b", $time, 						t.seq_detected, expect_seq_detected);
                else
                $display("[%0t][SC] Match! Actual:%b Expected:%b", $time, 					t.seq_detected, expect_seq_detected);

                // Update last4 bits and expected output
                last4 = {last4[2:0], t.in_bit}; 
                expect_seq_detected = (last4 == 4'b1011);

                t.display("SC", 1);

                if (count == total_txns) begin
          	        $display("[%0t][SC] All %0d transactions processed!", 
                            $time, total_txns);
                    -> done; 
                end
        end
        endtask
endclass

endpackage