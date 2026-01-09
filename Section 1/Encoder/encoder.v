module encoder(input [7:0] in, output reg [2:0] out, output valid);

    // If any bit is 1, valid is 1
    assign valid = |in; 

    always @(*) begin
        if      (in[7]) out = 3'b111;
        else if (in[6]) out = 3'b110;
        else if (in[5]) out = 3'b101;
        else if (in[4]) out = 3'b100;
        else if (in[3]) out = 3'b011;
        else if (in[2]) out = 3'b010;
        else if (in[1]) out = 3'b001;
        else if (in[0]) out = 3'b000;
	else 		out = 3'b000; // To prevent latch
    end
	 
endmodule