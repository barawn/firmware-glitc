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
module dual_RITC_correlator_v1(
		input sysclk_i,
		input sync_i,
		input [47:0] A,
		input [47:0] B,
		input [47:0] C,
		input [47:0] D,
		input [47:0] E,
		input [47:0] F,
		output [11:0] R0_MAX,
		output [11:0] R1_MAX,
		
		input user_clk_i,
		input user_sel_i,
		input user_wr_i,
		input user_rd_i,
		input [10:0] user_addr_i,
		input [31:0] user_dat_i,
		output [31:0] user_dat_o,
		input sample_sel_i,
		output [31:0] sample_dat_o,
		
		output[31:0] debug_o
    );

	wire [11:0] corr_R0;
	wire [11:0] corr_R1;
	single_corr_v6 u_corr_R0(.clk(SYSCLK),.A(A),.B(B),.C(C),.CORR(corr_R0));
	single_corr_v6 u_corr_R1(.clk(SYSCLK),.A(D),.B(E),.C(F),.CORR(corr_R1));
	assign debug_o[0 +: 12] = corr_R0;
	assign debug_o[12 +: 12] = corr_R1;	

	// Moron buffer storage. There's no pretrigger anything here: nothing smart, nothing intelligent, nothing.
	// Implementing a pretrigger is the next step.
	
	wire [47:0] sample_out_R0;
	wire [47:0] sample_out_R1;
	
	// We have 96 output bits, or 3 32-bit words.
	// Data is read out in chunks:
	// sample_out_R0[31:0] from 0-511
	// sample_out_R0/R1 from 512-1023
	// sample_out_R1 from 1024-1535
	// sample_out_R1/R0 from 1536-2047
	wire [31:0] STORCTRL;
	reg storage_trigger = 0;
	wire storage_done;
	reg storage_clear = 0;
	wire storage_sync_latch;
	always @(posedge user_clk_i) begin
		if (user_sel_i && user_wr_i) begin
			storage_trigger <= user_dat_i[0];
			storage_clear <= user_dat_i[2];
		end else begin
			storage_trigger <= 0;
			storage_clear <= 0;
		end
	end
	assign STORCTRL = {{28{1'b0}},storage_sync_latch,1'b0,storage_done,1'b0};
	
	assign user_dat_o = STORCTRL;
	
	RITC_sample_storage u_storage(.A(A),.B(B),.C(C),.D(D),.E(E),.F(F),.sysclk_i(sysclk_i),.sync_i(sync_i),
											.trig_i(storage_trigger),
											.clear_i(storage_clear),
											.done_o(storage_done),
											.sync_latch_o(storage_sync_latch),
											.user_clk_i(user_clk_i),
											.user_addr_i(user_addr_i),
											.user_sel_i(sample_sel_i),
											.user_rd_i(user_rd_i),
											.user_wr_i(user_wr_i),
											.user_dat_o(sample_dat_o));
	
endmodule
