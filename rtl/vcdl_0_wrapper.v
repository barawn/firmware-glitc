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
module vcdl_0_wrapper(
		input vcdl_i,
		input vcdl_clk_i,

		input [4:0] delay_i,
		input delay_ld_i,
		input delay_clk_i,
		
		input vcdl_fb_clk_i,
		output vcdl_fb_q_o,
		
		output VCDL
    );

	vcdl_0_delayable u_vcdl0( .L_VCDL_D(vcdl_i),
									  .L_VCDL_CLK(vcdl_clk_i),
									  .L_VCDL_O(VCDL),
									  
									  .L_VCDL_FB_CLK(vcdl_fb_clk_i),
									  .L_VCDL_FB_Q(vcdl_fb_q_o),
									  
									  .L_VCDL_LD(delay_ld_i),
									  .L_VCDL_DELAY0(delay_i[0]),
									  .L_VCDL_DELAY1(delay_i[1]),
									  .L_VCDL_DELAY2(delay_i[2]),
									  .L_VCDL_DELAY3(delay_i[3]),
									  .L_VCDL_DELAY4(delay_i[4]),
									  .L_VCDL_DELAY_CE(delay_ld_i),
									  .L_VCDL_DELAY_CLK(delay_clk_i),
									  
									  .L_VCDL_INC(1'b0),
									  .L_VCDL_REGRST(1'b0),
									  .L_VCDL_LDPIPEEN(1'b0));

endmodule

module vcdl_0_delayable( input L_VCDL_D,
								 input L_VCDL_CLK,
								 output L_VCDL_O,
								 input L_VCDL_FB_CLK,
								 output L_VCDL_FB_Q,
								 input L_VCDL_LD,
								 input L_VCDL_DELAY0,
								 input L_VCDL_DELAY1,
								 input L_VCDL_DELAY2,
								 input L_VCDL_DELAY3,
								 input L_VCDL_DELAY4,
								 input L_VCDL_DELAY_CE,
								 input L_VCDL_DELAY_CLK,
								 input L_VCDL_INC,
								 input L_VCDL_REGRST,
								 input L_VCDL_LDPIPEEN);

endmodule
