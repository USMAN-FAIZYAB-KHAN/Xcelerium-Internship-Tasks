# ALU
A flexible, self-checking Arithmetic Logic Unit (ALU) implemented in SystemVerilog. This project features a parameterized data width, a dedicated package for operation types, and a randomized testbench for verification.

## Features
- __Parameterized Width__: Default is 16-bit, but can be easily reconfigured via the N parameter.
- __7 Supported Operations__: Includes arithmetic, logical, and shift operations.
- __Status Flags__: Provides `CARRY` and `ZERO` flags for branch logic or status monitoring.
- __Self-Checking Testbench__: Uses randomized stimulus and compares DUT (Device Under Test) results against a reference model.

## Instruction Set
The ALU uses a 3-bit operation code defined in `alu_pkg.sv`:
| OP Code | Name        | Description                       |
|---------|-------------|-----------------------------------|
|   000   | AND         | Addition (A + B)                  |
|   001   | SUB         | Subtraction (A - B)               |
|   010   | AND         | Bitwise AND                       |
|   011   | OR          | Bitwise OR                        |
|   100   | XOR         | Bitwise XOR                       |
|   101   | SHIFT_LEFT  | Logical Left Shift (A << B[3:0])  |
|   110   | SHIFT_RIGHT | Logical Right Shift (A << B[3:0]) |

## File Structure
- __alu_pkg.sv__: Contains the typedef enum for ALU operations.
- __ALU.sv__: The core combinational logic for the ALU.
- __ALU_tb.sv__: The testbench providing randomized inputs and automated verification.

## Simulation Results
<img width="1651" height="228" alt="image" src="https://github.com/user-attachments/assets/036e6f75-c85e-4524-bfe1-75aa9e56ae53" />
<br>
<br>
<img width="1676" height="237" alt="image" src="https://github.com/user-attachments/assets/684128f9-acde-49c3-83f4-f5713ae1eee1" />




