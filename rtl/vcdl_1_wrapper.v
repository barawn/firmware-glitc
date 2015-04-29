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
module vcdl_1_wrapper(
		input vcdl_i,
		input vcdl_clk_i,

		input [4:0] delay_i,
		input delay_ld_i,
		input delay_clk_i,
		
		input vcdl_fb_clk_i,
		output vcdl_fb_q_o,
		
		output VCDL
    );

	vcdl_1_delayable u_vcdl1( .R_VCDL_D(vcdl_i),
									  .R_VCDL_CLK(vcdl_clk_i),
									  .R_VCDL_O(VCDL),
									  
									  .R_VCDL_FB_CLK(vcdl_fb_clk_i),
									  .R_VCDL_FB_Q(vcdl_fb_q_o),
									  
									  .R_VCDL_LD(delay_ld_i),
									  .R_VCDL_DELAY0(delay_i[0]),
									  .R_VCDL_DELAY1(delay_i[1]),
									  .R_VCDL_DELAY2(delay_i[2]),
									  .R_VCDL_DELAY3(delay_i[3]),
									  .R_VCDL_DELAY4(delay_i[4]),
									  .R_VCDL_DELAY_CE(delay_ld_i),
									  .R_VCDL_DELAY_CLK(delay_clk_i),
									  
									  .R_VCDL_INC(1'b0),
									  .R_VCDL_REGRST(1'b0),
									  .R_VCDL_LDPIPEEN(1'b0));

endmodule

module vcdl_1_delayable( input R_VCDL_D,
								 input R_VCDL_CLK,
								 output R_VCDL_O,
								 input R_VCDL_FB_CLK,
								 output R_VCDL_FB_Q,
								 input R_VCDL_LD,
								 input R_VCDL_DELAY0,
								 input R_VCDL_DELAY1,
								 input R_VCDL_DELAY2,
								 input R_VCDL_DELAY3,
								 input R_VCDL_DELAY4,
								 input R_VCDL_DELAY_CE,
								 input R_VCDL_DELAY_CLK,
								 input R_VCDL_INC,
								 input R_VCDL_REGRST,
								 input R_VCDL_LDPIPEEN);

endmodule
