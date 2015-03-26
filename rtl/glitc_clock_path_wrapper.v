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

//% Wrapper for the GLITC clock path hard macro. Crosses clock domain and adds BUFR.
module glitc_clock_path_wrapper(
		input SYSCLK_DIV2_PS,
		
		input	IN_P,
		input IN_N,

		input clk_i,
		input [4:0] delay_clk_i,
		input load_clk_i,
		
		output p_bufr_o,
		output p_q_o,
		output n_q_o
		);

	wire ilogic_to_bufr;
	wire load_SYSCLK_DIV2_PS;
	flag_sync u_load_n(.in_clkA(load_clk_i),.clkA(clk_i),
							 .out_clkB(load_SYSCLK_DIV2_PS),.clkB(SYSCLK_DIV2_PS));
	glitc_clock_path u_clock_path( .IN_P(IN_P), .IN_N(IN_N),
											 .P_O(ilogic_to_bufr),
											 .P_Q(p_q_o),
											 .P_CLK(clk_i),
											 .N_Q(n_q_o),
											 .N_CLK(SYSCLK_DIV2_PS),
											 .N_REGRST(1'b0),
											 .N_LDPIPEEN(1'b0),
											 .N_INC(1'b0),
											 .N_LD(load_SYSCLK_DIV2_PS),
											 .N_CE(load_SYSCLK_DIV2_PS),
											 .IDELAY_N_CLK(SYSCLK_DIV2_PS),
											 .N_D0(delay_clk_i[0]),
											 .N_D1(delay_clk_i[1]),
											 .N_D2(delay_clk_i[2]),
											 .N_D3(delay_clk_i[3]),
											 .N_D4(delay_clk_i[4]));
	  BUFR u_bufr(.I(ilogic_to_bufr),.O(p_bufr_o));
											 
endmodule

module glitc_clock_path(
		input	IN_P,
		input IN_N,
		output P_O,

		output P_Q,
		input P_CLK,		

		output N_Q,
		input N_CLK,
		
		input N_REGRST,
		input N_LDPIPEEN,
		input N_LD,
		input N_INC,
		input N_D0,
		input N_D1,
		input N_D2,
		input N_D3,
		input N_D4,
		input N_CE,
		input IDELAY_N_CLK
    );
endmodule
