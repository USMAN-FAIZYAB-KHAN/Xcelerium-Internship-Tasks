`timescale 1ns/1ps

module i2c_tb;

    // --- 1. Signal Declarations ---
    logic clk;
    logic rst_n;
    
    // tri1 simulates the pull-up resistor (lines stay High unless driven Low)
    tri1 scl; 
    tri1 sda;

    logic [11:0] rx_data;
    logic done;

    // Master control registers
    logic scl_out; 
    logic sda_out;

    // Open-drain emulation
    assign scl = (scl_out) ? 1'bz : 1'b0;
    assign sda = (sda_out) ? 1'bz : 1'b0;

    // --- 2. Instantiate DUT ---
    i2c_slave dut (
        .clk(clk),
        .rst_n(rst_n),
        .scl(scl),
        .sda(sda),
        .rx_data(rx_data),
        .done(done)
    );

    // --- 3. Clock Generation (50MHz) ---
    always #10 clk = ~clk;

    // --- 4. Master Protocol Tasks ---
    
    // START: SDA falls while SCL is High
    task send_start();
        scl_out = 1; sda_out = 1; #200;
        sda_out = 0; #200;
        scl_out = 0; #200;
    endtask

    // STOP: SDA rises while SCL is High
    task send_stop();
        sda_out = 0; #200;
        scl_out = 1; #200;
        sda_out = 1; #200;
    endtask

    // Sends 8 bits and waits for the Slave's ACK pulse
    task send_byte(input [7:0] data);
        for (int i = 7; i >= 0; i--) begin
            sda_out = data[i];
            #200;
            scl_out = 1; #400; // Slave samples on rising edge
            scl_out = 0; #200;
        end

        // 9th Clock Cycle (ACK Phase)
        sda_out = 1; // Master releases SDA
        #200;
        scl_out = 1; #400; // Slave drives SDA low here
        if (sda == 0) $display("[%0t] [TB] ACK received", $time);
        else          $error("[%0t] [TB] NACK received!", $time);
        scl_out = 0; #200;
    endtask

    // --- 5. Main Test Sequence ---
    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        scl_out = 1;
        sda_out = 1;
        
        #100 rst_n = 1;
        #100;

        $display("\n--- Starting I2C Test: Address 7'd52, Data 12'hABC ---");

        // 1. Start Condition
        send_start();

        // 2. Send Address: 7'd52 (7'h34) + Write Bit (0)
        // 7'h34 << 1 = 8'h68
        send_byte(8'h68); 

        // 3. Send Data Byte 1: Upper 8 bits (hAB)
        send_byte(8'hAB);

        // 4. Send Data Byte 2: Lower 4 bits + 4 padding bits (hC0)
        send_byte(8'hC0);

        // 5. Stop Condition
        send_stop();


        if (rx_data === 12'hABC) 
           $display("[%0t] [TB] SUCCESS: Received %h", $time, rx_data);
        else 
           $display("[%0t] [TB] FAILED: Expected ABC, got %h", $time, rx_data);
   

        #500;
        $finish;
    end

endmodule