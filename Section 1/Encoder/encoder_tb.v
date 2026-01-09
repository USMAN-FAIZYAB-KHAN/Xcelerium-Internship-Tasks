`timescale 1ns / 1ps

module encoder_tb;

    reg [7:0] in;
    wire [2:0] out;
    wire valid;
    
    integer i, k;
    reg [2:0] exp_out;
    reg exp_valid;
    integer pass_count = 0;

    encoder uut (
        .in(in), 
        .out(out), 
        .valid(valid)
    );

    task check_encoder(input [7:0] test_in);
        begin
            in = test_in;
            exp_valid = (test_in != 0);
            
            exp_out = 3'b000;
            for (k = 0; k < 8; k = k + 1) begin
                if (test_in[k]) begin
                    exp_out = k;
                end
            end
				
				#5;

            if ((out == exp_out) && (valid == exp_valid)) begin
                $display("PASS: Input=%b -> Out=%b Valid=%b", in, out, valid);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: Input=%b | Expected Out=%b Valid=%b | Got Out=%b Valid=%b", 
                          in, exp_out, exp_valid, out, valid);
            end
        end
    endtask

    initial begin        
        $display("--- Starting Testbench ---");

        check_encoder(8'b0000_0000);

        $display("Testing Single Bit Patterns...");
        for (i = 0; i < 8; i = i + 1) begin
            check_encoder(1 << i);
        end

        $display("Testing Multi-Bit Priority Patterns...");
        check_encoder(8'b1000_0001);
        check_encoder(8'b0001_1100);

        $display("Done! Total Passed: %0d", pass_count);
        $stop;
    end

endmodule