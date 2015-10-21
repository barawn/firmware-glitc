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
module glitc_clock_path_wrapper_v2(
		input SYSCLK_DIV2_PS,
		
		input	IN_P,
		input IN_N,

		input clk_i,
		input ctrl_i,
		input [2:0] channel_i,
		
		output p_bufr_o,
		output p_q_o,
		output n_q_o
		);

    parameter USE_HARD_MACRO = "NO";

	wire ilogic_to_bufr;
	wire load_SYSCLK_DIV2_PS;
	wire [4:0] delay_value;

	wire [4:0] idelay_value;
	wire idelay_load;
	wire iserdes_bitslip;
	// Bit controller. This limits the number of control signals that go to each bit to just 1.
	// Hopefully should free up HLONGs for other stuff.
	RITC_bit_control u_ctrl(.sysclk_i(SYSCLK_DIV2_PS),.ctrl_clk_i(clk_i),
									.ctrl_i(ctrl_i),
									.channel_i(channel_i),
									.bit_i(4'd15),
									.delay_o(idelay_value),
									.load_o(idelay_load),
									.bitslip_o(iserdes_bitslip));
    // Vivado can't use hard macros. So let's try instantiating it directly.
    // The clock path consists of:
    // an IFD which is clocked by gb_clk (which goes to p_q_o)
    // bypass past the IFD which goes to a BUFR
    // IDELAY for the negative path
    // IFD for the negative path passed through IDELAY
    
    generate
        if (USE_HARD_MACRO == "NO") begin : SOFT
            wire idelay_to_ifd;
            (* IOB = "TRUE" *)
            FD p_fd(.D(IN_P),.C(clk_i),.Q(p_q_o));
            BUFR u_bufr(.I(IN_P),.O(p_bufr_o));
            IDELAYE2 #(.HIGH_PERFORMANCE_MODE("FALSE"),.IDELAY_TYPE("VAR_LOAD"))
                u_idelay(.CNTVALUEIN(idelay_value),
                         .C(SYSCLK_DIV2_PS),
                         .CE(idelay_load),
                         .CINVCTRL(),
                         .DATAIN(),
                         .IDATAIN(IN_N),
                         .INC(),
                         .LD(idelay_load),
                         .LDPIPEEN(),
                         .REGRST(),
                         .DATAOUT(idelay_to_ifd));
            (* IOB = "TRUE" *)
            FD n_fd(.D(idelay_to_ifd),.C(SYSCLK_DIV2_PS),.Q(n_q_o));
	   end else begin : HARD				
            glitc_clock_path u_clock_path( .IN_P(IN_P), .IN_N(IN_N),
                                                     .P_O(ilogic_to_bufr),
                                                     .P_Q(p_q_o),
                                                     .P_CLK(clk_i),
                                                     .N_Q(n_q_o),
                                                     .N_CLK(SYSCLK_DIV2_PS),
                                                     .N_REGRST(1'b0),
                                                     .N_LDPIPEEN(1'b0),
                                                     .N_INC(1'b0),
                                                     .N_LD(idelay_load),
                                                     .N_CE(idelay_load),
                                                     .IDELAY_N_CLK(SYSCLK_DIV2_PS),
                                                     .N_D0(idelay_value[0]),
                                                     .N_D1(idelay_value[1]),
                                                     .N_D2(idelay_value[2]),
                                                     .N_D3(idelay_value[3]),
                                                     .N_D4(idelay_value[4]));
              BUFR u_bufr(.I(ilogic_to_bufr),.O(p_bufr_o));
        end
    endgenerate											 
endmodule