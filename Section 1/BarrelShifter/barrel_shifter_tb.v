`timescale 1ns / 1ps

module barrel_shifter_tb;

    reg [31:0] data_in;
    reg [4:0]  shift_amt;
    reg        dir;
    wire [31:0] data_out;

    integer pass_count = 0;
    reg [31:0] exp_data;

    barrel_shifter uut (
        .data_in(data_in),
        .shift_amt(shift_amt),
        .dir(dir),
        .data_out(data_out)
    );

    task check_shift(input [31:0] t_data, input [4:0] t_amt, input t_dir);
        begin
            data_in   = t_data;
            shift_amt = t_amt;
            dir       = t_dir;
            
            if (t_dir == 1'b1)
                exp_data = t_data >> t_amt;
            else
                exp_data = t_data << t_amt;
					 
				#5;

            if (data_out === exp_data) begin
                 $display("\nPASS:");
                 $display("Inputs: In=%b | Amt=%d | Dir=%b", t_data, t_amt, t_dir);
                 $display("Output: Out=%b", data_out);
                 pass_count = pass_count + 1;
            end else begin
                 $display("\nFAIL:");
                 $display("Inputs:   In=%b | Amt=%d | Dir=%b", t_data, t_amt, t_dir);
                 $display("Expected: %b", exp_data);
                 $display("Got:      %b", data_out);
            end
        end
    endtask

    initial begin
        $display("--- Starting Testbench ---");

        repeat(8) begin
            check_shift($random, {$random} % 32, {$random} % 2);
        end

        $display("\nDone! Total Passed: %d", pass_count);
        $stop;
    end

endmodule