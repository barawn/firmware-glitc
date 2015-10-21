`timescale 1ns / 1ps
module fabric_compare_4(
		GROUP,
		CLK,
		MAX,
		MAX_INDEX
    );
	parameter STAGENUM = 0;
	parameter NBITS = 11;
	parameter NGROUP = 4;
	input [NGROUP*NBITS-1:0] GROUP;
	input CLK;
	output [NBITS-1:0] MAX;
    output [1:0] MAX_INDEX;
    
	wire [NBITS-1:0] max1[NGROUP-1:0];
	wire [NBITS-1:0] max2[1:0];
	wire [1:0] max_index_0;
			
	assign max1[0] = GROUP[0 +: NBITS];
	assign max1[1] = GROUP[NBITS +: NBITS];
	assign max1[2] = GROUP[NBITS*2 +: NBITS];
	assign max1[3] = GROUP[NBITS*3 +: NBITS];
	
	assign max_index_0[0] = (max1[1] > max1[0]);
	assign max_index_0[1] = (max1[3] > max1[2]);
	
	assign MAX_INDEX[1] = (max2[1] > max2[0]);
    assign MAX_INDEX[2] = (MAX_INDEX[1]) ? max_index_0[1] : max_index_0[0];
    	
	assign max2[0] = (max_index_0[0]) ? max1[1] : max1[0];
	assign max2[1] = (max_index_0[1]) ? max1[3] : max1[2];
	
	assign MAX = (MAX_INDEX[1]) ? max2[1] : max2[0];

endmodule
