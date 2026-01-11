`timescale 1ns / 1ps
module adder_tree_multiplier_tb;
    
	 reg [7:0] a;
    reg [7:0] b;
    reg clk;
    reg ena;
    reg enb;

    wire [15:0] p;

    adder_tree_multiplier uut (
        .a(a), 
        .b(b), 
        .clk(clk), 
        .ena(ena), 
        .enb(enb), 
        .p(p)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        ena = 0;
        enb = 0;
        a = 0;
        b = 0;

        #20;
        
        @(negedge clk);
        a = 8'd5;
        b = 8'd3;
        ena = 1;
        enb = 1;
        
        @(negedge clk);
        ena = 0;
        enb = 0;
        
        repeat (2) @(posedge clk);
        $display("Test 1: 5 * 3 = %d (Expected: 15)", p);

        // 3. Load second set: 10 * 10 = 100
        @(negedge clk);
        a = 8'd10;
        b = 8'd10;
        ena = 1;
        enb = 1;
        
        repeat (2) @(posedge clk);
        $display("Test 2: 10 * 10 = %d (Expected: 100)", p);

        @(negedge clk);
        a = 8'd255;
        b = 8'd2;
        
        repeat (2) @(posedge clk);
        $display("Test 3: 255 * 2 = %d (Expected: 510)", p);

        @(negedge clk);
        a = 8'd255;
        b = 8'd255;
        
        repeat (2) @(posedge clk);
        $display("Test 4: 255 * 255 = %d (Expected: 65025)", p);

        #20 $finish;
    end
      
    initial begin
        $monitor("Time=%0t | a=%d | b=%d | p=%d", $time, a, b, p);
    end

endmodule