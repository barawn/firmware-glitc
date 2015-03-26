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
module RITC_full_datapath(
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
		
		output [47:0] CH0_OUT,
		output [47:0] CH1_OUT,
		output [47:0] CH2_OUT,
		output [47:0] CH3_OUT,
		output [47:0] CH4_OUT,
		output [47:0] CH5_OUT,
		output [11:0] CH0_BYPASS,
		output [11:0] CH1_BYPASS,
		output [11:0] CH2_BYPASS,
		output [11:0] CH3_BYPASS,
		output [11:0] CH4_BYPASS,
		output [11:0] CH5_BYPASS,
		output [5:0] REFCLK,
		output [5:0] REFCLK_BYPASS,
		
		input user_clk_i,
		input user_sel_i,
		input [3:0] user_addr_i,
		input user_wr_i,
		input user_rd_i,
		input [31:0] user_dat_i,
		output [31:0] user_dat_o,
		
		output [31:0] debug_o
    );

	// Datapath register map:
	// 0x00: Datapath Reset/Enable register.
	// 0x01: Bitslip control register.
	// 0x02: IDELAY value register.
	// 0x03: IDELAY control register.

	wire [11:0] R_DAT_I[1:0][2:0];
	wire [11:0] R_DAT_D[1:0][2:0];
	wire [11:0] R_BYP[1:0][2:0];
	wire [11:0] R_BYP_D[1:0][2:0];
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
	
	// The "_B" signals are inverted here.
	RITC_dual_input_buffers u_inputs_R0(.disable_i(datapath_disable),
													.CH0_P(CH0_P),.CH0_N(CH0_N),
													.CH1_P(CH1_P),.CH1_N(CH1_N),
													.CH2_P(CH2_P),.CH2_N(CH2_N),
													.CH0(R_DAT_I[0][0]),.CH0_B(R_BYP[0][0]),
													.CH1(R_DAT_I[0][1]),.CH1_B(R_BYP[0][1]),
													.CH2(R_DAT_I[0][2]),.CH2_B(R_BYP[0][2]),
													.CLK_P(REFCLK_P[2:0]),.CLK_N(REFCLK_N[2:0]),
													.CLK(REFCLK[2:0]),.CLK_B(R_CLK_BYP[2:0]));
	RITC_dual_input_buffers u_inputs_R1(.disable_i(datapath_disable),
													.CH0_P(CH3_P),.CH0_N(CH3_N),
													.CH1_P(CH4_P),.CH1_N(CH4_N),
													.CH2_P(CH5_P),.CH2_N(CH5_N),
													.CH0(R_DAT_I[1][0]),.CH0_B(R_BYP[1][0]),
													.CH1(R_DAT_I[1][1]),.CH1_B(R_BYP[1][1]),
													.CH2(R_DAT_I[1][2]),.CH2_B(R_BYP[1][2]),
													.CLK_P(REFCLK_P[5:3]),.CLK_N(REFCLK_N[5:3]),
													.CLK(REFCLK[5:3]),.CLK_B(R_CLK_BYP[5:3]));
	// We now put them through an identical IDELAY.
	// The "_B" signals are *no longer* inverted after here.
	RITC_dual_idelay u_dual_idelay(.CH0(R_DAT_I[0][0]), .CH0_B(R_BYP[0][0]),
											 .CH1(R_DAT_I[0][1]), .CH1_B(R_BYP[0][1]),
											 .CH2(R_DAT_I[0][2]), .CH2_B(R_BYP[0][2]),
											 .CH3(R_DAT_I[1][0]), .CH3_B(R_BYP[1][0]),
											 .CH4(R_DAT_I[1][1]), .CH4_B(R_BYP[1][1]),
											 .CH5(R_DAT_I[1][2]), .CH5_B(R_BYP[1][2]),
											 .CH0_D(R_DAT_D[0][0]), .CH0_B_D(R_BYP_D[0][0]),
											 .CH1_D(R_DAT_D[0][1]), .CH1_B_D(R_BYP_D[0][1]),
											 .CH2_D(R_DAT_D[0][2]), .CH2_B_D(R_BYP_D[0][2]),
											 .CH3_D(R_DAT_D[1][0]), .CH3_B_D(R_BYP_D[1][0]),
											 .CH4_D(R_DAT_D[1][1]), .CH4_B_D(R_BYP_D[1][1]),
											 .CH5_D(R_DAT_D[1][2]), .CH5_B_D(R_BYP_D[1][2]),
											 .CLK(R_CLK_BYP),.CLK_D(REFCLK_BYPASS),
											 .CLK200(CLK200),
											 .IDELAY_CLK(DATACLK_DIV2),
											 .IDELAY_PS_CLK(SYSCLK_DIV2_PS),
											 .user_clk_i(user_clk_i),
											 .user_sel_i(sel_idelay),
											 .user_wr_i(user_wr_i),
											 .user_addr_i(user_addr_i[0]),
											 .user_dat_i(user_dat_i),
											 .user_dat_o(user_dat_o));
	RITC_dual_datapath u_datapath(.SYSCLK(SYSCLK),
											.DATACLK(DATACLK),
											.DATACLK_DIV2(DATACLK_DIV2),
											.CH0(R_DAT_D[0][0]),
											.CH1(R_DAT_D[0][1]),
											.CH2(R_DAT_D[0][2]),
											.CH3(R_DAT_D[1][0]),
											.CH4(R_DAT_D[1][1]),
											.CH5(R_DAT_D[1][2]),
											.CH0_OUT(CH0_OUT),
											.CH1_OUT(CH1_OUT),
											.CH2_OUT(CH2_OUT),
											.CH3_OUT(CH3_OUT),
											.CH4_OUT(CH4_OUT),
											.CH5_OUT(CH5_OUT),
											.rst_i(datapath_reset),
											.user_clk_i(user_clk_i),
											.user_sel_i(sel_datapath),
											.user_wr_i(user_wr_i),
											.user_dat_i(user_dat_i),
											.user_dat_o(user_dat_o));
	assign CH0_BYPASS = R_BYP_D[0][0];
	assign CH1_BYPASS = R_BYP_D[0][1];
	assign CH2_BYPASS = R_BYP_D[0][2];
	assign CH3_BYPASS = R_BYP_D[1][0];
	assign CH4_BYPASS = R_BYP_D[1][1];
	assign CH5_BYPASS = R_BYP_D[1][2];
	
endmodule
