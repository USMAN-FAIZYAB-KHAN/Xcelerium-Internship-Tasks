module FIFO #(
    parameter DEPTH = 8,
    parameter DATA_WIDTH = 16
)(
    input  logic                   clk,
    input  logic                   rst,
    input  logic                   write_en,
    input  logic                   read_en,
    input  logic [DATA_WIDTH-1:0]  data_in,
    output logic [DATA_WIDTH-1:0]  data_out,
    output logic                   full,
    output logic                   empty
);

    localparam ADDR_WIDTH = $clog2(DEPTH);
    
    // Using one extra bit for FULL logic
    logic [ADDR_WIDTH:0] write_ptr, read_ptr;
    
    logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Write Logic
    always_ff @(posedge clk) begin
        if (rst) begin
            write_ptr <= 0;
        end else if (write_en && !full) begin
            mem[write_ptr[ADDR_WIDTH-1:0]] <= data_in;
            write_ptr <= write_ptr + 1;
        end
    end

    // Read Logic
    always_ff @(posedge clk) begin
        if (rst) begin
            read_ptr <= 0;
            data_out <= 0;
        end else if (read_en && !empty) begin
            data_out <= mem[read_ptr[ADDR_WIDTH-1:0]];
            read_ptr <= read_ptr + 1;
        end
    end

    // Status Flags
    assign empty = (write_ptr == read_ptr);
    
    // Full if MSB is different but index bits are the same 
    // (e.g. write_ptr = 1000 read_ptr = 0000)
    assign full  = (write_ptr[ADDR_WIDTH] != read_ptr[ADDR_WIDTH]) &&
                   (write_ptr[ADDR_WIDTH-1:0] == read_ptr[ADDR_WIDTH-1:0]);

endmodule