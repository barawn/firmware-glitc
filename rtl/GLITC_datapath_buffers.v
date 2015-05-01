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

/** \brief Super-fancy datapath buffers for the GLITC using IN_FIFOs matched to inputs.
 *
 * This module uses IN_FIFOs, specifically matched to each input to make the routing
 * trivial and optimized.
 *
 * The FIFOs are more based on banks and byte groups than channels.
 *
 * There's no real pattern here to where the bits go. It just depends on the
 * actual routing of the FPGA to the RITC, and where each input bit landed.
 * So yes, this all does look like magic.
 *
 * Obviously this utilizes the IO_FIFO resources pretty heavily, using
 * 20 FIFOs where we could have used only 6. But the FIFOs are there, and they're
 * very low power, whereas the interconnect (running at 162.5 MHz) is actually
 * pretty power hungry. The average delay drops from ~2.5 ns to ~0.6 ns, and the
 * number of interconnects needed drops by like a factor of 6.
 *
 * The LOC constraints are there because Map is brain-dead. Each of these FIFOs
 * should be the FIFO that's associated with the byte-group, but it can't recognize
 * that. So we LOC-constrain it to the exact one.
 *
 * Obviously THIS ENTIRE THING needs to be changed if the GLITC physical design
 * is changed at all.
 *
 */
