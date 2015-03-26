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

/** \brief Version 6 of a single correlator, using optimized logic.
 *
 * This version of the GLITC correlator uses a number of logic improvements:
 * - Single-slice 3-way add (ternary_add_logic)
 * - Single-slice squaring (slice_square_logic)
 * - DSP-based summing.
 *  
 * The single-slice 3-way add and single-slice square should reduce
 * routing congestion significantly, since 
 */
module single_corr_v6(
		clk,
		A,
		B,
		C,
		CORR
    );

	parameter DELAY = 0;
	parameter DEMUX = 16;
	parameter NBITS = 3;
	localparam NCBITS = DEMUX*NBITS;
	input [NCBITS-1:0] A;
	input [NCBITS-1:0] B;
	input [NCBITS-1:0] C;
	output [11:0] CORR;
	input clk;
	
	wire [NBITS-1:0] inA[DEMUX-1:0];
	wire [NBITS-1:0] inB[DEMUX-1:0];
	wire [NBITS-1:0] inC[DEMUX-1:0];
	
	generate
		genvar in_i;
		for (in_i=0;in_i<DEMUX;in_i=in_i+1) begin : INIT
			assign inA[in_i] = A[in_i*NBITS +: NBITS];
			assign inB[in_i] = B[in_i*NBITS +: NBITS];
			assign inC[in_i] = C[in_i*NBITS +: NBITS];
		end
	endgenerate
		
	//% (A+B+C)^2
	wire [5:0] res_square[DEMUX-1:0];

	wire [4:0] sum_of_inputs[DEMUX-1:0];
	generate
		genvar ii;
		for (ii=0;ii<DEMUX;ii=ii+1) begin : EXTEND_LOOP
			ternary_add_logic u_ternary_add(.A(inA[ii]),
													  .B(inB[ii]),
													  .C(inC[ii]),
													  .D(sum_of_inputs[ii]),
													  .CLK(clk));
			slice_square_logic u_slicesquare(.I(sum_of_inputs[ii]),
														.SQR(res_square[ii]),
														.CLK(clk));
		end
	endgenerate

/*
	//% First stage adder tree. Now 0+1+2+3, 4+5+6+7, etc.
	reg [7:0] res_tree_l1[7:0];
	//% Final adder stage and shift register.
	reg [9:0] res_tree_l4[1:0];
	//% Final output, and delay.
	reg [10:0] corr_sum[DELAY:0];
	
	integer i,j,k,l,m;
	initial begin
		i=0;j=0;k=0;l=0;m=0;
	end
	always @(posedge clk) begin
		// Adder tree. We were actually pipelining too strongly here, so again,
		// we'll go ahead and add 4 at once, rather than 2.
		// Ignore the bottom bit. It's always zero for valid inputs.
		for (j=0;j<4;j=j+1) begin
			res_tree_l1[j] <= res_square[4*j] + res_square[4*j+1] + res_square[4*j+2] + res_square[4*j+3];
		end
		// Last level of the adder tree.
		res_tree_l4[0] <= res_tree_l1[0] + res_tree_l1[1] + res_tree_l1[2] + res_tree_l1[3];
		// Pipe.
		res_tree_l4[1] <= res_tree_l4[0];
		// Output. We pick up the extra 8 from the implicitly dropped 0.25 after the squarer (*32).
		// Adding a constant 8 here is easy.
		// Now we only add 4 because we're actually downshifted by 1.
		corr_sum[0] <= res_tree_l4[0] + res_tree_l4[1] + 4;
		for (m=1;m<DELAY;m=m+1) begin
			corr_sum[m] <= corr_sum[m-1];
		end
	end
*/
	// Stage 1: add half of the inputs (0,1,2,3,4,5,6,7), pairwise. Pass those to stage 2.
	// Stage 2: Delay other half of inputs (8,9,10,11,12,13,14,15). Add those pairwise, plus the stage 1 inputs cascaded.
	// We now have 4 inputs that we need to feed together: call them A, B, C, D.

	// Sum of the first half of inputs, pairwise.
	wire [12:0] sum_1[3:0];
	// Cascade to second adder.
	wire [47:0]	quadsum_cascade;
	// 4-input sum (0,1,8,9), etc.
	wire [12:0] sum_2[3:0];
	wire [12:0] sum_3[1:0];
	wire [12:0] sum_4[1:0];
	reg [11:0] sum_4_store = {12{1'b0}};
	assign sum_4[1] = sum_4_store;
	quad_dsp_sum #(.ADD_CASCADE(0),.INPUT_REG(0),.OUTPUT_REG(1)) 
				  u_quadsum_1(.A(res_square[0]),.B(res_square[1]),.C(res_square[2]),.D(res_square[3]),
								  .E(res_square[4]),.F(res_square[5]),.G(res_square[6]),.H(res_square[7]),
								  .APB(sum_1[0]),.CPD(sum_1[1]),.EPF(sum_1[2]),.GPH(sum_1[3]),
								  .CASC_OUT(quadsum_cascade),
								  .CLK(clk));
	quad_dsp_sum #(.ADD_CASCADE(1),.INPUT_REG(1),.OUTPUT_REG(0))
				  u_quadsum_2(.A(res_square[8]),.B(res_square[9]),.C(res_square[10]),.D(res_square[11]),
								  .E(res_square[12]),.F(res_square[13]),.G(res_square[14]),.H(res_square[15]),
								  .CASC_IN(quadsum_cascade),
								  .APB(sum_2[0]),.CPD(sum_2[1]),.EPF(sum_2[2]),.GPH(sum_2[3]),
								  .CLK(clk));
// Need to think about the full architecture. 
	quad_dsp_sum #(.ADD_CASCADE(0),.INPUT_REG(1),.OUTPUT_REG(0))
				  u_quadsum_3(.A(sum_2[0]),.B(sum_2[1]),.C(sum_2[2]),.D(sum_2[3]),
								 .E(sum_3[0]),.F(sum_3[1]),.G(sum_4[0]),.H(sum_4[1]),
								 .APB(sum_3[0]),.CPD(sum_3[1]),.EPF(sum_4[0]),.GPH(corr_out),
								 .CLK(clk));
	always @(posedge clk) begin
		sum_4_store <= sum_4[0][11:0];
	end
	wire [10:0] corr_sum[DELAY:0];
	assign corr_sum[0] = corr_out;
	generate
		genvar d_i;
		for (d_i=0;d_i<DELAY;d_i=d_i+1) begin : DL
			if (d_i > 0) begin : ST
				reg [10:0] corr_store = {11{1'b0}};
				always @(posedge clk) begin : STL
					corr_store <= corr_sum[d_i-1];
				end
				assign corr_sum[d_i] = corr_store;
			end
		end
	endgenerate
		
	// Upshift by 1 to recover the implicitly dropped bit at the output of the squarer.
	assign CORR = {corr_sum[DELAY],1'b0};
endmodule
