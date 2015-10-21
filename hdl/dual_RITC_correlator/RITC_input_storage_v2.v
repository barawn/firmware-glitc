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

// Takes the RITC input data, stores it, and outputs it as a much larger time series.
// Syncs are expanded too.
module RITC_input_storage_v2(
			clk_i,
			sync_i,
			A_i, B_i, C_i,
			AS_o, BS_o, CS_o,
			Async_o, Bsync_o, Csync_o
    );

	parameter DEMUX = 16;
	parameter NBITS = 48;
	parameter A_STAGES = 0;
	parameter B_STAGES = 2;
	parameter C_STAGES = 3;
	
	input clk_i;
	input sync_i;
	input [NBITS-1:0] A_i;
	input [NBITS-1:0] B_i;
	input [NBITS-1:0] C_i;
	output [NBITS*(A_STAGES+1)-1:0] AS_o;
	output [NBITS*(B_STAGES+1)-1:0] BS_o;
	output [NBITS*(C_STAGES+1)-1:0] CS_o;
	output [DEMUX*(A_STAGES+1)-1:0] Async_o;
	output [DEMUX*(B_STAGES+1)-1:0] Bsync_o;
	output [DEMUX*(C_STAGES+1)-1:0] Csync_o;

	localparam MAX_STAGES = (C_STAGES > B_STAGES) ? ((C_STAGES > A_STAGES) ? C_STAGES : A_STAGES) :
																	((B_STAGES > A_STAGES) ? B_STAGES : A_STAGES);
	assign Async_o[0 +: DEMUX] = {DEMUX{sync_i}};
	assign Bsync_o[0 +: DEMUX] = {DEMUX{sync_i}};
	assign Csync_o[0 +: DEMUX] = {DEMUX{sync_i}};
	
	wire [MAX_STAGES:0] sync_in;
	assign sync_in[0] = sync_i;
	
	generate
		genvar i;
		for (i=0;i<MAX_STAGES;i=i+1) begin : LOOP
			reg sync_reg = 1'b0;
			always @(posedge clk_i) begin : SYNC_STORE
				sync_reg <= sync_in[i];
			end
			if (i < A_STAGES) begin : A_SYNC
				assign Async_o[DEMUX*(i+1) +: DEMUX] = {DEMUX{sync_reg}};
			end
			if (i < B_STAGES) begin : B_SYNC
				assign Bsync_o[DEMUX*(i+1) +: DEMUX] = {DEMUX{sync_reg}};
			end
			if (i < C_STAGES) begin : C_SYNC
				assign Csync_o[DEMUX*(i+1) +: DEMUX] = {DEMUX{sync_reg}};
			end
			assign sync_in[i+1] = sync_reg;
		end
	endgenerate
	
	RITC_input_channel_storage #(.NBITS(NBITS),.STAGES(A_STAGES))
			u_storeA(.clk_i(clk_i),.in_i(A_i),.out_o(AS_o));
	RITC_input_channel_storage #(.NBITS(NBITS),.STAGES(B_STAGES))
			u_storeB(.clk_i(clk_i),.in_i(B_i),.out_o(BS_o));
	RITC_input_channel_storage #(.NBITS(NBITS),.STAGES(C_STAGES))
			u_storeC(.clk_i(clk_i),.in_i(C_i),.out_o(CS_o));
	

endmodule
