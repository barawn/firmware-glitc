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

/** \brief Partition/preadd for the v7 quad correlator.
 *
 * This module splits up the 16 (A+B+C)^2 samples to feed to the DSP adder cascade.
 * It also pre-adds half of them pairwise since they have to be stored for a cycle anyway.
 *
 * This is in its own module because the exact partitioning (which bits go where) could
 * possibly affect the routing, so we leave things here in case we need to change it.
 * That way downstream logic stays the same.
 *
 * Preadding is done either in slice logic (if PREADD_TYPE == "SLICE_PREADD") or in
 * a single DSP (PREADD_TYPE = "DSP_PREADD"). I don't know which one will be better.
 * 
 */
module partition_and_preadd_v7(
		clk,
		IN,
		STAGE1A, STAGE1B,
		STAGE2A, STAGE2B,
		STAGE3A, STAGE3B,
		STAGE4A, STAGE4B,
		STAGE5A, STAGE5B,
		STAGE6A, STAGE6B
    );

	parameter PREADD_TYPE = "SLICE_PREADD";

	parameter DEMUX = 16;
	parameter INBITS = 6;
	parameter DSPBITS = 12;
	localparam NINBITS = DEMUX*INBITS;
	
	input clk;
	input [NINBITS-1:0] IN;
	output [DSPBITS-1:0] STAGE1A;
	output [DSPBITS-1:0] STAGE1B;
	output [DSPBITS-1:0] STAGE2A;
	output [DSPBITS-1:0] STAGE2B;
	output [DSPBITS-1:0] STAGE3A;
	output [DSPBITS-1:0] STAGE3B;
	output [DSPBITS-1:0] STAGE4A;
	output [DSPBITS-1:0] STAGE4B;
	output [DSPBITS-1:0] STAGE5A;
	output [DSPBITS-1:0] STAGE5B;
	output [DSPBITS-1:0] STAGE6A;
	output [DSPBITS-1:0] STAGE6B;
	
	wire [INBITS-1:0] input_vector[DEMUX-1:0];
	generate
		genvar i;
		for (i=0;i<DEMUX;i=i+1) begin : VEC
			assign input_vector[i] = IN[INBITS*i +: INBITS];
		end
	endgenerate
	
	// Stage1 outputs.
	assign STAGE1A = {{DSPBITS-INBITS{1'b0}},input_vector[0]};
	assign STAGE1B = {{DSPBITS-INBITS{1'b0}},input_vector[1]};
	// Stage2 outputs.
	assign STAGE2A = {{DSPBITS-INBITS{1'b0}},input_vector[2]};
	assign STAGE2B = {{DSPBITS-INBITS{1'b0}},input_vector[3]};
	// Stage3 outputs.
	assign STAGE3A = {{DSPBITS-INBITS{1'b0}},input_vector[4]};
	assign STAGE3B = {{DSPBITS-INBITS{1'b0}},input_vector[5]};
	// Stage4 outputs.
	assign STAGE4A = {{DSPBITS-INBITS{1'b0}},input_vector[6]};
	assign STAGE4B = {{DSPBITS-INBITS{1'b0}},input_vector[7]};
	
	generate
		if (PREADD_TYPE == "SLICE_PREADD") begin : SLICE_PREADD
			//% Pre-add values. 4 total, for the last two stages.
			reg [INBITS:0] preadd_0 = {INBITS{1'b0}};
			reg [INBITS:0] preadd_1 = {INBITS{1'b0}};
			reg [INBITS:0] preadd_2 = {INBITS{1'b0}};
			reg [INBITS:0] preadd_3 = {INBITS{1'b0}};
			
			always @(posedge clk) begin
				preadd_0 <= input_vector[8] + input_vector[9];
				preadd_1 <= input_vector[10] + input_vector[11];
				preadd_2 <= input_vector[12] + input_vector[13];
				preadd_3 <= input_vector[14] + input_vector[15];
			end
			
			// Stage5 outputs.
			assign STAGE5A = {{DSPBITS-INBITS+1{1'b0}},preadd_0};
			assign STAGE5B = {{DSPBITS-INBITS+1{1'b0}},preadd_1};
			// Stage6 outputs.
			assign STAGE6A = {{DSPBITS-INBITS+1{1'b0}},preadd_2};
			assign STAGE6B = {{DSPBITS-INBITS+1{1'b0}},preadd_3};
		end else begin : DSP_PREADD
			quad_dsp_sum #(.ADD_CASCADE(0),.INPUT_REG(0),.OUTPUT_REG(1))
				u_preadder(.A(input_vector[8]),.B(input_vector[9]),
							  .C(input_vector[10]),.D(input_vector[11]),
							  .E(input_vector[12]),.F(input_vector[13]),
							  .G(input_vector[14]),.H(input_vector[15]),
							  .APB(STAGE5A),.CPD(STAGE5B),
							  .EPF(STAGE6A),.GPH(STAGE6B),
							  .CLK(clk));
		end
	endgenerate
endmodule
