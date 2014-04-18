`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    14:25:13 07/30/2012 
// Design Name: 
// Module Name:    glitc 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module glitc(
		A_P,
		A_N,
		AREF_P,
		AREF_N,
		B_P,
		B_N,
		BREF_P,
		BREF_N,
		C_P,
		C_N,
		CREF_P,
		CREF_N,

		A_VCDL,
		A_VCDL_OUT,
		
		A_DAC_DIN,
		A_DAC_CLK,
		A_DAC_LATCH,
		A_DAC_DOUT,
		
		A_TRAINING_ON,
		
		D_P,
		D_N,
		DREF_P,
		DREF_N,
		E_P,
		E_N,
		EREF_P,
		EREF_N,
		F_P,
		F_N,
		FREF_P,
		FREF_N,
		
		B_VCDL,
		B_VCDL_OUT,

		B_DAC_DIN,
		B_DAC_CLK,
		B_DAC_LATCH,
		B_DAC_DOUT,
		
		B_TRAINING_ON,
		
		clk,
		MAX_A,
		MAX_B,
		
		GSEL,
		GAD,
		GCCLK,
		GRST
    );

	input [11:0] A_P;
	input [11:0] A_N;
	input AREF_P, AREF_N;
	
	input [11:0] B_P;
	input [11:0] B_N;
	input BREF_P, BREF_N;
	
	input [11:0] C_P;
	input [11:0] C_N;
	input CREF_P, CREF_N;

	output A_VCDL;
	input A_VCDL_OUT;
	
	output A_DAC_DIN;
	output A_DAC_CLK;
	output A_DAC_LATCH;
	input A_DAC_DOUT;
	
	output A_TRAINING_ON;
	
	input [11:0] D_P;
	input [11:0] D_N;
	input DREF_P, DREF_N;
	
	input [11:0] E_P;
	input [11:0] E_N;
	input EREF_P, EREF_N;
	
	input [11:0] F_P;
	input [11:0] F_N;
	input FREF_P, FREF_N;

	output B_VCDL;
	input B_VCDL_OUT;

	output B_DAC_DIN;
	output B_DAC_CLK;
	output B_DAC_LATCH;
	input B_DAC_DOUT;
	
	output B_TRAINING_ON;
	
	input clk;
	output [10:0] MAX_A;
	output [10:0] MAX_B;

	// GLITCBUS
	input GSEL;
	inout [7:0] GAD;
	input GCCLK;
	
	wire [47:0] inA;
	wire [47:0] inB;
	wire [47:0] inC;

	// GLITCBUS output interface.
	wire [13:0] address;
	wire [7:0] data_to_glitc;
	wire [7:0] data_from_glitc;
	wire [7:0] data_from_glitcA;
	wire [7:0] data_from_glitcB;
	wire sel_A;
	wire sel_B;
	wire wr;
	wire rd;
	wire ackA;
	wire ackB;
	wire ack;
	glitc_infrastructure g_infraA(.A_P(A_P),.A_N(A_N),.AREF_P(AREF_P),.AREF_N(AREF_N),
										  .B_P(B_P),.B_N(B_N),.BREF_P(BREF_P),.BREF_N(BREF_N),
										  .C_P(C_P),.C_N(C_N),.CREF_P(CREF_P),.CREF_N(CREF_N),
										  .clk(clk),
										  .A_o(inA),
										  .B_o(inB),
										  .C_o(inC),.enable_i(1'b1));
	
	glitc_infrastructure g_infraB(.A_P(D_P),.A_N(D_N),.AREF_P(DREF_P),.AREF_N(DREF_N),
										  .B_P(E_P),.B_N(E_N),.BREF_P(EREF_P),.BREF_N(EREF_N),
										  .C_P(F_P),.C_N(F_N),.CREF_P(FREF_P),.CREF_N(FREF_N),
										  .clk(clk),
										  .A_o(inD),
										  .B_o(inE),
										  .C_o(inF),.enable_i(1'b1));
	
	top_glitc top(.clk(clk),.A(inA),.B(inB),.C(inC),.sum_max(MAX_A),
					  .address(address),.data_i(data_to_glitc),.data_o(data_from_glitcA),
					  .sel_i(sel_A),.wr_i(wr),.rd_i(rd),.ack_o(ackA),.VCDL(A_VCDL),.VCDL_OUT(A_VCDL_OUT));

	top_glitc top(.clk(clk),.A(inD),.B(inE),.C(inF),.sum_max(MAX_B),
					  .address(address),.data_i(data_to_glitc),.data_o(data_from_glitcB),
					  .sel_i(sel_B),.wr_i(wr),.rd_i(rd),.ack_o(ackB),.VCDL(B_VCDL),.VCDL_OUT(B_VCDL_OUT));

	assign data_from_glitch = (sel_A) ? data_from_glitcA : data_from_glitcB;
	assign ack = (sel_A) ? ackA : ackB;
	
	glitcbus_slave(.GSEL(GSEL),.GAD(GAD),.GCCLK(GCCLK),.GRST(GRST),.clk_i(clk),
					   .address_o(address),.data_i(data_from_glitc),.data_o(data_to_glitc),
						.selA_o(sel_A),.selB_o(sel_B),.wr_o(wr),.rd_o(rd),.ack(ack));
endmodule
