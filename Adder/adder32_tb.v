`timescale 1ns / 1ps

module adder32_tb;

    reg [31:0] a, b;
    reg cin;
    wire [31:0] sum;
    wire cout;
    integer pass_count = 0;
    integer i;

    adder32 uut (.a(a), .b(b), .cin(cin), .sum(sum), .cout(cout));

    task check_add(input [31:0] ta, input [31:0] tb, input tcin);
        begin
            a = ta; b = tb; cin = tcin;
            #5;
            if ({cout, sum} === (a + b + cin)) begin
                $display("PASS: %h + %h + %b = %h (Cout: %b)", a, b, cin, sum, cout);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %h + %h + %b | Got %h", a, b, cin, sum);
            end
        end
    endtask

    initial begin
        $display("--- Starting Testbench ---");
		  
		  check_add(32'h0, 32'h0, 0);               
        check_add(32'hFFFFFFFF, 32'hFFFFFFFF, 0);  

        for (i = 0; i < 5; i = i + 1) begin
            check_add($random, $random, i % 2);
        end

        $display("Done! Total Passed: %0d", pass_count);
        $stop;
    end

endmodule