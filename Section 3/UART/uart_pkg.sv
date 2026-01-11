package uart_pkg;

interface uart_if;
    // Data and Control Signals
    logic [7:0] din;          // Data to be transmitted
    logic [7:0] dout;         // Data received
    logic       tx_en;        // Enable transmission
    logic       tx;           // Physical TX line
    logic       rx;           // Physical RX line
    
    // Status Ticks
    logic       tx_done_tick; // Transmission complete
    logic       rx_done_tick; // Reception complete

    // Modport for the Transmitter module
    modport tx_mp (
        input  din, tx_en,
        output tx, tx_done_tick
    );

    // Modport for the Receiver module
    modport rx_mp (
        input  rx,
        output dout, rx_done_tick
    );
    
endinterface

endpackage