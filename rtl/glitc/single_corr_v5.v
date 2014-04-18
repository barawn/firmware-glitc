`timescale 1ns / 1ps
// Version 5 of a single correlator. This module only takes 16 inputs, and builds the 32-entry
// correlation from the current and previous sum.
//
// This version tweaks a few points - eliminates the multistep add, and eliminates the
// extraneous bit on the output of the squarer. Also actually register the output of the squarer
// to give it a chance to meet timing on a low-power Spartan-6.
//
// In order to align all of the correlations, the DELAY parameter determines how many clocks the
// output value is delayed by.
module single_corr_v5(
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
	
	//% This is the first-stage add (A+B for each entry)
	reg [4:0] res_single_1[DEMUX-1:0];
	//% This is the second-stage add (A+B+C for each entry). To be honest, a 3-way add is probably more efficient.
	reg [4:0] res_single[DEMUX-1:0];
	//% Add 3 to the constant entry to pick up the offset for all of them.
	reg [NBITS-1:0] C_delayed[DEMUX-1:0];
	
	//% (A+B+C)^2
	wire [6:0] res_square[DEMUX-1:0];
	//% (A+B+C)^2, registered.
	reg [5:0] res_squarer[DEMUX-1:0];

	//% First stage adder tree. Now 0+1+2+3, 4+5+6+7, etc.
	reg [7:0] res_tree_l1[7:0];
	//% Final adder stage and shift register.
	reg [9:0] res_tree_l4[1:0];
	//% Final output, and delay.
	reg [10:0] corr_sum[DELAY:0];
	
	wire [4:0] sign_extended_inputs[DEMUX-1:0][2:0];
	wire [4:0] sum_of_inputs[DEMUX-1:0];
	generate
		genvar ii;
		for (ii=0;ii<DEMUX;ii=ii+1) begin : EXTEND_LOOP
			assign sign_extended_inputs[ii][0] = {inA[ii][2],inA[ii]};
			assign sign_extended_inputs[ii][1] = {inB[ii][2],inB[ii]};
			assign sign_extended_inputs[ii][2] = {inC[ii][2],inC[ii]};
			assign sum_of_inputs[ii] = sign_extended_inputs[ii][0] +
												sign_extended_inputs[ii][1] +
												sign_extended_inputs[ii][2];
		end
	endgenerate
	
	integer i,j,k,l,m;
	initial begin
		i=0;j=0;k=0;l=0;m=0;
	end
	always @(posedge clk) begin
		for (i=0;i<DEMUX;i=i+1) begin
			// We were actually pipelining too heavily here, so
			// we ended up with hold time violations due to clock skew. So we'll see
			// how it handles doing the sum + square in one step.
			res_squarer[i] <= res_square[i][6:1];
//			// Generate the sum. One cycle only. Three way adds are easy.
////   res_single[i] <= {inA[i][2],inA[i][2],inA[i][2:0]} +
////          {inB[i][2],inB[i][2],inB[i][2:0]} +
////          {inC[i][2],inC[i][2],inC[i][2:0]};
//		res_single[i] <= {~inA[i][2],~inA[i][2], ~inA[i][2], inA[i][1:0]} + //LM: add change of sign....
//          {~inB[i][2],~inB[i][2], ~inB[i][2], inB[i][1:0]} +
//          {~inC[i][2],~inC[i][2], ~inC[i][2], inC[i][1:0]};
////			C_delayed[i] <= inC[i];
////			res_single[i] <= res_single_1[i] + {C_delayed[i][2],C_delayed[i][2],C_delayed[i]};
//			res_squarer[i] <= res_square[i][6:1];
		end

		// Adder tree. We were actually pipelining too strongly here, so again,
		// we'll go ahead and add 4 at once, rather than 2.
		// Ignore the bottom bit. It's always zero for valid inputs.
		for (j=0;j<4;j=j+1) begin
			res_tree_l1[j] <= res_squarer[2*j] + res_squarer[2*j+1] + res_squarer[2*j+2] + res_squarer[2*j+3];
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
	
	//% ROM-based squarer. This maps correctly with the 1.5 offset in each one, and drops the implicit
	//% 0.25 output. That is, for an input of (0), which corresponds to an input of 1.5, you get an output
	//% of 2 instead of 2.25.
	generate
		genvar sq_i;
		for (sq_i=0;sq_i<DEMUX;sq_i=sq_i+1) begin : SQUARER
			 squarer_mod2_hdl sq(.a(sum_of_inputs[sq_i]),.spo(res_square[sq_i]));
		end
	endgenerate
	
	// Upshift by 1 to recover the implicitly dropped bit at the output of the squarer.
	assign CORR = {corr_sum[DELAY],1'b0};
endmodule
