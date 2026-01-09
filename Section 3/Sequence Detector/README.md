# "1011" Sequence Detector FSM
A SystemVerilog implementation of a Moore-type Finite State Machine (FSM) designed to detect the overlapping sequence 1011 in a serial bit stream.


## FSM Design
The detector is implemented as a Moore Machine, meaning the output seq_detected depends solely on the current state.

<p align="center">
  <img width="753" height="349" alt="Sequence Detector State Transition Diagram" src="https://github.com/user-attachments/assets/e767d562-51bf-4fc3-8773-57814f6d5152" />
</p>

- **States:** Five states (S0 to S4) representing the progress of the sequence detection.
- **Overlapping Detection:** The FSM is designed to handle overlapping patterns (e.g., `1011011` will trigger the output twice).
- **Reset:** Features an asynchronous active-low reset (`rst_n`) that forces the FSM back to the IDLE state (S0).

## Verification Methodology
The project uses a Layered Testbench architecture to ensure high verification quality and modularity:
- **Generator:** Creates both directed (pre-defined) and random bit sequences using SystemVerilog queues.
- **Driver:** Pulls transactions from the generator and drives the input in_bit to the DUT on every clock edge.
- **Monitor:** Samples the interface and sends the observed data to the Scoreboard.
- **Scoreboard:** Maintains a "golden model" (using a 4-bit shift register) to compare actual results with expected values.
- **Interface:** Simplifies connections and encapsulates all signals between the testbench and DUT.

## Functional Coverage
The project includes a covergroup in the Monitor to track:
- **State Coverage:** Ensuring every state (S0–S4) was visited.
- **Transition Coverage:** Verifying every possible transition path between states.
- **Sequence Coverage:** Specifically tracking if the target sequence 1011 and overlapping sequences were fully exercised.

## Simulation Results
<img width="1197" height="335" alt="image" src="https://github.com/user-attachments/assets/1bba91de-50e5-4d47-a4c2-505fe1e54a5a" />
