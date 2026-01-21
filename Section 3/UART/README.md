# UART Controller
A SystemVerilog implementation of a Universal Asynchronous Receiver-Transmitter (UART).

## System Architecture
The system consists of three main hardware modules:
- __Baud Rate Generator__: A programmable frequency divider that generates a sampling tick (`s_tick`) at 16x the baud rate.
- __UART Transmitter (TX)__: Converts 8-bit parallel data into a serial stream with Start, Data, optional Parity, and Stop bits.
- __UART Receiver (RX)__: Reconstructs 8-bit parallel data from the serial input by sampling the center of each bit period for maximum reliability.

## FSM Design
### UART Transmitter
<img width="1471" height="2003" alt="UART Transmitter State Diagram" src="https://github.com/user-attachments/assets/1abea5dc-a1df-426d-aeb3-95b8426ab55e" />

### UART Receiver
<img width="1471" height="2048" alt="UART Receiver State Diagram" src="https://github.com/user-attachments/assets/9bf879dd-1b1c-4c87-aaa9-2ff4d04268cf" />

## Verification Methodology
The project uses a Layered Testbench architecture to automate the verification process.
- __Generator__: Creates uart_txn objects, supporting both Directed Testing (specific byte sequences) and Random Testing to exercise corner cases.
- __Driver__: Pulls transactions from the generator and drives the `vif.din` and `vif.tx_en` signals. It monitors the `tx_done` signal to know when the hardware has finished serializing the current byte and is ready for the next one.
- __Monitor__: Observes the interface and waits for the `rx_done` signal to go High. At that precise moment, it captures the valid parallel data from `vif.dout` and sends it to the Scoreboard via a mailbox.
- __Scoreboard__: Receives the "intended" data from the Generator and the "actual" captured data from the Monitor. It performs a real-time comparison and flags an error if a mismatch occurs.

## Functional Coverage
Verification completeness is tracked via a covergroup in the Monitor to ensure the FSMs were thoroughly exercised:
- __Signal Coverage__: Ensures correct activity on UART control and data signals by verifying that:
  - `tx` and `rx` lines toggle between logic 0 and 1
  - `tx_done` and `rx_done` are asserted, confirming successful transmission and reception events

- __State Coverage__: Confirms that both transmitter and receiver FSMs have exercised all protocol states (`IDLE`, `START`, `DATA`, `PARITY` and `STOP`). This ensures no FSM state remains unvisited during simulation.

- __Transition Coverage__: Validates correct UART protocol sequencing by covering all legal state transitions, including:
  - IDLE → START
  - START → DATA
  - DATA → DATA (multi-bit transmission)
  - DATA → PARITY
  - PARITY → STOP
  - STOP → IDLE
     
  for both TX and RX FSMs, ensuring the complete UART transaction loop is exercised.

## Simulation Results
<img width="1534" height="295" alt="image" src="https://github.com/user-attachments/assets/adcd752c-2b77-423e-9668-a708c0614eb1" />
<br>
<br>
<img width="1523" height="295" alt="image" src="https://github.com/user-attachments/assets/a943c7ea-e00e-49d8-a610-e40720762ff1" />
