`timescale 1ns / 1ps
/** \brief Utility module to reverse the bits in a vector.
 *
 * Author: Patrick Allison (allison.122@osu.edu)
 */ 
module bit_reverser(
		A,
		B
    );

	parameter WIDTH=32;
	input [WIDTH-1:0] A;
	output [0:WIDTH-1] B;
	
	assign B = A;

endmodule
