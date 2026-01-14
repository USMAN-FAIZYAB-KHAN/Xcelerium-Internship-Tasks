// it generaters 4 ticks per I2C clock period
module i2c_tick_gen #(
   parameter SYS_CLK_FREQ = 50_000_000, // 50 MHz
   parameter I2C_FREQ     = 100_000 // 100 kHz
)(
   input  logic clk, // System clock
   input  logic rst_n,
   output logic tick_4x // 4x I2C clock tick
);
   localparam DIVISOR = SYS_CLK_FREQ / (I2C_FREQ * 4);
   logic [$clog2(DIVISOR)-1:0] count;

   always_ff @(posedge clk or negedge rst_n) begin
       if (!rst_n) begin
           count <= '0;
           tick_4x <= 1'b0;
       end else begin
           if (count == DIVISOR - 1) begin
               count <= '0;
               tick_4x <= 1'b1;
           end else begin
               count <= count + 1;
               tick_4x <= 1'b0;
           end
       end
   end
endmodule