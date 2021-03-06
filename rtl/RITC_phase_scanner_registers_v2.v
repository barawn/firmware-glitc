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
module RITC_phase_scanner_registers_v2(
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
	wire scan_request_CLK_PS_flag_out;
	reg scan_request_CLK_PS = 0;
	flag_sync u_sync(.in_clkA(user_scan_i),.clkA(user_clk_i),
						  .out_clkB(scan_request_CLK_PS_flag_out),.clkB(CLK_PS));
	always @(posedge CLK_PS) scan_request_CLK_PS <= scan_request_CLK_PS_flag_out;

	reg vcdl_reg = 0;
	(* SHREG_EXTRACT = "NO" *)
	reg [1:0] vcdl_reg_user_clk = {2{1'b0}};
	always @(posedge CLK_PS) begin
		vcdl_reg <= VCDL_IN;
	end
	always @(posedge user_clk_i) begin
		vcdl_reg_user_clk <= {vcdl_reg_user_clk[0], vcdl_reg};
	end

	generate
		genvar i,j;
		for (i=0;i<3;i=i+1) begin : CHL
			reg clk_reg = 0;
			(* SHREG_EXTRACT = "NO" *)
			reg [1:0] clk_reg_user_clk = {2{1'b0}};
			always @(posedge CLK_PS) clk_reg <= CLK_IN[i];
			always @(posedge user_clk_i) clk_reg_user_clk <= {clk_reg_user_clk[0],clk_reg};
			assign CLK_Q[i] = clk_reg_user_clk[1];
			
			for (j=0;j<12;j=j+1) begin : BTL
				reg dat_reg = 0;
				(* SHREG_EXTRACT = "NO" *)
				reg [1:0] dat_reg_user_clk = {2{1'b0}};
				always @(posedge CLK_PS) dat_reg <= CH_IN[i][j];
				always @(posedge user_clk_i) dat_reg_user_clk <= {dat_reg_user_clk[0],dat_reg};
				assign CH_OUT[i][j] = dat_reg_user_clk[1];
			end
		end
	endgenerate
	assign CH0_Q = CH_OUT[0];
	assign CH1_Q = CH_OUT[1];
	assign CH2_Q = CH_OUT[2];

	assign VCDL_Q = vcdl_reg_user_clk[1];
endmodule
