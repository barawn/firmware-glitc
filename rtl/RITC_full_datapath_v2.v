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
module RITC_full_datapath_v2(
		input [5:0] REFCLK_P,
		input [5:0] REFCLK_N,
		input [11:0] CH0_P, input [11:0] CH0_N,
		input [11:0] CH1_P, input [11:0] CH1_N,
		input [11:0] CH2_P, input [11:0] CH2_N,
		input [11:0] CH3_P, input [11:0] CH3_N,
		input [11:0] CH4_P, input [11:0] CH4_N,
		input [11:0] CH5_P, input [11:0] CH5_N,
		input DATACLK,
		input DATACLK_DIV2,
		input SYSCLK,
		input SYSCLK_DIV2_PS,
		input CLK200,
		
		// Deserialized outputs.
		output [47:0] CH0_OUT,
		output [47:0] CH1_OUT,
		output [47:0] CH2_OUT,
		output [47:0] CH3_OUT,
		output [47:0] CH4_OUT,
		output [47:0] CH5_OUT,
		// Single bit clocked output.
		output [11:0] CH0_BYPASS,
		output [11:0] CH1_BYPASS,
		output [11:0] CH2_BYPASS,
		output [11:0] CH3_BYPASS,
		output [11:0] CH4_BYPASS,
		output [11:0] CH5_BYPASS,
		output [5:0] REFCLK_BYPASS,
		// Sync input
		input SYNC,
		// VCDL outputs
		output [1:0] VCDL,
		// Training outputs
		output [1:0] TRAIN_ON,
		
		input user_clk_i,
		input user_sel_i,
		input [3:0] user_addr_i,
		input user_wr_i,
		input user_rd_i,
		input [31:0] user_dat_i,
		output [31:0] user_dat_o,
		
		output [11:0] debug_o
    );

	// Datapath register map:
	// 0x00: Datapath Reset/Enable register.
	// 0x01: Bitslip control register.
	// 0x02: IDELAY value register.
	// 0x03: IDELAY control register.

	//< RITC data input, out of input buffers.
	wire [11:0] R_DAT_I[1:0][2:0];
	//< RITC bypass data inputs, out of input buffers.
	wire [11:0] R_BYP[1:0][2:0];
	wire [5:0] R_CLK;
	wire [5:0] R_CLK_BYP;
	
	reg datapath_disable = 1;
	reg datapath_reset = 0;
	wire sel_idelay = user_addr_i[1];
	wire sel_datapath = user_addr_i[1:0] == 2'b01;
	always @(posedge user_clk_i) begin
		if (user_wr_i && (user_addr_i[1:0] == 2'b00) && user_sel_i) datapath_disable <= user_dat_i[0];
		if (user_wr_i && (user_addr_i[1:0] == 2'b00) && user_sel_i) datapath_reset <= user_dat_i[1];
		else datapath_reset <= 0;
	end
	
	// Input buffers for RITC signals.
	RITC_dual_input_buffers u_inputs_R0(.disable_i(datapath_disable),
													.CH0_P(CH0_P),.CH0_N(CH0_N),
													.CH1_P(CH1_P),.CH1_N(CH1_N),
													.CH2_P(CH2_P),.CH2_N(CH2_N),
													.CH0(R_DAT_I[0][0]),.CH0_B(R_BYP[0][0]),
													.CH1(R_DAT_I[0][1]),.CH1_B(R_BYP[0][1]),
													.CH2(R_DAT_I[0][2]),.CH2_B(R_BYP[0][2]),
													.CLK_P(REFCLK_P[2:0]),.CLK_N(REFCLK_N[2:0]),
													.CLK(R_CLK[2:0]),.CLK_B(R_CLK_BYP[2:0]));
	RITC_dual_input_buffers u_inputs_R1(.disable_i(datapath_disable),
													.CH0_P(CH3_P),.CH0_N(CH3_N),
													.CH1_P(CH4_P),.CH1_N(CH4_N),
													.CH2_P(CH5_P),.CH2_N(CH5_N),
													.CH0(R_DAT_I[1][0]),.CH0_B(R_BYP[1][0]),
													.CH1(R_DAT_I[1][1]),.CH1_B(R_BYP[1][1]),
													.CH2(R_DAT_I[1][2]),.CH2_B(R_BYP[1][2]),
													.CLK_P(REFCLK_P[5:3]),.CLK_N(REFCLK_N[5:3]),
													.CLK(R_CLK[5:3]),.CLK_B(R_CLK_BYP[5:3]));
	// The datapath - both IDELAY and ISERDES control - are now
	// located in a single module, feeding a hard macro which forces everything into the
	// same ILOGIC pair.
	RITC_dual_datapath_v2 u_datapath(
												// Clocks. This module takes them all.
												.SYSCLK(SYSCLK),
												.DATACLK(DATACLK),
												.DATACLK_DIV2(DATACLK_DIV2),
												.SYSCLK_DIV2_PS(SYSCLK_DIV2_PS),
												.CLK200(CLK200),
												// Sync input, training and VCDL outputs.
												.SYNC(SYNC),
												.TRAIN_ON(TRAIN_ON),
												.VCDL(VCDL),
												// Data and duplicate.
												.CH0(R_DAT_I[0][0]),
												.CH1(R_DAT_I[0][1]),
												.CH2(R_DAT_I[0][2]),
												.CH3(R_DAT_I[1][0]),
												.CH4(R_DAT_I[1][1]),
												.CH5(R_DAT_I[1][2]),
												.CH0_B(R_BYP[0][0]),
												.CH1_B(R_BYP[0][1]),
												.CH2_B(R_BYP[0][2]),
												.CH3_B(R_BYP[1][0]),
												.CH4_B(R_BYP[1][1]),
												.CH5_B(R_BYP[1][2]),
												// Clock and duplicate inputs.
												.CLK(R_CLK),												
												.CLK_B(R_CLK_BYP),
												// Latched clock duplicate output.
												.CLK_B_Q(REFCLK_BYPASS),
												// Deserialized output data.
												.CH0_OUT(CH0_OUT),
												.CH1_OUT(CH1_OUT),
												.CH2_OUT(CH2_OUT),
												.CH3_OUT(CH3_OUT),
												.CH4_OUT(CH4_OUT),
												.CH5_OUT(CH5_OUT),
												// Duplicate, clocked outputs.
												.CH0_Q(CH0_BYPASS),
												.CH1_Q(CH1_BYPASS),
												.CH2_Q(CH2_BYPASS),
												.CH3_Q(CH3_BYPASS),
												.CH4_Q(CH4_BYPASS),
												.CH5_Q(CH5_BYPASS),
												// Interface (both IDELAY and datapath)
												.rst_i(datapath_reset),
												.user_clk_i(user_clk_i),
												.user_sel_i(user_sel_i),
												.user_addr_i(user_addr_i),
												.user_wr_i(user_wr_i),
												.user_dat_i(user_dat_i),
												.user_dat_o(user_dat_o));
		assign debug_o = CH0_BYPASS;
	
endmodule
