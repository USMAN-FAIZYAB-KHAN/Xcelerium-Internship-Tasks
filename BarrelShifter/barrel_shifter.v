module barrel_shifter(data_in, shift_amt, dir, data_out);
	
	input [31:0] data_in;
	input [4:0] shift_amt;
	input dir;
	output [31:0] data_out;
	
	assign data_out = dir ? data_in >> shift_amt : data_in << shift_amt;
	
endmodule