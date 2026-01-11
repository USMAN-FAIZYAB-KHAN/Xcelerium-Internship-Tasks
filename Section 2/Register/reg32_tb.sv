`timescale 1ns/1ps

module reg32_tb;

    reg [31:0] d;
    reg load, clk, rst_n;
    wire [31:0] q;

    initial clk = 0;
    always #5 clk = ~clk;

    reg32 uut (.q(q), .d(d), .load(load), .clk(clk), .rst_n(rst_n));

    initial begin
        // Reset Behaviour
        d = 32'hFFFF_FFFF; load = 1; rst_n = 0;
        @(posedge clk); 
        #1;
        assert (q == 0) else $error("Reset failed");
        
        // Load Behaviour
        rst_n = 1; d = 32'hA5A5_A5A5; load = 1;
        @(posedge clk); 
        #1;
        assert (q == 32'hA5A5_A5A5) else $error("Load failed");
        
        // Hold Behaviour
        load = 0; d = 32'h1234_5678;
        @(posedge clk);
        #1;
        assert (q == 32'hA5A5_A5A5) else $error("Hold failed: q changed to %h", q);
		  
		  d = 32'hEEEE_EEEE; load = 1;
        @(posedge clk);
        #1;
        assert (q == 32'hA5A5_A5A5) else $error("Intentional Load Failure: q updated to %h", q);

		  @(posedge clk);
        rst_n = 0;
        #1;
        assert (q == 32'hFFFF_FFFF) else $error("Intentional Reset Failure: q is %h", q);

        #10;
        $display("Simulation Finished");
        $finish;
    end
endmodule