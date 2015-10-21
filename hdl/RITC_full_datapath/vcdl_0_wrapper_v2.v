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
module vcdl_0_wrapper_v2(
		input vcdl_i,
		input vcdl_clk_i,

		input ctrl_i,
		input ctrl_clk_i,
		input sysclk_i,
		
		input vcdl_fb_clk_i,
		output vcdl_fb_q_o,
		
		output VCDL
    );
    
    parameter USE_HARD_MACRO = "NO";
    
	wire [4:0] idelay_value;
	wire idelay_load;
	wire iserdes_bitslip;
	// Bit controller. This limits the number of control signals that go to each bit to just 1.
	// Hopefully should free up HLONGs for other stuff.
	RITC_bit_control #(.USE_BITSLIP_FOR_LOADING("TRUE")) u_ctrl(.sysclk_i(sysclk_i),.ctrl_clk_i(ctrl_clk_i),.ctrl_i(ctrl_i),
									.channel_i(3'd0),
									.bit_i(4'd14),
									.delay_o(idelay_value),
									.load_o(idelay_load),
									.bitslip_o(iserdes_bitslip));
    generate
        if (USE_HARD_MACRO == "NO") begin : SOFT
            // The hard macro consists of:
            // an FD which generates the actual VCDL output
            // which goes to
            // IDELAY receiving the input in fabric
            // IDELAY output is passed to an IFD which captures the output
            // IDELAY output also then passes over to OLOGIC to head out
            //
            // Personal belief as to the chance that this will work: ZERO
            wire vcdl_from_ff_to_idelay;
            wire vcdl_from_idelay_to_ilogic;
            (* LOC = "SLICE_X1Y99" *)
            (* BEL = "AFF" *)
            FD u_vcdl0(.D(vcdl_i),.C(vcdl_clk_i),.Q(vcdl_from_ff_to_idelay));
            (* LOC = "IDELAY_X0Y99" *)
            IDELAYE2 #(.DELAY_SRC("DATAIN"),.IDELAY_TYPE("VAR_LOAD")) 
                u_vcdl_idelay(.DATAIN(vcdl_from_ff_to_idelay),
                              .CNTVALUEIN(idelay_value),
                              .LD(idelay_load),
                              .C(sysclk_i),
                              .DATAOUT(vcdl_from_idelay_to_ilogic));
            (* LOC = "ILOGIC_X0Y99" *)
            FD u_vcdl1(.D(vcdl_from_idelay_to_ilogic),.C(vcdl_fb_clk_i),.Q(vcdl_fb_q_o));
            
            assign VCDL = vcdl_from_idelay_to_ilogic;
        end else begin : HARD
            vcdl_0_delayable u_vcdl0( .L_VCDL_D(vcdl_i),
                                              .L_VCDL_CLK(vcdl_clk_i),
                                              .L_VCDL_O(VCDL),
                                              
                                              .L_VCDL_FB_CLK(vcdl_fb_clk_i),
                                              .L_VCDL_FB_Q(vcdl_fb_q_o),
                                              
                                              .L_VCDL_LD(idelay_load),
                                              .L_VCDL_DELAY0(idelay_value[0]),
                                              .L_VCDL_DELAY1(idelay_value[1]),
                                              .L_VCDL_DELAY2(idelay_value[2]),
                                              .L_VCDL_DELAY3(idelay_value[3]),
                                              .L_VCDL_DELAY4(idelay_value[4]),
                                              .L_VCDL_DELAY_CE(idelay_load),
                                              .L_VCDL_DELAY_CLK(sysclk_i),
                                              
                                              .L_VCDL_INC(1'b0),
                                              .L_VCDL_REGRST(1'b0),
                                              .L_VCDL_LDPIPEEN(1'b0));
        end
    endgenerate
endmodule
