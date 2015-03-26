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

module RITC_idelay_pair(
		input IN, input IN_B,
		input [4:0] delay_i,
		input clk_i,
		input clk_b_i,
		input load_i,
		output O1, output O2   
	);

	parameter POL = 0;
	generate
		if (POL == 0) begin : NINV
			glitc_idelay_in u_in(.P_IN(IN),.N_IN(IN_B),
										.P_REGRST(1'b0),.N_REGRST(1'b0),
										.P_LDPIPEEN(1'b0),.N_LDPIPEEN(1'b0),
										.P_INC(1'b0),.N_INC(1'b0),
										.P_D0(delay_i[0]),
										.P_D1(delay_i[1]),
										.P_D2(delay_i[2]),
										.P_D3(delay_i[3]),
										.P_D4(delay_i[4]),
										.N_D0(delay_i[0]),
										.N_D1(delay_i[1]),
										.N_D2(delay_i[2]),
										.N_D3(delay_i[3]),
										.N_D4(delay_i[4]),
										.P_CE(1'b0),
										.N_CE(1'b0),
										.P_C(clk_i),
										.N_C(clk_b_i),
										.P_LD(load_i),
										.N_LD(load_i),
										.P_OUT(O1),
										.N_OUT(O2));
		end else begin : INV
			glitc_idelay_in_n u_in(.P_IN(IN),.N_IN(IN_B),
										.P_REGRST(1'b0),.N_REGRST(1'b0),
										.P_LDPIPEEN(1'b0),.N_LDPIPEEN(1'b0),
										.P_INC(1'b0),.N_INC(1'b0),
										.P_D0(delay_i[0]),
										.P_D1(delay_i[1]),
										.P_D2(delay_i[2]),
										.P_D3(delay_i[3]),
										.P_D4(delay_i[4]),
										.N_D0(delay_i[0]),
										.N_D1(delay_i[1]),
										.N_D2(delay_i[2]),
										.N_D3(delay_i[3]),
										.N_D4(delay_i[4]),
										.P_CE(1'b0),
										.N_CE(1'b0),
										.P_C(clk_i),
										.N_C(clk_b_i),
										.P_LD(load_i),
										.N_LD(load_i),
										.P_OUT(O1),
										.N_OUT(O2));
		end
	endgenerate

endmodule

module glitc_idelay_in( input P_IN, input N_IN,
								input P_REGRST, input N_REGRST,
								input P_LDPIPEEN, input N_LDPIPEEN,
								input P_INC, input N_INC,
								input P_D0, input N_D0,
								input P_D1, input N_D1,
								input P_D2, input N_D2,
								input P_D3, input N_D3,
								input P_D4, input N_D4,
								output P_OUT, output N_OUT,
								input P_CE, input N_CE,
								input P_C, input N_C,
								input P_LD, input N_LD );
endmodule

module glitc_idelay_in_n( input P_IN, input N_IN,
								input P_REGRST, input N_REGRST,
								input P_LDPIPEEN, input N_LDPIPEEN,
								input P_INC, input N_INC,
								input P_D0, input N_D0,
								input P_D1, input N_D1,
								input P_D2, input N_D2,
								input P_D3, input N_D3,
								input P_D4, input N_D4,
								output P_OUT, output N_OUT,
								input P_CE, input N_CE,
								input P_C, input N_C,
								input P_LD, input N_LD );
endmodule
