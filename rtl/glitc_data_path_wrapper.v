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
module glitc_data_path_wrapper(
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
		// Delay value to set in the IDELAY.
		input [4:0] delay_clk_i,
		// Load the value on delay_i into IDELAY.
		input load_clk_i,
		// Bitslip the SERDES.
		input bitslip_clk_i,
		// Global reset for the SERDES.
		input serdes_rst_DATACLK_DIV2_i,

		// Output from SERDES.
		output [3:0] serdes_DATACLK_DIV2_o,
		// Output from ILOGIC.
		output q_SYSCLK_DIV2_PS_o
    );

	parameter USE_HARD_MACRO = "YES";
	parameter POLARITY = 0;

	wire load_DATACLK_DIV2;
	wire load_SYSCLK_DIV2_PS;
	wire bitslip_DATACLK_DIV2;
	wire serdes_rst_DATACLK_DIV2;

	wire pside_input;
	wire nside_input;
	
	flag_sync u_bitslip_flag(.in_clkA(bitslip_clk_i),.clkA(clk_i),
									 .out_clkB(bitslip_DATACLK_DIV2),.clkB(DATACLK_DIV2));
	generate
		if (USE_HARD_MACRO == "YES") begin : MACRO
			glitc_data_path u_datapath( .ILOGIC_P_DATAIN(IN_P),
												 .ILOGIC_N_DATAIN(IN_N),
												 // Fast clock, for latching data.
												 .ILOGIC_P_CLK(DATACLK),
												 .ILOGIC_P_CLKB(DATACLK),
												 // Slower clock, for IDELAY control.
												 .IDELAY_P_CLK(clk_i),
												 .IDELAY_N_CLK(clk_i),
												 // N-side logic clock.
												 .ILOGIC_N_CLK(SYSCLK_DIV2_PS),
												 
												 // SERDES controls/output
												 // NOTE: DYNCLKSEL and DYNCLKDIVSEL BOTH need to be 1 here!
												 // Why? I DON'T KNOW! It's not documented anywhere,
												 // but if you leave them unconnected on a normal ISERDES
												 // instantiation, it connects them to 1.
												 .DYNCLKSEL(1'b1),
												 .DYNCLKDIVSEL(1'b1),
												 .BITSLIP(bitslip_DATACLK_DIV2),
												 .CLKDIV(DATACLK_DIV2),
												 .ISERDES_RST(serdes_rst_DATACLK_DIV2_i),
												 .CE1(1'b1),
												 .CE2(1'b1),
												 .P_Q1(serdes_DATACLK_DIV2_o[0]),
												 .P_Q2(serdes_DATACLK_DIV2_o[1]),
												 .P_Q3(serdes_DATACLK_DIV2_o[2]),
												 .P_Q4(serdes_DATACLK_DIV2_o[3]),
												 // N-side ILOGIC output.
												 .N_Q(q_SYSCLK_DIV2_PS_o),
												 // IDELAY unused controls.
												.P_REGRST(1'b0),.N_REGRST(1'b0),
												.P_LDPIPEEN(1'b0),.N_LDPIPEEN(1'b0),
												.P_INC(1'b0),.N_INC(1'b0),
												.P_CINVCTRL(1'b0),
												.IDELAY_P_DATAIN_UNUSED(1'b1),
												// IDELAY inputs
												.P_D0(delay_clk_i[0]),.N_D0(delay_clk_i[0]),
												.P_D1(delay_clk_i[1]),.N_D1(delay_clk_i[1]),
												.P_D2(delay_clk_i[2]),.N_D2(delay_clk_i[2]),
												.P_D3(delay_clk_i[3]),.N_D3(delay_clk_i[3]),
												.P_D4(delay_clk_i[4]),.N_D4(delay_clk_i[4]),
												// IDELAY controls
												.P_LD(load_clk_i),
												.P_CE(1'b0),
												.N_LD(load_clk_i),
												.N_CE(1'b0)
												);
		end else begin : NO_MACRO
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
			IDELAYE2 #(.IDELAY_TYPE("VAR_LOAD"),.HIGH_PERFORMANCE_MODE("FALSE")) u_idelay(.C(clk_i),
									.LD(load_clk_i),
									.CNTVALUEIN(delay_clk_i),
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
											.RST(serdes_rst_DATACLK_DIV2_i),
											.CE1(1'b1),
											.DDLY(idelay_to_iserdes),
											.BITSLIP(bitslip_DATACLK_DIV2),
											.Q1(serdes_DATACLK_DIV2_o[0]),
											.Q2(serdes_DATACLK_DIV2_o[1]),
											.Q3(serdes_DATACLK_DIV2_o[2]),
											.Q4(serdes_DATACLK_DIV2_o[3]));
			IDELAYE2 #(.IDELAY_TYPE("VAR_LOAD"),.HIGH_PERFORMANCE_MODE("FALSE")) u_idelay_n(.C(clk_i),
									.LD(load_clk_i),
									.CNTVALUEIN(delay_clk_i),
									.IDATAIN(nside_input),
									.DATAOUT(idelay_to_ilogic));
			(* IOB = "TRUE" *)
			FDE #(.INIT(0)) u_ilogicn_fd(.D(idelay_to_ilogic),.CE(1'b1),
												  .C(SYSCLK_DIV2_PS),
												  .Q(q_SYSCLK_DIV2_PS_o));
		end
	endgenerate
endmodule
module glitc_data_path(	// Overall P-side clocks.
			input ILOGIC_P_DATAIN,
			input ILOGIC_P_CLK,
			input ILOGIC_P_CLKB,
			// ISERDES controls.
			input DYNCLKSEL,
			input DYNCLKDIVSEL,
			input CE1,
			input CE2,
			output	P_Q1,
			output  P_Q2,
			output	P_Q3,
			output	P_Q4,
			input BITSLIP,
			input CLKDIV,
			input ISERDES_RST,
			// P IDELAY controls
			input P_REGRST,
			input P_LDPIPEEN,
			input P_LD,
			input P_INC,
			input P_D0,
			input P_D1,
			input P_D2,
			input P_D3,
			input P_D4,
			input P_CE,
			input IDELAY_P_DATAIN_UNUSED,
			input P_CINVCTRL,
			
			input IDELAY_P_CLK,

			input ILOGIC_N_DATAIN,
			output N_Q,
			input ILOGIC_N_CLK,
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
			// Must match ILOGIC_N_CLK.
			input IDELAY_N_CLK
);

endmodule
