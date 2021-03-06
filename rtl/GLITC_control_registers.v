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
module GLITC_control_registers(
		input user_clk_i,
		input [1:0] user_addr_i,
		input [31:0] user_dat_i,
		output [31:0] user_dat_o,
		input user_wr_i,
		input user_rd_i,
		input user_sel_i,
		
		output [2:0] clk_control_o,
		output reset_o
    );
	parameter [31:0] IDENT = "GLTC";
	parameter [31:0] VERSION = 32'h00000000;
	wire [31:0] control_data_out;
	wire [31:0] data_out[3:0];
	assign data_out[0] = IDENT;
	assign data_out[1] = VERSION;
	assign data_out[2] = control_data_out;
	assign data_out[3] = control_data_out;
	
	reg [2:0] clk_control_reg = {3{1'b0}};
	reg reset_reg = 1'b0;
	
	always @(posedge user_clk_i) begin
		if (user_sel_i && user_wr_i && user_addr_i[1]) clk_control_reg <= user_dat_i[2:0];
		if (user_sel_i && user_wr_i && user_addr_i[1]) reset_reg <= user_dat_i[31];
		else reset_reg <= 0;
	end
	assign control_data_out[2:0] = clk_control_reg;
	assign control_data_out[30:3] = {28{1'b0}};
	assign control_data_out[31] = reset_reg;
	
	assign reset_o = reset_reg;
	assign clk_control_o = clk_control_reg;
	assign user_dat_o = data_out[user_addr_i];

endmodule
