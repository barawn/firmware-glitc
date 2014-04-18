`timescale 1ns / 1ps
module glitc_dedisperse(
		input [47:0] raw_i,
		output [47:0] filter_o,
		input clk_i
    );

	// Does nothing. Placeholder.
	assign filter_o = raw_i; 

/*
	parameter TOTLENGTH = 64;
	parameter DEMUX = 16;
	parameter NCLOCKS = (TOTLENGTH/DEMUX - 1);
	wire [NBITS-1:0] din_i[DEMUX-1:0];
	reg [2:0] shreg[NCLOCKS*DEMUX - 1:0];
	wire [2:0] inData[TOTLENGTH-1:0];
	generate
		genvar in_i,in_j;
		for (in_i=0;in_i<DEMUX;in_i=in_i+1) begin : INIT
			for (in_j=0;in_j<NCLOCKS;in_j=in_j+1) begin : INIT2
				// this initializes 0,16,32,1,17,33, etc. Still covers everything.
				initial shreg[j*DEMUX+i] <= {3{1'b0}};
				assign inData[j*DEMUX+i] = shreg[j*NCLOCKS+i];
			end
			assign din_i[in_i] = raw_i[in_i*NBITS +: NBITS];
			assign inData[in_i] = din_i[in_i];
		end
	endgenerate

	always @(posedge clk_i) begin
		shreg[0  +: 16] <= din_i;
		shreg[16 +: 16] <= shreg[0 +: 16];
		shreg[32 +: 16] <= shreg[16 +: 16];
	end
	function [6:0] calc_one_prodsum;
		input [2:0] A;
		input [2:0] B;
		input [2:0] cA;
		input [2:0] cB;
		reg [5:0] cAxA;
		reg [5:0] cBxB;
		begin
			cAxA = A*cA;
			cBxB = B*cB;
			calc_one_prodsum = cAxA + cBxB + A + B + 2;
		end
	endfunction
	
	function [31:0] lutinit;
		input [2:0] cA;
		input [2:0] cB;
		input [2:0] index;
		reg [5:0] tmp = {6{1'b0}};
		reg [5:0] tmp2 = {6{1'b0}};
		integer i = 0;
		begin
			if (index > 6) begin
				lutinit = {32{1'b0}};
			end else begin
				for (i=0;i<32;i=i+1) begin
					tmp = i;
					tmp2 = calc_one_prodsum(tmp[5:3],tmp[2:0],cA,cB);
					lutinit[i] = tmp2[index];
				end
			end
		end
	endfunction
*/	
	
	
endmodule
