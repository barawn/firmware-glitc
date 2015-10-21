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

//% RITC VCDL generation module.
module RITC_vcdl(
		input sysclk_i,
		input user_clk_i,
		input clk_ps_i,
		input sync_i,
		input vcdl_enable_i,
		input vcdl_pulse_i,
		
		input ctrl_i,
		
		output vcdl_ps_q,
		output VCDL
    );

	parameter SIDE = "LEFT";
    parameter USE_HARD_MACRO = "NO";
    
	wire vcdl_pulse_sysclk;
	reg vcdl_pulse_seen = 0;
	reg [1:0] vcdl_enable_sysclk = {2{1'b0}};
	
	always @(posedge sysclk_i) begin
		if (vcdl_pulse_sysclk) vcdl_pulse_seen <= 1;
		else if (sync_i) vcdl_pulse_seen <= 0;
	
		vcdl_enable_sysclk <= {vcdl_enable_sysclk[0],vcdl_enable_i};
	end
	
	//< Flag synchronizer (user_clk -> SYSCLK) for the VCDL pulse requeset for R0.
	flag_sync u_vcdl_pulse_sync(.in_clkA(vcdl_pulse_i),.clkA(user_clk_i),
										 .out_clkB(vcdl_pulse_sysclk), .clkB(sysclk_i));
	generate
		if (SIDE == "LEFT") begin : LEFT
            vcdl_0_wrapper_v2 #(.USE_HARD_MACRO(USE_HARD_MACRO)) u_vcdl0( 
                                            .vcdl_i( sync_i & (vcdl_enable_sysclk[1] || vcdl_pulse_seen )),
                                            .vcdl_clk_i(sysclk_i),
                                            
                                            .ctrl_i(ctrl_i),
                                            .ctrl_clk_i(user_clk_i),
                                            .sysclk_i(user_clk_i),
                                            
                                            .vcdl_fb_clk_i(clk_ps_i),
                                            .vcdl_fb_q_o(vcdl_ps_q),
                                            
                                            .VCDL(VCDL));	
        end else begin : RIGHT
			vcdl_1_wrapper_v2 #(.USE_HARD_MACRO(USE_HARD_MACRO)) u_vcdl1( 
											.vcdl_i( sync_i & (vcdl_enable_sysclk[1] || vcdl_pulse_seen )),
											.vcdl_clk_i(sysclk_i),
											
											.ctrl_i(ctrl_i),
											.ctrl_clk_i(user_clk_i),
											.sysclk_i(user_clk_i),
											
											.vcdl_fb_clk_i(clk_ps_i),
											.vcdl_fb_q_o(vcdl_ps_q),
											
											.VCDL(VCDL));			
		end
	endgenerate
endmodule
