package vga_pkg;

// VGA Timing Parameters for 640x480 @60Hz
localparam int H_ACTIVE = 640;
localparam int H_FP     = 16;
localparam int H_SYNC   = 96;
localparam int H_BP     = 48;
localparam int H_TOTAL  = H_ACTIVE + H_FP + H_SYNC + H_BP;

localparam int V_ACTIVE = 480;
localparam int V_FP     = 10;
localparam int V_SYNC   = 2;
localparam int V_BP     = 33;
localparam int V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;

// State encoding
typedef enum logic [1:0] {
    VISIBLE,
    FRONT_PORCH,
	SYNC_PULSE,
    BACK_PORCH
} state_t;

class vga_txn;
    bit en;
    bit hsync;
    bit vsync;
    bit [18:0] sram_addr;
    bit video_on;
  
  	function void display(string tag, bit show=0);
      if (show)
        $display("[%0t][%s] en:%b hs:%b vs:%b addr:%h video_on:%b", $time, tag, en, hsync, vsync, sram_addr, video_on);
      else
        $display("[%0t][%s] en:%b", $time, tag, en);     	
    endfunction	
endclass

class generator;
	// mailbox to driver
	mailbox #(vga_txn) gen2drv;

	function new(mailbox #(vga_txn) mb);
		this.gen2drv = mb;
	endfunction
	
	// generate transactions to send to driver
  	task run(int num_txns = 15);
    	vga_txn t;
      
        repeat(num_txns) begin
            t = new();
            t.en = 1'b1;
            t.display("GEN");
            gen2drv.put(t);
        end
	endtask
endclass

class driver;
	virtual vga_if vif; // use virtual interface to drive signals
	mailbox #(vga_txn) gen2drv;

	function new(virtual vga_if vif, mailbox #(vga_txn) mb);
		this.vif = vif;
		this.gen2drv = mb;
	endfunction
	
	task run();
		// drive signals to DUT before each clock edge
    	vga_txn t;
      	forever begin
          	gen2drv.get(t);
          	vif.en <= t.en;
          	t.display("DRI");
          	@(posedge vif.clk_25mhz);
        end
	endtask
endclass

class monitor;
	virtual vga_if vif;
	mailbox #(vga_txn) mon2scb;

	// coverage group to track signal transitions
    covergroup vga_cg;
        option.per_instance = 1;
        
        cp_hsync: coverpoint vif.hsync {
            bins active = {0};
            bins inactive = {1};
        }
        cp_vsync: coverpoint vif.vsync {
            bins active = {0};
            bins inactive = {1};
        }
        cp_video_on: coverpoint vif.video_on {
            bins visible = {1};
            bins blanking = {0};
        }
		cp_h_state: coverpoint vif.h_state {
			bins states[] = {VISIBLE, FRONT_PORCH, SYNC_PULSE, BACK_PORCH};
		}
		cp_v_state: coverpoint vif.v_state {
			bins states[] = {VISIBLE, FRONT_PORCH, SYNC_PULSE, BACK_PORCH};
		}
		cp_h_state_transition: coverpoint vif.h_state {
			bins VISIBLE_to_FRONT_PORCH = (VISIBLE => FRONT_PORCH);
			bins FRONT_PORCH_to_SYNC_PULSE = (FRONT_PORCH => SYNC_PULSE);
			bins SYNC_PULSE_to_BACK_PORCH = (SYNC_PULSE => BACK_PORCH);
			bins BACK_PORCH_to_VISIBLE = (BACK_PORCH => VISIBLE);
		}
		cp_v_state_transition: coverpoint vif.v_state {
			bins VISIBLE_to_FRONT_PORCH = (VISIBLE => FRONT_PORCH);
			bins FRONT_PORCH_to_SYNC_PULSE = (FRONT_PORCH => SYNC_PULSE);
			bins SYNC_PULSE_to_BACK_PORCH = (SYNC_PULSE => BACK_PORCH);
			bins BACK_PORCH_to_VISIBLE = (BACK_PORCH => VISIBLE);
		}
		cp_h_sync_vsync_cross: cross cp_hsync, cp_vsync;
    endgroup

	function new(virtual vga_if vif, mailbox #(vga_txn) mb);
		this.vif = vif;
		this.mon2scb = mb;
      	vga_cg = new();
	endfunction
	
	task run();
		// capture signals from DUT after each clock edge
    	vga_txn t;
      	forever begin
          	@(posedge vif.clk_25mhz);
          vga_cg.sample();
          	t = new();
          	t.en = vif.en;
            t.hsync = vif.hsync;
            t.vsync = vif.vsync;
          	t.sram_addr = vif.sram_addr;
            t.video_on = vif.video_on;  
          	t.display("MON", 1);
          	mon2scb.put(t);
        end
	endtask
endclass

class scoreboard;
    mailbox #(vga_txn) mon2scb;
    event done; // event to signal completion
  
	// Internal counters to track expected values
    int hcount = 0; 
    int vcount = 0;
    bit [18:0] exp_addr = 0; 
    bit exp_hsync;
    bit exp_vsync;
    bit exp_video_on;
    bit is_correct;

    function new(mailbox #(vga_txn) mb);
        this.mon2scb = mb;
    endfunction
  
    task run(int num_txns = 15);
        vga_txn t;
        int count = 0;
        
        forever begin
            mon2scb.get(t);
            
            exp_hsync = !((hcount >= (H_ACTIVE + H_FP)) && (hcount < (H_ACTIVE + H_FP + H_SYNC)));
            exp_vsync = !((vcount >= (V_ACTIVE + V_FP)) && (vcount < (V_ACTIVE + V_FP + V_SYNC)));
            exp_video_on = (hcount < H_ACTIVE) && (vcount < V_ACTIVE);

			// compare actual vs expected
            is_correct = (t.hsync === exp_hsync) && 
                         (t.vsync === exp_vsync) && 
                         (t.video_on === exp_video_on) &&
                         (t.sram_addr === exp_addr);

            $display("[%0t] [SCB] H:%0d V:%0d | Expected Addr:%h | Result: %s", 
                     $time, hcount, vcount, exp_addr, (is_correct ? "CORRECT" : "WRONG"));

			// Update expected counters and address only if enabled
			if (t.en) begin
				if (exp_video_on) begin
					exp_addr++;
				end

				if (hcount == H_TOTAL - 1) begin
					hcount = 0;
					if (vcount == V_TOTAL - 1) begin
						vcount = 0;
						exp_addr = 0; // reset address at the end of frame
					end else begin
						vcount++;
					end
				end else begin
					hcount++;
				end
			end

            count++;
            if (count == num_txns) -> done;
        end
    endtask
endclass

endpackage