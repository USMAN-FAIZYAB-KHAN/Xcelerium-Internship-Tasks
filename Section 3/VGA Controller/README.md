# VGA Controller (640x480 @ 60Hz)
A SystemVerilog implementation of a VGA controller designed to generate precise timing signals and memory addresses for a standard 640x480 display.

## VGA Timing Parameters
| Parameter | Description                                      | Value (Pixels) |
|----------|--------------------------------------------------|----------------|
| H_ACTIVE | Visible Active Video Area                        | 640            |
| H_FP     | Horizontal Front Porch                           | 16             |
| H_SYNC   | Horizontal Sync Pulse (Active Low)               | 96             |
| H_BP     | Horizontal Back Porch                            | 48             |
| H_TOTAL  | Total pixels per scanline (H_ACTIVE + H_FP + H_SYNC + H_BP) | 800 |

| Parameter | Description                                      | Value (Lines) |
|----------|--------------------------------------------------|---------------|
| V_ACTIVE | Visible Active Video Lines                       | 480           |
| V_FP     | Vertical Front Porch                             | 10            |
| V_SYNC   | Vertical Sync Pulse (Active Low)                 | 2             |
| V_BP     | Vertical Back Porch                              | 33            |
| V_TOTAL  | Total lines per frame (V_ACTIVE + V_FP + V_SYNC + V_BP) | 525 |

## FSM Design
The VGA controller is implemented using two synchronized Finite State Machines (FSMs) that manage the horizontal scan and vertical frame timing.

<img width="1382" height="855" alt="VGA Controller State Transition Diagram" src="https://github.com/user-attachments/assets/185a7c86-668c-44bd-9368-5e7dc1852b27" />

### Horizontal State Machine
The Horizontal FSM controls the timing for a single scanline. It transitions based on the pixel clock (25 MHz) and the `h_cnt_reg` value:
- __Visible__: The active video region where pixels are drawn (h_cnt_reg == H_ACTIVE - 1).
- __Front Porch__: A brief blanking period before the sync pulse (h_cnt_reg == H_FP - 1).
- __Sync Pulse__: The period where hsync is pulled Low (active) to synchronize the monitor (h_cnt_reg == H_SYNC - 1).
- __Back Porch__: The final blanking period before the next visible line (h_cnt_reg == H_BP - 1). Completion of this state triggers the `h_end_of_line` signal.

### Vertical State Machine
The Vertical FSM manages the frame structure and only transitions when a full horizontal line is complete (`h_end_of_line` is high):
- __Visible__: The active vertical region containing 480 lines (v_cnt_reg == V_ACTIVE - 1).
- __Front Porch__: Blanking period before the vertical sync (v_cnt_reg == V_FP - 1).
- __Sync Pulse__: The period where vsync is pulled Low to signal a new frame (v_cnt_reg == V_SYNC - 1).
- __Back Porch__: The final blanking period before returning to the top of the screen (v_cnt_reg == V_BP - 1).

### SRAM Address Generation
The controller generates a 19-bit memory address (`sram_addr`) that increments only when both FSMs are in the Visible state. This provides a direct mapping from memory to the $640 \times 480$ display grid. The address automatically resets to 0 at the end of the Vertical Back Porch to prepare for the next frame.

## Verification Methodology
The project utilizes a Layered Testbench architecture to automate the verification of timing parameters:
- __Generator__: Creates `vga_txn` objects to drive the simulation.
- __Driver__: Fetches transactions and drives the `en` signal into the virtual interface (`vif`) synchronously with the 25MHz clock.
- __Monitor__: Observes the DUT outputs (`hsync`, `vsync`, `video_on`, `sram_addr`) and captures them for the scoreboard.
- __Scoreboard__: Implements a reference model to predict the exact state and address. It verifies that `sram_addr` increments correctly and resets precisely at the start of a new frame.

## Functional Coverage
Completeness is tracked via a covergroup in the Monitor, ensuring:
- __Signal Coverage__: Verification that hsync, vsync, and video_on have all toggled between active and inactive states.
- __State Coverage__: Ensuring both FSMs have spent time in all four timing states (VISIBLE through BACK PORCH).
- __Transition Coverage__: Verifying the full loop of the VGA protocol (e.g., ensuring the FSM correctly moves from SYNC PULSE to BACK PORCH).

## Simulation Results
<img width="1234" height="272" alt="image" src="https://github.com/user-attachments/assets/92fa6246-e15a-4465-836e-4b91d822c793" />
<br>
<br>
<img width="1360" height="271" alt="image" src="https://github.com/user-attachments/assets/5c228d25-42e9-4af2-a846-7dd9e9321169" />
<br>
<br>
<img width="1298" height="271" alt="image" src="https://github.com/user-attachments/assets/703a4844-f97c-4e81-8f34-edb2e26a4dae" />
