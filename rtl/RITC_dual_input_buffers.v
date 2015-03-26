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
module RITC_dual_input_buffers(
		input disable_i,
		input [11:0] CH0_P,
		input [11:0] CH0_N,
		input [11:0] CH1_P,
		input [11:0] CH1_N,
		input [11:0] CH2_P,
		input [11:0] CH2_N,
		output [11:0] CH0,
		output [11:0] CH0_B,
		output [11:0] CH1,
		output [11:0] CH1_B,
		output [11:0] CH2,
		output [11:0] CH2_B,
		input [2:0] CLK_P,
		input [2:0] CLK_N,
		output [2:0] CLK,
		output [2:0] CLK_B
    );

	wire [11:0] RITC_DATA[2:0];
	wire [11:0] RITC_DATA_B[2:0];
	generate
		genvar i,j;
		for (i=0;i<12;i=i+1) begin : LP
			IBUFDS_DIFF_OUT_IBUFDISABLE u_ibufds_CH0(.IBUFDISABLE(disable_i),
					.I(CH0_P[i]),.IB(CH0_N[i]),.O(RITC_DATA[0][i]),.OB(RITC_DATA_B[0][i]));			
			IBUFDS_DIFF_OUT_IBUFDISABLE u_ibufds_CH1(.IBUFDISABLE(disable_i),
					.I(CH1_P[i]),.IB(CH1_N[i]),.O(RITC_DATA[1][i]),.OB(RITC_DATA_B[1][i]));
			IBUFDS_DIFF_OUT_IBUFDISABLE u_ibufds_CH2(.IBUFDISABLE(disable_i),
					.I(CH2_P[i]),.IB(CH2_N[i]),.O(RITC_DATA[2][i]),.OB(RITC_DATA_B[2][i]));
		end
		for (j=0;j<3;j=j+1) begin : CLP
			IBUFDS_DIFF_OUT_IBUFDISABLE u_ibufds_CLK(.IBUFDISABLE(disable_i),
					.I(CLK_P[j]),.IB(CLK_N[j]),.O(CLK[j]),.OB(CLK_B[j]));
		end
	endgenerate

	assign CH0 = RITC_DATA[0];
	assign CH0_B = RITC_DATA_B[0];
	assign CH1 = RITC_DATA[1];
	assign CH1_B = RITC_DATA_B[1];
	assign CH2 = RITC_DATA[2];
	assign CH2_B = RITC_DATA_B[2];

endmodule
