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
(* SHREG_EXTRACT = "NO" *) 
module RITC_dual_idelay(
		input [11:0] CH0, input [11:0] CH0_B,
		input [11:0] CH1, input [11:0] CH1_B,
		input [11:0] CH2, input [11:0] CH2_B,
		input [11:0] CH3, input [11:0] CH3_B,
		input [11:0] CH4, input [11:0] CH4_B,
		input [11:0] CH5, input [11:0] CH5_B,
		output [11:0] CH0_D, output [11:0] CH0_B_D,
		output [11:0] CH1_D, output [11:0] CH1_B_D,
		output [11:0] CH2_D, output [11:0] CH2_B_D,
		output [11:0] CH3_D, output [11:0] CH3_B_D,
		output [11:0] CH4_D, output [11:0] CH4_B_D,
		output [11:0] CH5_D, output [11:0] CH5_B_D,
		input [5:0] CLK,
		output [5:0] CLK_D,
		input CLK200,
		input IDELAY_CLK,
		input IDELAY_PS_CLK,
		
		input user_clk_i,
		input user_sel_i,
		input user_wr_i,
		input user_addr_i,
		input [31:0] user_dat_i,
		input [31:0] user_dat_o
    );

	parameter [12:0] CH0_POLARITY = 13'h0000;
	parameter [12:0] CH1_POLARITY = 13'h0000;
	parameter [12:0] CH2_POLARITY = 13'h1FFF;
	parameter [12:0] CH3_POLARITY = 13'h0000;
	parameter [12:0] CH4_POLARITY = 13'h0000;
	parameter [12:0] CH5_POLARITY = 13'h1FFF;
	parameter [6*13-1:0] CH_POLARITY = {CH5_POLARITY,CH4_POLARITY,CH3_POLARITY,CH2_POLARITY,CH1_POLARITY,CH0_POLARITY};

	reg delayctrl_reset = 0;
	reg [4:0] delay_in = {5{1'b0}};
	reg [4:0] delay_in_2 = {5{1'b0}};
	reg [11:0] delay_load[5:0];
	reg [11:0] delay_load_2[5:0];
	reg [5:0] clock_delay_load = {6{1'b0}};
	reg [5:0] clock_delay_load_2 = {6{1'b0}};
	wire [11:0] CH[5:0]; 	
	wire [11:0] CH_B[5:0];
	wire [11:0] CH_D[5:0];
	wire [11:0] CH_B_D[5:0];
	assign CH[0] = CH0; assign CH_B[0] = CH0_B;
	assign CH[1] = CH1; assign CH_B[1] = CH1_B;
	assign CH[2] = CH2; assign CH_B[2] = CH2_B;
	assign CH[3] = CH3; assign CH_B[3] = CH3_B;
	assign CH[4] = CH4; assign CH_B[4] = CH4_B;
	assign CH[5] = CH5; assign CH_B[5] = CH5_B;
	assign CH0_D = CH_D[0]; assign CH0_B_D = CH_B_D[0];
	assign CH1_D = CH_D[1]; assign CH1_B_D = CH_B_D[1];
	assign CH2_D = CH_D[2]; assign CH2_B_D = CH_B_D[2];
	assign CH3_D = CH_D[3]; assign CH3_B_D = CH_B_D[3];
	assign CH4_D = CH_D[4]; assign CH4_B_D = CH_B_D[4];
	assign CH5_D = CH_D[5]; assign CH5_B_D = CH_B_D[5];
	
	always @(posedge user_clk_i) begin
		if (user_sel_i && user_wr_i && !user_addr_i) delay_in <= user_dat_i[4:0];

		if (user_sel_i && user_wr_i && user_addr_i) delayctrl_reset <= user_dat_i[0];
		else delayctrl_reset <= 0;
	end
	
	IDELAYCTRL u_idelayctrl(.REFCLK(CLK200),.RST(delayctrl_reset));
	
	generate
		genvar i,j;
		for (i=0;i<6;i=i+1) begin : CHL
			for (j=0;j<12;j=j+1) begin : BTL
				initial begin : INIT
					delay_load[i][j] <= 0;
					delay_load_2[i][j] <= 0;
				end
				always @(posedge user_clk_i) begin : LOAD
					if (user_sel_i && user_wr_i && !user_addr_i && (user_dat_i[5 +: 4] == j) && (user_dat_i[9 +: 3] == i))
						delay_load[i][j] <= 1;
					else
						delay_load[i][j] <= 0;
					delay_load_2[i][j] <= delay_load[i][j];
				end
				RITC_idelay_pair #(.POL(CH_POLARITY[i*13+j])) u_idelay_pair(.IN(CH[i][j]),.IN_B(CH_B[i][j]),
																							 .delay_i(delay_in),
																							 .load_i(delay_load_2[i][j]),
																							 .clk_i(IDELAY_CLK),
																							 .clk_b_i(IDELAY_PS_CLK),
																							 .O1(CH_D[i][j]),.O2(CH_B_D[i][j]));
			end
			// There is no duplicate path for the clocks. The primary path is used for reference counting.
			// The secondary path is used for phase locking.
			wire clk_polarity_sel = CH_POLARITY[i*13+12] ^ CLK[i];
			always @(posedge user_clk_i) begin : CLKLOAD
				if (user_sel_i && user_wr_i && !user_addr_i && (user_dat_i[5 +: 4] == 4'hF) && (user_dat_i[9 +: 3] == i))
					clock_delay_load[i] <= 1;
				else
					clock_delay_load[i] <= 0;
				clock_delay_load_2[i] <= clock_delay_load[i];
			end
			IDELAYE2 #(.IDELAY_TYPE("VAR_LOAD"),
						  .DELAY_SRC("IDATAIN"),
						  .IDELAY_VALUE(0),
						  .HIGH_PERFORMANCE_MODE("FALSE"),
						  .SIGNAL_PATTERN("DATA")) u_clock_path(.IDATAIN(clk_polarity_sel),
																			 .DATAIN(1'b0),
																			 .DATAOUT(CLK_D[i]),
																			 .CNTVALUEIN(delay_in),
																			 .LD(clock_delay_load_2[i]),
																			 .C(IDELAY_PS_CLK),
																			 .CINVCTRL(1'b0),.CE(1'b0),.INC(1'b0));
		end
	endgenerate
	
endmodule
