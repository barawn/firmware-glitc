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

// V3 now accepts *clocked* inputs, rather than raw inputs.
// So we only need to resync them over to the user clock side.
module RITC_phase_scanner_registers_v3(
		input CLK_PS,
		input user_clk_i,
		input user_scan_i,
		input [2:0] CLK_IN,
		input [11:0] CH0_IN,
		input [11:0] CH1_IN,
		input [11:0] CH2_IN,
		input VCDL_IN,
		output [2:0] CLK_Q,
		output [11:0] CH0_Q,
		output [11:0] CH1_Q,
		output [11:0] CH2_Q,
		output VCDL_Q		
    );

	wire [11:0] CH_IN[2:0];
	wire [11:0] CH_OUT[2:0];
	assign CH_IN[0] = CH0_IN;
	assign CH_IN[1] = CH1_IN;
	assign CH_IN[2] = CH2_IN;
	
	// This is the only thing CLK_PS is used for - to get a rough delay
	// from user-side to scanning-side. It's a bit silly.
	wire scan_request_CLK_PS_flag_out;
	reg scan_request_CLK_PS = 0;
	flag_sync u_sync(.in_clkA(user_scan_i),.clkA(user_clk_i),
						  .out_clkB(scan_request_CLK_PS_flag_out),.clkB(CLK_PS));
	always @(posedge CLK_PS) scan_request_CLK_PS <= scan_request_CLK_PS_flag_out;

	generate
		genvar i,j;
		for (i=0;i<3;i=i+1) begin : CHL
			(* SHREG_EXTRACT = "NO" *)
			reg [1:0] clk_reg_user_clk = {2{1'b0}};
			always @(posedge user_clk_i) clk_reg_user_clk <= {clk_reg_user_clk[0],CLK_IN[i]};
			assign CLK_Q[i] = clk_reg_user_clk[1];
			
			for (j=0;j<12;j=j+1) begin : BTL
				(* SHREG_EXTRACT = "NO" *)
				reg [1:0] dat_reg_user_clk = {2{1'b0}};
				always @(posedge user_clk_i) dat_reg_user_clk <= {dat_reg_user_clk[0],CH_IN[i][j]};
				assign CH_OUT[i][j] = dat_reg_user_clk[1];
			end
		end
	endgenerate
	assign CH0_Q = CH_OUT[0];
	assign CH1_Q = CH_OUT[1];
	assign CH2_Q = CH_OUT[2];
endmodule
