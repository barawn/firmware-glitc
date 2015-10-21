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

/** \brief Partition/preadd, version 8.
 *
 * This module splits up the 16 (A+B+C)^2 samples to feed to the DSP adder cascade.
 * It also pre-adds half of them pairwise since they have to be stored for a cycle anyway.
 *
 * This is in its own module because the exact partitioning (which bits go where) could
 * possibly affect the routing, so we leave things here in case we need to change it.
 * That way downstream logic stays the same.
 *
 * Preadding is done in slice logic as a carry-save adder since we're ultimately trying
 * to add 4 things together. In fact, the carry-save addition is just flat out better:
 * you can generate a 6-bit add in 3 LUT6s. There's a second level of logic needed,
 * but a 6-bit straight add needs a carry chain, so the route cost isn't significant.
 * So we add 4 things together in 6 LUT6s, or 1.5 slices, as opposed to the 3 slices
 * needed in the carry-propagate adder design.
 */
module partition_and_preadd_v8(
		clk,
		IN,
		CARRYIN,
		STAGE1A, STAGE1B,
		STAGE2A, STAGE2B,
		STAGE3A, STAGE3B,
		STAGE4A, STAGE4B,
		STAGE5A, STAGE5B,
		STAGE6A, STAGE6B
    );

	parameter DEMUX = 16;
	parameter INBITS = 3;
	parameter DSPBITS = 12;
	localparam NINBITS = DEMUX*INBITS;
	
	input clk;
	input [NINBITS-1:0] IN;
	input [3:0] CARRYIN;
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
	
	//% Carry-save sums
	wire [INBITS-1:0] csa_sum[3:0];
	//% Carry-save carries
	wire [INBITS-1:0] csa_carry[3:0];	

    //% Carry-save add 8+9+10+11, and also stick in the carry bit into the available slot in the cascaded adder.
    carry_save_adder #(.NBITS(INBITS)) csa0(.X(input_vector[8]),.Y(input_vector[9]),.Z(input_vector[10]), .S(csa_sum[0]),.C(csa_carry[0]));
    //% 2-stage carry-save adder adds the carry from the previous stage, shifted up by 1 bit. Top bit falls through to the sum.
    carry_save_adder #(.NBITS(INBITS)) csa1(.X({csa_carry[0][0 +: INBITS-1],CARRYIN[0]}),.Y(csa_sum[0]),.Z(input_vector[11]),.S(csa_sum[1]),.C(csa_carry[1]));
    //% Carry-save add 12+13+14+15, and also stick in the carry bit into the available slot in the cascaded adder.
    carry_save_adder #(.NBITS(INBITS)) csa2(.X(input_vector[12]),.Y(input_vector[13]),.Z(input_vector[14]),.S(csa_sum[2]),.C(csa_carry[2]));
    //% 2-stage carry-save adder adds the carry from the previous stage, shifted up by 1 bit. Top bit falls through to the sum.
    carry_save_adder #(.NBITS(INBITS)) csa3(.X({csa_carry[2][0 +: INBITS-1],CARRYIN[2]}),.Y(csa_sum[2]),.Z(input_vector[15]),.S(csa_sum[3]),.C(csa_carry[3]));
    
    //% Preadd carry-save outputs for 0: sum
	reg [INBITS:0] sum_0 = {INBITS+1{1'b0}};
	//% Preadd carry-save outputs for 0: carry
	reg [INBITS:0] carry_0 = {INBITS+1{1'b0}};
	//% Preadd carry-save outputs for 1: sum
	reg [INBITS:0] sum_1 = {INBITS+1{1'b0}};
	//% Preadd carry-save outputs for 1: carry
	reg [INBITS:0] carry_1 = {INBITS+1{1'b0}};
	
	always @(posedge clk) begin
        sum_0 <= { csa_carry[0][INBITS-1], csa_sum[1] };
        carry_0 <= { csa_carry[1], CARRYIN[1] };
        
        sum_1 <= { csa_carry[2][INBITS-1], csa_sum[3] };
        carry_1 <= { csa_carry[3], CARRYIN[3] };
	end
	
	// Stage5 outputs.
	assign STAGE5A = {{DSPBITS-INBITS+1{1'b0}},sum_0};
	assign STAGE5B = {{DSPBITS-INBITS+1{1'b0}},carry_0};
	// Stage6 outputs.
	assign STAGE6A = {{DSPBITS-INBITS+1{1'b0}},sum_1};
	assign STAGE6B = {{DSPBITS-INBITS+1{1'b0}},carry_1};

endmodule
