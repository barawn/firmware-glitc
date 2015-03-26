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
		input serdes_rst_clk_i,

		// Output from SERDES.
		output [3:0] serdes_DATACLK_DIV2_o,
		// Output from ILOGIC.
		output q_SYSCLK_DIV2_PS_o
    );

	wire load_DATACLK_DIV2;
	wire load_SYSCLK_DIV2_PS;
	wire bitslip_DATACLK_DIV2;
	wire serdes_rst_DATACLK_DIV2;
	
	flag_sync u_bitslip_flag(.in_clkA(bitslip_clk_i),.clkA(clk_i),
									 .out_clkB(bitslip_DATACLK_DIV2),.clkB(DATACLK_DIV2));
	flag_sync u_serdes_rst(.in_clkA(serdes_rst_clk_i),.clkA(clk_i),
								  .out_clkB(serdes_rst_DATACLK_DIV2),.clkB(DATACLK_DIV2));
	flag_sync u_load_p(.in_clkA(load_clk_i),.clkA(clk_i),
							 .out_clkB(load_DATACLK_DIV2),.clkB(DATACLK_DIV2));
	flag_sync u_load_n(.in_clkA(load_clk_i),.clkA(clk_i),
							 .out_clkB(load_SYSCLK_DIV2_PS),.clkB(SYSCLK_DIV2_PS));

	glitc_data_path u_datapath( .ILOGIC_P_DATAIN(IN_P),
										 .ILOGIC_N_DATAIN(IN_N),
										 // Fast clock, for latching data.
										 .ILOGIC_P_CLK(DATACLK),
										 .ILOGIC_P_CLKB(DATACLK),
										 // Slower clock, for IDELAY control.
										 .IDELAY_P_CLK(DATACLK_DIV2),
										 .IDELAY_N_CLK(SYSCLK_DIV2_PS),
										 // N-side logic clock.
										 .ILOGIC_N_CLK(SYSCLK_DIV2_PS),
										 
										 // SERDES controls/output
										 .DYNCLKSEL(1'b0),
										 .DYNCLKDIVSEL(1'b0),
										 .BITSLIP(bitslip_DATACLK_DIV2),
										 .CLKDIV(DATACLK_DIV2),
										 .ISERDES_RST(serdes_rst_DATACLK_DIV2),
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
										// IDELAY inputs
										.P_D0(delay_clk_i[0]),.N_D0(delay_clk_i[0]),
										.P_D1(delay_clk_i[1]),.N_D1(delay_clk_i[1]),
										.P_D2(delay_clk_i[2]),.N_D2(delay_clk_i[2]),
										.P_D3(delay_clk_i[3]),.N_D3(delay_clk_i[3]),
										.P_D4(delay_clk_i[4]),.N_D4(delay_clk_i[4]),
										// IDELAY controls
										.P_LD(load_DATACLK_DIV2),
										.P_CE(load_DATACLK_DIV2),
										.N_LD(load_SYSCLK_DIV2_PS),
										.N_CE(load_SYSCLK_DIV2_PS)
										);
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
			// Must match ILOGIC_P_CLK.
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