module GLITC_datapath_buffers(
		input rst_i,
		input en_i,
		output valid_o,
		input DATACLK_DIV2,
		input SYSCLK,
		// These are in "bit-order" - [3:0] = bit 0, [7:4] = bit 1, etc.
		input [47:0] IN0,
		input [47:0] IN1,
		input [47:0] IN2,
		input [47:0] IN3,
		input [47:0] IN4,
		input [47:0] IN5,
		output [47:0] OUT0,
		output [47:0] OUT1,
		output [47:0] OUT2,
		output [47:0] OUT3,
		output [47:0] OUT4,
		output [47:0] OUT5
    );

	reg en_sysclk_p = 0;
	reg en_sysclk_n = 0;
	reg en_dataclk_div2 = 0;
	reg ack_dataclk_div2 = 0;
	reg ack_sysclk = 0;

	// FIFO control handling.
	always @(posedge SYSCLK) begin
		en_sysclk_p <= en_i;
		ack_sysclk <= ack_dataclk_div2;
	end
	always @(negedge SYSCLK) begin
		en_sysclk_n <= en_sysclk_p;
	end
	always @(posedge DATACLK_DIV2) begin
		en_dataclk_div2 <= en_sysclk_n;
		ack_dataclk_div2 <= en_dataclk_div2;
	end
	assign valid_o = ack_sysclk;
	
	// Vectorize.
	wire [3:0] ch_vect[5:0][11:0];
	wire [3:0] fifo_vect[5:0][11:0];
	generate
		genvar i;
		for (i=0;i<12;i=i+1) begin : BV
			assign ch_vect[0][i] = IN0[4*i +: 4];
			assign ch_vect[1][i] = IN1[4*i +: 4];
			assign ch_vect[2][i] = IN2[4*i +: 4];
			assign ch_vect[3][i] = IN3[4*i +: 4];
			assign ch_vect[4][i] = IN4[4*i +: 4];
			assign ch_vect[5][i] = IN5[4*i +: 4];
		end
	endgenerate
	
	// CH0 (A): Bank 14
	// Bank 14, byte 0: A2 is bit 1, A8 is bit 11
	wire [7:0] bank14_byte0_bit6_in = {ch_vect[0][8],{4{1'b0}}};
	wire [7:0] bank14_byte0_bit6_out;
	assign fifo_vect[0][8] = bank14_byte0_bit6_out[7:4];
	(* LOC = "IN_FIFO_X0Y11" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank14_byte0(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D1(ch_vect[0][2]),.Q1(fifo_vect[0][2]),
				.D6(bank14_byte0_bit6_in),.Q6(bank14_byte0_bit6_out)
				);
	// Bank 14, byte 1: A7 is bit 5, A9 is bit 7, A10 is bit 9, and A11 is bit11 (bit6[7:4])
	wire [7:0] bank14_byte1_bit6_in = {ch_vect[0][11],{4{1'b0}}};
	wire [7:0] bank14_byte1_bit6_out;
	assign fifo_vect[0][11] = bank14_byte1_bit6_out[7:4];
	(* LOC = "IN_FIFO_X0Y10" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank14_byte1(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D5(ch_vect[0][7]),.Q5(fifo_vect[0][7]),
				.D7(ch_vect[0][9]),.Q7(fifo_vect[0][9]),
				.D9(ch_vect[0][10]),.Q9(fifo_vect[0][10]),
				.D6(bank14_byte1_bit6_in),.Q6(bank14_byte1_bit6_out)
				);
	(* LOC = "IN_FIFO_X0Y9" *)
	// Bank 14, byte 2: A1 (bit3), A3 (bit9), A5 (bit1), A6 (bit7)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank14_byte2(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D1(ch_vect[0][5]),.Q1(fifo_vect[0][5]),
				.D3(ch_vect[0][1]),.Q3(fifo_vect[0][1]),
				.D7(ch_vect[0][6]),.Q7(fifo_vect[0][6]),
				.D9(ch_vect[0][3]),.Q9(fifo_vect[0][3]));
	// Bank 14, byte 3: A0 (bit7), A4 (bit1)
	(* LOC = "IN_FIFO_X0Y8" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank14_byte3(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D7(ch_vect[0][0]),.Q7(fifo_vect[0][0]),
				.D1(ch_vect[0][4]),.Q1(fifo_vect[0][4]));
	// Collect the FIFO vector.
	assign OUT0 = { fifo_vect[0][11],
						 fifo_vect[0][10],
						 fifo_vect[0][9],
						 fifo_vect[0][8],
						 fifo_vect[0][7],
						 fifo_vect[0][6],
						 fifo_vect[0][5],
						 fifo_vect[0][4],
						 fifo_vect[0][3],
						 fifo_vect[0][2],
						 fifo_vect[0][1],
						 fifo_vect[0][0] };
	// Bank 15, byte 0: nothing
	// Bank 15, byte 1: B5 (5) B7 (11) B9 (3) B10 (9) B11 (7)
	wire [7:0] bank15_byte1_bit6_in = {ch_vect[1][7],{4{1'b0}}};
	wire [7:0] bank15_byte1_bit6_out;
	assign fifo_vect[1][7] = bank15_byte1_bit6_out[7:4];	
	(* LOC = "IN_FIFO_X0Y14" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank15_byte1(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D3(ch_vect[1][9]),.Q3(fifo_vect[1][9]),
				.D5(ch_vect[1][5]),.Q5(fifo_vect[1][5]),
				.D6(bank15_byte1_bit6_in),.Q6(bank15_byte1_bit6_out),
				.D7(ch_vect[1][11]),.Q7(fifo_vect[1][11]),
				.D9(ch_vect[1][10]),.Q9(fifo_vect[1][10]));
				
	// Bank 15, byte 2: B0 (3), B2 (1), B3 (11), B6(5), B8 (9)
	wire [7:0] bank15_byte2_bit6_in = {ch_vect[1][3],{4{1'b0}}};
	wire [7:0] bank15_byte2_bit6_out;
	assign fifo_vect[1][3] = bank15_byte2_bit6_out[7:4];	
	(* LOC = "IN_FIFO_X0Y13" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank15_byte2(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D1(ch_vect[1][2]),.Q1(fifo_vect[1][2]),
				.D3(ch_vect[1][0]),.Q3(fifo_vect[1][0]),
				.D5(ch_vect[1][6]),.Q5(fifo_vect[1][6]),
				.D6(bank15_byte2_bit6_in),.Q6(bank15_byte2_bit6_out),
				.D9(ch_vect[1][8]),.Q9(fifo_vect[1][8]));
	
	// Bank 15, byte 3: B1 (1), B4 (3).
	(* LOC = "IN_FIFO_X0Y12" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank15_byte3(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D1(ch_vect[1][1]),.Q1(fifo_vect[1][1]),
				.D3(ch_vect[1][4]),.Q3(fifo_vect[1][4]));

	// Collect the FIFO vector.
	assign OUT1 = { fifo_vect[1][11],
						 fifo_vect[1][10],
						 fifo_vect[1][9],
						 fifo_vect[1][8],
						 fifo_vect[1][7],
						 fifo_vect[1][6],
						 fifo_vect[1][5],
						 fifo_vect[1][4],
						 fifo_vect[1][3],
						 fifo_vect[1][2],
						 fifo_vect[1][1],
						 fifo_vect[1][0] };


	// Bank 16, byte 0: C3, bit 7.
	(* LOC = "IN_FIFO_X0Y19" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank16_byte0(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D7(ch_vect[2][3]),.Q7(fifo_vect[2][3]));
	// Bank 16, byte 1: nothing.
	// Bank 16, byte 2: C0(11),C1(3),C4(1),C9(5),C11(9)
	wire [7:0] bank16_byte2_bit6_in = {ch_vect[2][0],{4{1'b0}}};
	wire [7:0] bank16_byte2_bit6_out;
	assign fifo_vect[2][0] = bank16_byte2_bit6_out[7:4];
	(* LOC = "IN_FIFO_X0Y17" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank16_byte2(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D1(ch_vect[2][4]),.Q1(fifo_vect[2][4]),
				.D3(ch_vect[2][1]),.Q3(fifo_vect[2][1]),
				.D5(ch_vect[2][9]),.Q5(fifo_vect[2][9]),
				.D6(bank16_byte2_bit6_in),.Q6(bank16_byte2_bit6_out),
				.D9(ch_vect[2][11]),.Q9(fifo_vect[2][11]));

	// Bank 16, byte 3: C2(1), C5(7), C6(3),C7(11),C8(5),C10(9)
	wire [7:0] bank16_byte3_bit6_in = {ch_vect[2][7],{4{1'b0}}};
	wire [7:0] bank16_byte3_bit6_out;
	assign fifo_vect[2][7] = bank16_byte3_bit6_out[7:4];
	(* LOC = "IN_FIFO_X0Y16" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank16_byte3(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D1(ch_vect[2][2]),.Q1(fifo_vect[2][2]),
				.D3(ch_vect[2][6]),.Q3(fifo_vect[2][6]),
				.D5(ch_vect[2][8]),.Q5(fifo_vect[2][8]),
				.D6(bank16_byte3_bit6_in),.Q6(bank16_byte3_bit6_out),
				.D7(ch_vect[2][5]),.Q7(fifo_vect[2][5]),
				.D9(ch_vect[2][10]),.Q9(fifo_vect[2][10]));
	// Collect the FIFO vector.
	assign OUT2 = { fifo_vect[2][11],
						 fifo_vect[2][10],
						 fifo_vect[2][9],
						 fifo_vect[2][8],
						 fifo_vect[2][7],
						 fifo_vect[2][6],
						 fifo_vect[2][5],
						 fifo_vect[2][4],
						 fifo_vect[2][3],
						 fifo_vect[2][2],
						 fifo_vect[2][1],
						 fifo_vect[2][0] };
	// Bank 35, byte 0: nothing
	// Bank 35, byte 1: D0 (11) D2 (9)
	wire [7:0] bank35_byte1_bit6_in = {ch_vect[3][0],{4{1'b0}}};
	wire [7:0] bank35_byte1_bit6_out;
	assign fifo_vect[3][0] = bank35_byte1_bit6_out[7:4];	
	(* LOC = "IN_FIFO_X1Y14" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank35_byte1(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D6(bank35_byte1_bit6_in),.Q6(bank35_byte1_bit6_out),
				.D9(ch_vect[3][2]),.Q9(fifo_vect[3][2]));				
	// Bank 35, byte 2: D4 (1) D5 (3) D6 (11) D8 (5)
	wire [7:0] bank35_byte2_bit6_in = {ch_vect[3][6],{4{1'b0}}};
	wire [7:0] bank35_byte2_bit6_out;
	assign fifo_vect[3][6] = bank35_byte2_bit6_out[7:4];	
	(* LOC = "IN_FIFO_X1Y13" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank35_byte2(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D1(ch_vect[3][4]),.Q1(fifo_vect[3][4]),
				.D3(ch_vect[3][5]),.Q3(fifo_vect[3][5]),
				.D5(ch_vect[3][8]),.Q5(fifo_vect[3][8]),
				.D6(bank35_byte2_bit6_in),.Q6(bank35_byte2_bit6_out));
	// Bank 35, byte 3: D1 (1) D3 (9) D7 (3) D9 (11) D10 (5) D11 (7)
	wire [7:0] bank35_byte3_bit6_in = {ch_vect[3][9],{4{1'b0}}};
	wire [7:0] bank35_byte3_bit6_out;
	assign fifo_vect[3][9] = bank35_byte3_bit6_out[7:4];	
	(* LOC = "IN_FIFO_X1Y12" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank35_byte3(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D1(ch_vect[3][1]),.Q1(fifo_vect[3][1]),
				.D3(ch_vect[3][7]),.Q3(fifo_vect[3][7]),
				.D5(ch_vect[3][10]),.Q5(fifo_vect[3][10]),
				.D6(bank35_byte3_bit6_in),.Q6(bank35_byte3_bit6_out),
				.D7(ch_vect[3][11]),.Q7(fifo_vect[3][11]),
				.D9(ch_vect[3][3]),.Q9(fifo_vect[3][3]));
	// Collect the FIFO vector.
	assign OUT3 = { fifo_vect[3][11],
						 fifo_vect[3][10],
						 fifo_vect[3][9],
						 fifo_vect[3][8],
						 fifo_vect[3][7],
						 fifo_vect[3][6],
						 fifo_vect[3][5],
						 fifo_vect[3][4],
						 fifo_vect[3][3],
						 fifo_vect[3][2],
						 fifo_vect[3][1],
						 fifo_vect[3][0] };
	// Bank 34, byte 0: nothing
	// Bank 34, byte 1: E0 (3) E1 (5) E2 (1)
	(* LOC = "IN_FIFO_X1Y10" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank34_byte1(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D1(ch_vect[4][2]),.Q1(fifo_vect[4][2]),
				.D3(ch_vect[4][0]),.Q3(fifo_vect[4][0]),
				.D5(ch_vect[4][1]),.Q5(fifo_vect[4][1]));	
	// Bank 34, byte 2: E3 (5) E4 (11) E5 (1)
	wire [7:0] bank34_byte2_bit6_in = {ch_vect[4][4],{4{1'b0}}};
	wire [7:0] bank34_byte2_bit6_out;
	assign fifo_vect[4][4] = bank34_byte2_bit6_out[7:4];	
	(* LOC = "IN_FIFO_X1Y9" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank34_byte2(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D1(ch_vect[4][5]),.Q1(fifo_vect[4][5]),
				.D5(ch_vect[4][3]),.Q5(fifo_vect[4][3]),
				.D6(bank34_byte2_bit6_in),.Q6(bank34_byte2_bit6_out));
				
	
	// Bank 34, byte 3: E6 (7) E7 (3) E8 (9) E9 (5) E10 (1) E11 (11)
	wire [7:0] bank34_byte3_bit6_in = {ch_vect[4][11],{4{1'b0}}};
	wire [7:0] bank34_byte3_bit6_out;
	assign fifo_vect[4][11] = bank34_byte3_bit6_out[7:4];	
	(* LOC = "IN_FIFO_X1Y8" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank34_byte3(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D1(ch_vect[4][10]),.Q1(fifo_vect[4][10]),
				.D3(ch_vect[4][7]),.Q3(fifo_vect[4][7]),
				.D5(ch_vect[4][9]),.Q5(fifo_vect[4][9]),
				.D6(bank34_byte3_bit6_in),.Q6(bank34_byte3_bit6_out),
				.D7(ch_vect[4][6]),.Q7(fifo_vect[4][6]),
				.D9(ch_vect[4][8]),.Q9(fifo_vect[4][8]));

	// Collect the FIFO vector.
	assign OUT4 = { fifo_vect[4][11],
						 fifo_vect[4][10],
						 fifo_vect[4][9],
						 fifo_vect[4][8],
						 fifo_vect[4][7],
						 fifo_vect[4][6],
						 fifo_vect[4][5],
						 fifo_vect[4][4],
						 fifo_vect[4][3],
						 fifo_vect[4][2],
						 fifo_vect[4][1],
						 fifo_vect[4][0] };


	// Bank 13, byte 0: F1 (7) F2 (11) F3 (9) F7 (5) F9 (1) F11 (3)	
	wire [7:0] bank13_byte0_bit6_in = {ch_vect[5][2],{4{1'b0}}};
	wire [7:0] bank13_byte0_bit6_out;
	assign fifo_vect[5][2] = bank13_byte0_bit6_out[7:4];	
	(* LOC = "IN_FIFO_X0Y7" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank13_byte0(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D1(ch_vect[5][9]),.Q1(fifo_vect[5][9]),
				.D3(ch_vect[5][11]),.Q3(fifo_vect[5][11]),
				.D5(ch_vect[5][7]),.Q5(fifo_vect[5][7]),
				.D6(bank13_byte0_bit6_in),.Q6(bank13_byte0_bit6_out),
				.D7(ch_vect[5][1]),.Q7(fifo_vect[5][1]),
				.D9(ch_vect[5][3]),.Q9(fifo_vect[5][3]));

	// Bank 13, byte 1: F4(1) F6 (9) F8 (11) F10 (3)
	wire [7:0] bank13_byte1_bit6_in = {ch_vect[5][8],{4{1'b0}}};
	wire [7:0] bank13_byte1_bit6_out;
	assign fifo_vect[5][8] = bank13_byte1_bit6_out[7:4];	
	(* LOC = "IN_FIFO_X0Y6" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank13_byte1(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D1(ch_vect[5][4]),.Q1(fifo_vect[5][4]),
				.D3(ch_vect[5][10]),.Q3(fifo_vect[5][10]),
				.D6(bank13_byte1_bit6_in),.Q6(bank13_byte1_bit6_out),
				.D9(ch_vect[5][6]),.Q9(fifo_vect[5][6]));

	// Bank 13, byte 2: F0 (9), F5 (5)
	(* LOC = "IN_FIFO_X0Y5" *)
	IN_FIFO #(.ARRAY_MODE("ARRAY_MODE_4_X_4")) u_bank13_byte2(
				.RESET(rst_i),.RDCLK(SYSCLK),.RDEN(ack_sysclk),
				.WRCLK(DATACLK_DIV2),.WREN(en_dataclk_div2),
				.D5(ch_vect[5][5]),.Q5(fifo_vect[5][5]),
				.D9(ch_vect[5][0]),.Q9(fifo_vect[5][0]));
	// Collect the FIFO vector.
	assign OUT5 = { fifo_vect[5][11],
						 fifo_vect[5][10],
						 fifo_vect[5][9],
						 fifo_vect[5][8],
						 fifo_vect[5][7],
						 fifo_vect[5][6],
						 fifo_vect[5][5],
						 fifo_vect[5][4],
						 fifo_vect[5][3],
						 fifo_vect[5][2],
						 fifo_vect[5][1],
						 fifo_vect[5][0] };
	
endmodule
