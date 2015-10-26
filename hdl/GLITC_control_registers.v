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
		output realign_o,
		input realigned_i,
		output [2:0] clk_control_o,
		output reset_o
    );
	parameter [31:0] IDENT = "GLTC";
	parameter [31:0] VERSION = 32'h00000000;
	wire [31:0] control_data_out;
    wire [31:0] dna_data_out;
	wire [31:0] data_out[3:0];
	assign data_out[0] = IDENT;
	assign data_out[1] = VERSION;
	assign data_out[2] = control_data_out;
	assign data_out[3] = dna_data_out;
	
    reg read_reg = 0;
    reg shift_reg = 0;	
	reg [2:0] clk_control_reg = {3{1'b0}};
	reg reset_reg = 1'b0;
	reg realign = 0;
	reg realigned = 0;
	wire dna_data;
	
	always @(posedge user_clk_i) begin
        if (user_sel_i && user_wr_i && (user_addr_i[1:0]==2'b11)) read_reg <= user_dat_i[31];
        else read_reg <= 0;
        
        if (user_sel_i && user_rd_i && (user_addr_i[1:0]==2'b11)) shift_reg <= 1;
        else shift_reg <= 0;
        
		if (user_sel_i && user_wr_i && (user_addr_i[1:0]==2'b10)) clk_control_reg <= user_dat_i[2:0];
        if (user_sel_i && user_wr_i && (user_addr_i[1:0]==2'b10)) realign <= user_dat_i[4];
        else realign <= 0;
        if (realigned_i) realigned <= 1;
        else if (realign) realigned <= 0;
        
		if (user_sel_i && user_wr_i && user_addr_i[1]) reset_reg <= user_dat_i[31];
		else reset_reg <= 0;
	end
	
	DNA_PORT u_dna(.DIN(1'b0),.READ(read_reg),.SHIFT(shift_reg),.CLK(user_clk_i),.DOUT(dna_data));
	
	assign dna_data_out = {{30{1'b0}},dna_data};
	assign control_data_out[2:0] = clk_control_reg;
	assign control_data_out[4:3] = 2'b00;
	assign control_data_out[5] = realigned;
	assign control_data_out[31:6] = {26{1'b0}};
	
	assign reset_o = reset_reg;
	assign clk_control_o = clk_control_reg;
	assign user_dat_o = data_out[user_addr_i];
    assign realign_o = realign;
endmodule
