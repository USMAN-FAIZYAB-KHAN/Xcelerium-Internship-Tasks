`timescale 1ns/1ps

module FIFO_tb;
    parameter DEPTH = 8;
    parameter DATA_WIDTH = 16;

    bit   clk;
    logic rst;
    logic write_en;
    logic read_en;
    logic [DATA_WIDTH-1:0] data_in;
    logic [DATA_WIDTH-1:0] data_out;
    logic full;
    logic empty;

    logic [DATA_WIDTH-1:0] queue [$];
    logic [DATA_WIDTH-1:0] expected_data;

    FIFO #(
        .DEPTH(DEPTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .write_en(write_en),
        .read_en(read_en),
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty)
    );

    always #10 clk = ~clk;

    // Write Data
    task write_data(input [DATA_WIDTH-1:0] val);
        @(negedge clk);
        if (!full) begin
            write_en = 1;
            data_in = val;
            queue.push_back(val);
            $display("[WRITE] Data: %h", val);
        end else begin
            $display("[WRITE SKIP] FIFO Full! Cannot write %h", val);
        end
        @(posedge clk);
        write_en = 0;
    endtask

    // Read Data
    task read_data();
        @(negedge clk);
        if (!empty) begin
            read_en = 1;
            @(posedge clk);
            #1;
            expected_data = queue.pop_front();
            if (data_out === expected_data) begin
                $display("[READ SUCCESS] Data: %h", data_out);
            end else begin
                $display("[READ ERROR] Expected: %h, Got: %h", expected_data, data_out);
            end
        end else begin
            $display("[READ SKIP] FIFO Empty!");
        end
        read_en = 0;
    endtask

    initial begin
        int op;
        rst = 1;
        write_en = 0;
        read_en = 0;
        data_in = 0;
		
        
        repeat(2) @(posedge clk);
        rst = 0;
        $display("--- Starting FIFO Test ---");

        // 1. Fill the FIFO to the max
        $display("\nTest 1: Filling FIFO...");
        repeat (DEPTH) begin
            write_data($urandom_range(16'hFFFF));
        end
        
        if (full) $display("Status Check: FIFO is FULL as expected.");

        // 2. Try writing to a full FIFO (Should be ignored)
        write_data(16'hBEEF);

        // 3. Read everything back
        $display("\nTest 2: Emptying FIFO...");
        repeat (DEPTH) begin
            read_data();
        end

        if (empty) $display("Status Check: FIFO is EMPTY as expected.");

        // 4. Randomized Read/Write Sequence
        $display("\nTest 3: Randomized sequence...");
        repeat (20) begin
            op = $urandom_range(0, 1);
            if (op == 0) write_data($random % 65536);
            else        read_data();
            #10;
        end

        $display("\n--- Simulation Finished ---");
        $finish;
    end

endmodule