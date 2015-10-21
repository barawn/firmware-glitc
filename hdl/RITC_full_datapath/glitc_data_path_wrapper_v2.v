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

// Version 2 of the wrapper around an individual bit output.
// This one uses the bit control module to eliminate multiple signal fanout,
// and it also abandons the use of a hard macro at all (which was abandoned
// before anyway for the data path).
module glitc_data_path_wrapper_v2(
		// System clock (162.5 MHz)
		input SYSCLK,
		// Data clock (325 MHz)
		input DATACLK,
		// Data clock divided by 2 (162.5 MHz). Base clock for 'P' logic.
		input DATACLK_DIV2,
		// System clock, divided by 2, phase shifted (81.25 MHz). Base clock for 'N' logic.
		input SYSCLK_DIV2_PS,

		// Inputs.
		wire	IN_P,
		wire	IN_N,

		// Clock for control signals.
		input clk_i,
		// Control input for the bit control.
		input ctrl_i,
		// Channel address.
		input [2:0] channel_i,
		// Bit address.
		input [3:0] bit_i,
		// Global reset for the SERDES.
		input serdes_rst_DATACLK_DIV2_i,

		// Output from SERDES.
		output [3:0] serdes_DATACLK_DIV2_o,
		// Output from ILOGIC.
		output q_SYSCLK_DIV2_PS_o
    );

	parameter POLARITY = 0;

	wire pside_input;
	wire nside_input;
	
	wire [4:0] idelay_value;
	wire idelay_load;
	wire iserdes_bitslip;
	
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* DONT_TOUCH = "TRUE" *)
	reg serdes_reset = 0;
	always @(posedge DATACLK_DIV2) begin
	   serdes_reset <= serdes_rst_DATACLK_DIV2_i;
	end
	
	// Bit controller. This limits the number of control signals that go to each bit to just 1.
	// Hopefully should free up HLONGs for other stuff.
	RITC_bit_control u_ctrl(.sysclk_i(DATACLK_DIV2),.ctrl_clk_i(clk_i),
									.ctrl_i(ctrl_i),
									.channel_i(channel_i),
									.bit_i(bit_i),
									.delay_o(idelay_value),
									.load_o(idelay_load),
									.bitslip_o(iserdes_bitslip));
	generate
		if (POLARITY == 1) begin : INVERT
			assign pside_input = ~IN_P;
			assign nside_input = IN_N;
		end else begin : NORMAL
			assign pside_input = IN_P;
			assign nside_input = ~IN_N;
		end
		// NOTE: Not using the hard macro means you need to set
		// the environment variable XIL_PAR_ALLOW_LVDS_LOC_OVERRIDE = 1 
		// otherwise par will error out.
		//
		// This is just a bug in par. There's nothing wrong with any
		// of these connections, it just gets confused. Probably because
		// it's placing the negative side first, thinks it's inverted,
		// and doesn't realize there's something on the positive side too.
		wire idelay_to_iserdes;
		wire idelay_to_ilogic;
		IDELAYE2 #(.IDELAY_TYPE("VAR_LOAD"),.HIGH_PERFORMANCE_MODE("FALSE")) u_idelay(.C(DATACLK_DIV2),
								.LD(idelay_load),
								.CNTVALUEIN(idelay_value),
								.IDATAIN(pside_input),
								.DATAOUT(idelay_to_iserdes));
		ISERDESE2 #(.DATA_RATE("DDR"),
						.DATA_WIDTH(4),
						.INTERFACE_TYPE("NETWORKING"),
						.NUM_CE(1),
						.IOBDELAY("IFD"))
						u_iserdes(  .CLK(DATACLK),
										.CLKB(~DATACLK),
										.CLKDIV(DATACLK_DIV2),
										.RST(serdes_reset),
										.CE1(1'b1),
										.DDLY(idelay_to_iserdes),
										.BITSLIP(iserdes_bitslip),
										.Q1(serdes_DATACLK_DIV2_o[0]),
										.Q2(serdes_DATACLK_DIV2_o[1]),
										.Q3(serdes_DATACLK_DIV2_o[2]),
										.Q4(serdes_DATACLK_DIV2_o[3]));
		IDELAYE2 #(.IDELAY_TYPE("VAR_LOAD"),.HIGH_PERFORMANCE_MODE("FALSE")) u_idelay_n(.C(DATACLK_DIV2),
								.LD(idelay_load),
								.CNTVALUEIN(idelay_value),
								.IDATAIN(nside_input),
								.DATAOUT(idelay_to_ilogic));
		(* IOB = "TRUE" *)
		FDE #(.INIT(0)) u_ilogicn_fd(.D(idelay_to_ilogic),.CE(1'b1),
											  .C(SYSCLK_DIV2_PS),
											  .Q(q_SYSCLK_DIV2_PS_o));
	endgenerate
	
endmodule
