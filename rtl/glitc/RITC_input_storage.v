`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// This file is a part of the Antarctic Impulsive Transient Antenna (ANITA)
// project, a collaborative scientific effort between multiple institutions. For
// more information, contact Peter Gorham (gorham@phys.hawaii.edu).
//
// All rights reserved.
//
// Author: Patrick Allison, Ohio State University (allison.122@osu.edu)
// Author:
// Author:
////////////////////////////////////////////////////////////////////////////////
module RITC_input_storage(
			clk_i,
			A_i, B_i, C_i,
			AS_o, BS_o, CS_o
    );
	
	parameter NBITS = 48;
	parameter A_STAGES = 1;
	parameter B_STAGES = 2;
	parameter C_STAGES = 3;
	
	input clk_i;
	input [NBITS-1:0] A_i;
	input [NBITS-1:0] B_i;
	input [NBITS-1:0] C_i;
	output [NBITS*(A_STAGES+1)-1:0] AS_o;
	output [NBITS*(B_STAGES+1)-1:0] BS_o;
	output [NBITS*(C_STAGES+1)-1:0] CS_o;
	
	assign AS_o[ NBITS-1 : 0 ] = A_i;
	assign BS_o[ NBITS-1 : 0 ] = B_i;
	assign CS_o[ NBITS-1 : 0 ] = C_i;
	
	generate
		genvar ai, bi, ci;
		if (A_STAGES > 0) begin : A0
			// For each stage, create an NBITS-wide shift register.
			reg [(A_STAGES)*NBITS-1:0] a_shift = {(A_STAGES)*NBITS-1{1'b0}};
			for (ai=0;ai<A_STAGES;ai=ai+1) begin : LOOP
				// First stage sees the input.
				if (ai == 0 ) begin : HEAD
					always @(posedge clk_i) begin : HEAD_SHIFT
						a_shift[ NBITS*(ai) +: NBITS ] <= A_i;
					end
				end 
				// Everyone else sees a shift register.
				else begin : BODY
					always @(posedge clk_i) begin : BODY_SHIFT
						a_shift[ NBITS*(ai) +: NBITS ] <= a_shift[ NBITS*(ai-1) +: NBITS ];
					end
				end
			end
			assign AS_o[ NBITS +: (NBITS*A_STAGES) ] = a_shift;
		end
		if (B_STAGES > 0) begin : B0
			// For each stage, create an NBITS-wide shift register.
			reg [(B_STAGES)*NBITS-1:0] b_shift = {(B_STAGES)*NBITS-1{1'b0}};
			for (bi=0;bi<B_STAGES;bi=bi+1) begin : LOOP
				if (bi == 0 ) begin : HEAD
					always @(posedge clk_i) begin : HEAD_SHIFT
						b_shift[ NBITS*(bi) +: NBITS ] <= B_i;
					end
				end else begin : BODY
					always @(posedge clk_i) begin : BODY_SHIFT
						b_shift[ NBITS*(bi) +: NBITS ] <= b_shift[ NBITS*(bi-1) +: NBITS ];
					end
				end
			end
			assign BS_o[ NBITS +: (NBITS*B_STAGES) ] = b_shift;
		end
		if (C_STAGES > 0) begin : C0
			// For each stage, create an NBITS-wide shift register.
			reg [(C_STAGES)*NBITS-1:0] c_shift = {(C_STAGES)*NBITS-1{1'b0}};
			for (ci=0;ci<C_STAGES;ci=ci+1) begin : LOOP
				if (ci == 0 ) begin : HEAD
					always @(posedge clk_i) begin : HEAD_SHIFT
						c_shift[ NBITS*(ci) +: NBITS ] <= C_i;
					end
				end else begin : BODY
					always @(posedge clk_i) begin : BODY_SHIFT
						c_shift[ NBITS*(ci) +: NBITS ] <= c_shift[ NBITS*(ci-1) +: NBITS ];
					end
				end
			end
			assign CS_o[ NBITS +: (NBITS*C_STAGES) ] = c_shift;
		end
	endgenerate

endmodule
