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
(* SHREG_EXTRACT = "NO" *)
module RITC_dual_datapath(
		input SYSCLK,
		input DATACLK,
		input DATACLK_DIV2,
		input [11:0] CH0,
		input [11:0] CH1,
		input [11:0] CH2,
		input [11:0] CH3,
		input [11:0] CH4,
		input [11:0] CH5,
		output [47:0] CH0_OUT,
		output [47:0] CH1_OUT,
		output [47:0] CH2_OUT,
		output [47:0] CH3_OUT,
		output [47:0] CH4_OUT,
		output [47:0] CH5_OUT,
		input rst_i,
		input user_clk_i,
		input user_sel_i,
		input user_wr_i,
		input [31:0] user_dat_i,
		output [31:0] user_dat_o
    );

	wire [11:0] CH[5:0];
	wire [47:0] CH_deserdes[5:0];
	wire [47:0] CH_fifo_out[5:0];
	wire [47:0] CH_scramble[5:0];
	wire [47:0] CH_OUT[5:0];
	assign CH[0] = CH0;
	assign CH[1] = CH1;
	assign CH[2] = CH2;
	assign CH[3] = CH3;
	assign CH[4] = CH4;
	assign CH[5] = CH5;
	assign CH0_OUT = CH_OUT[0];
	assign CH1_OUT = CH_OUT[1];
	assign CH2_OUT = CH_OUT[2];
	assign CH3_OUT = CH_OUT[3];
	assign CH4_OUT = CH_OUT[4];
	assign CH5_OUT = CH_OUT[5];

	wire iserdes_reset_out;
	reg iserdes_reset = 0;
	wire [11:0] iserdes_bitslip[5:0];
	reg [11:0] iserdes_bitslip_reg[5:0];
	flag_sync u_reset_flag(.in_clkA(rst_i),.clkA(user_clk_i),
								  .out_clkB(iserdes_reset_out),.clkB(DATACLK_DIV2));
	always @(posedge DATACLK_DIV2) iserdes_reset <= iserdes_reset_out;
	
	generate
		genvar i,j,bs;
		for (i=0;i<6;i=i+1) begin : CHL
			wire [3:0] fifo_in[11:0];		
			for (j=0;j<12;j=j+1) begin : BTL
				reg bitslip_reg = 0;
				initial iserdes_bitslip_reg[i][j] <= 0;
				always @(posedge user_clk_i) begin : BITREG
					iserdes_bitslip_reg[i][j] <= user_sel_i && user_wr_i && (user_dat_i[3:0] == j) && (user_dat_i[6:4] == i);
				end
				flag_sync u_bitslip_flag(.in_clkA(iserdes_bitslip_reg[i][j]),.clkA(user_clk_i),
												 .out_clkB(iserdes_bitslip[i][j]),.clkB(DATACLK_DIV2));
				always @(posedge DATACLK_DIV2) bitslip_reg <= iserdes_bitslip[i][j];
				ISERDESE2 #(.DATA_RATE("DDR"),
								.DATA_WIDTH(4),
								.INTERFACE_TYPE("NETWORKING"),
								.IOBDELAY("IFD")) 
					u_iserdes(.DDLY(CH[i][j]),
								 .CLK(DATACLK),
								 .CLKB(~DATACLK),
								 .CE1(1'b1),
								 .CE2(1'b1),
								 .RST(iserdes_reset),
								 .CLKDIV(DATACLK_DIV2),
								 .BITSLIP(bitslip_reg),
								 .Q1(CH_deserdes[i][4*j]),
								 .Q2(CH_deserdes[i][4*j+1]),
								 .Q3(CH_deserdes[i][4*j+2]),
								 .Q4(CH_deserdes[i][4*j+3]));
				assign fifo_in[j] = CH_deserdes[i][4*j +: 4];
			end
			reg fifo_read_enable = 0;
			always @(posedge SYSCLK) begin
				fifo_read_enable <= !fifo_empty;
			end
			wire fifo_empty;
			wire [7:0] fifo_out[9:0];
			IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_fifo(
											.RDCLK(SYSCLK),.RDEN(fifo_read_enable),.EMPTY(fifo_empty),
											.D0(fifo_in[0]),.D1(fifo_in[1]),.D2(fifo_in[2]),.D3(fifo_in[3]),
											.D4(fifo_in[4]),.D5({fifo_in[10],fifo_in[5]}),.D6({fifo_in[11],fifo_in[6]}),
											.D7(fifo_in[7]),.D8(fifo_in[8]),.D9(fifo_in[9]),
											.WRCLK(DATACLK_DIV2),.WREN(1'b1),.RESET(iserdes_reset),
											.Q0(fifo_out[0]),.Q1(fifo_out[1]),.Q2(fifo_out[2]),.Q3(fifo_out[3]),
											.Q4(fifo_out[4]),.Q5(fifo_out[5]),.Q6(fifo_out[6]),.Q7(fifo_out[7]),
											.Q8(fifo_out[8]),.Q9(fifo_out[9]));
			assign CH_fifo_out[i][0 +: 4] = fifo_out[0][3:0];
			assign CH_fifo_out[i][4 +: 4] = fifo_out[1][3:0];
			assign CH_fifo_out[i][8 +: 4] = fifo_out[2][3:0];
			assign CH_fifo_out[i][12 +: 4] = fifo_out[3][3:0];
			assign CH_fifo_out[i][16 +: 4] = fifo_out[4][3:0];
			assign CH_fifo_out[i][20 +: 4] = fifo_out[5][3:0];
			assign CH_fifo_out[i][24 +: 4] = fifo_out[6][3:0];
			assign CH_fifo_out[i][28 +: 4] = fifo_out[7][3:0];
			assign CH_fifo_out[i][32 +: 4] = fifo_out[8][3:0];
			assign CH_fifo_out[i][36 +: 4] = fifo_out[9][3:0];
			assign CH_fifo_out[i][40 +: 4] = fifo_out[5][7:4];
			assign CH_fifo_out[i][44 +: 4] = fifo_out[6][7:4];			
			for (bs=0;bs<12;bs=bs+1) begin : BIT_SCR_LP
				  assign CH_OUT[i][bs] = CH_fifo_out[i][4*bs];
				  assign CH_OUT[i][12+bs] = CH_fifo_out[i][4*bs+1];
				  assign CH_OUT[i][24+bs] = CH_fifo_out[i][4*bs+2];
				  assign CH_OUT[i][36+bs] = CH_fifo_out[i][4*bs+3];
			end
		end
	endgenerate

endmodule
