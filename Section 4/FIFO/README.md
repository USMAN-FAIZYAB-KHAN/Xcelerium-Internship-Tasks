# Synchronous FIFO
A First-In, First-Out (FIFO) buffer implemented in SystemVerilog. This design uses a synchronous clock domain and features a parameterized data width and depth, making it suitable for various digital design applications such as data buffering and rate matching.

## RTL Schematic
<img width="1592" height="421" alt="image" src="https://github.com/user-attachments/assets/1e798ded-c579-4a88-8782-96bd2ab0d390" />

## Features
- __Fully Parameterized__: Configure `DATA_WIDTH` (default 16) and `DEPTH` (default 8) at instantiation.
- __MSB Pointer Logic__: Uses the `N+1` bit pointer method to accurately distinguish between "Full" and "Empty" states.
- __Synchronous Operation__: All writes, reads, and pointer updates occur on the rising edge of the clock.
- __Self-Checking Testbench__: Includes a sophisticated testbench using SystemVerilog queues as a golden reference model to verify data integrity.

## Logic Overview
The FIFO utilizes two pointers, write_ptr and read_ptr, which are one bit wider than necessary to address the memory (ADDR_WIDTH + 1).
- __Empty Condition__: Occurs when both pointers are exactly equal.
- __Full Condition__: Occurs when the index bits are equal, but the Most Significant Bit (MSB) is different. This indicates the write pointer has wrapped around the memory space once more than the read pointer.

## Verification Strategy
The provided testbench (`FIFO_tb.sv`) ensures reliability through three distinct phases:
1. __Fill Test__: Writes data until the full flag is asserted and attempts an overflow write to ensure hardware protection.
2. __Empty Test__: Reads data until the empty flag is asserted and attempts an underflow read.
3. __Randomized Stimulus__: Executes a series of randomized read and write operations to simulate real-world data flow.

During simulation, the testbench maintains an internal SystemVerilog Queue. Every time a read occurs, the hardware output is compared against the queue's front element. If a mismatch occurs, a [READ ERROR] is reported in the console.

## Simulation Results
<img width="1166" height="225" alt="image" src="https://github.com/user-attachments/assets/19104508-3979-454b-a79b-53befc1e6c2e" />
<br>
<br>
<img width="1706" height="228" alt="image" src="https://github.com/user-attachments/assets/c04abbc6-07ad-467d-9192-4f227a4bed60" />

