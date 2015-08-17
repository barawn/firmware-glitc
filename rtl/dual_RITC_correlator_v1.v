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
module dual_RITC_correlator_v1(
		input sysclk_i,
		input sync_i,
		input [47:0] A,
		input [47:0] B,
		input [47:0] C,
		input [47:0] D,
		input [47:0] E,
		input [47:0] F,
		output [10:0] R0_MAX,
		output [10:0] R1_MAX,
		
		input user_clk_i,
		input user_sel_i,
		input user_wr_i,
		input user_rd_i,
		input [12:0] user_addr_i,
		input [31:0] user_dat_i,
		output [31:0] user_dat_o,
		input sample_sel_i,
		output [31:0] sample_dat_o,
		
		output[63:0] debug_o
    );

	localparam NCORRBITS = 10;
	// For the correlations, we need to store 2, 3, and 4 clocks worth of data.
	localparam NBITS = 48;
	// Only 4 correlations currently. Note that the "old" setup used 58 correlations,
	// but those were clearly crap. So we'll have to refigure this stuff anyway.
	localparam NCORR = 8;
	
	wire [2*NBITS-1:0] A_store;
	wire [3*NBITS-1:0] B_store;
	wire [4*NBITS-1:0] C_store;
	wire [2*NBITS-1:0] D_store;
	wire [3*NBITS-1:0] E_store;
	wire [4*NBITS-1:0] F_store;

	wire [NCORRBITS-1:0] CORR_R0[NCORR-1:0];
	wire [NCORRBITS-1:0] CORR_R1[NCORR-1:0];
	wire [NCORRBITS*NCORR-1:0] CORR_R0_CONCAT;
	wire [NCORRBITS*NCORR-1:0] CORR_R1_CONCAT;
	wire [NCORRBITS-1:0] max_R0;
	wire [NCORRBITS-1:0] max_R1;
	generate
		genvar ci;
		for (ci=0;ci<NCORR;ci=ci+1) begin : CORR_CONCAT
			assign CORR_R0_CONCAT[NCORRBITS*ci +: NCORRBITS] = CORR_R0[ci];
			assign CORR_R1_CONCAT[NCORRBITS*ci +: NCORRBITS] = CORR_R1[ci];
		end
	endgenerate
	
	
	RITC_input_storage u_storage_R0(.clk_i(sysclk_i),.A_i(A),.B_i(B),.C_i(C),
															    .AS_o(A_store),.BS_o(B_store),.CS_o(C_store));
	RITC_input_storage u_storage_R1(.clk_i(sysclk_i),.A_i(D),.B_i(E),.C_i(F),
																 .AS_o(D_store),.BS_o(E_store),.CS_o(F_store));

	// Note that this is a lot simpler than the complicated CMAP16/MAP/etc. macros.
	// This is because I realized that with the vectorized inputs, you can just offset the whole damn thing.
	// An offset of 0 means you map 0 - 47 (16 samples)
	// An offset of 1 means you map 3 - 49 (16 samples) etc.
	`define R0_QUAD_CORRELATOR( a , b , c , d , e , f,  g, h, i, j, k, l, m, n, o, p) 	\
		quad_corr_v7 u_r0quadcorr``a( .clk(sysclk_i), 													\
											 .A0( A_store[ 3*b +: NBITS ] ),								\
											 .B0( B_store[ 3*c +: NBITS ] ),								\
											 .C0( C_store[ 3*d +: NBITS ] ),								\
											 .A1( A_store[ 3*f +: NBITS ] ),								\
											 .B1( B_store[ 3*g +: NBITS ] ),								\
											 .C1( C_store[ 3*h +: NBITS ] ),								\
											 .A2( A_store[ 3*j +: NBITS ] ),								\
											 .B2( B_store[ 3*k +: NBITS ] ),								\
											 .C2( C_store[ 3*l +: NBITS ] ),								\
											 .A3( A_store[ 3*n +: NBITS ] ),								\
											 .B3( B_store[ 3*o +: NBITS ] ),								\
											 .C3( C_store[ 3*p +: NBITS ] ),								\
											 .CORR0( CORR_R0[ a ] ),										\
											 .CORR1( CORR_R0[ e ] ),										\
											 .CORR2( CORR_R0[ i ] ),										\
											 .CORR3( CORR_R0[ m ] ))
	`define R1_QUAD_CORRELATOR( a , b , c , d , e , f,  g, h, i, j, k, l, m, n, o, p) 	\
		quad_corr_v7 u_r1quadcorr``a( .clk(sysclk_i), 													\
											 .A0( D_store[ 3*b +: NBITS ] ),								\
											 .B0( E_store[ 3*c +: NBITS ] ),								\
											 .C0( F_store[ 3*d +: NBITS ] ),								\
											 .A1( D_store[ 3*f +: NBITS ] ),								\
											 .B1( E_store[ 3*g +: NBITS ] ),								\
											 .C1( F_store[ 3*h +: NBITS ] ),								\
											 .A2( D_store[ 3*j +: NBITS ] ),								\
											 .B2( E_store[ 3*k +: NBITS ] ),								\
											 .C2( F_store[ 3*l +: NBITS ] ),								\
											 .A3( D_store[ 3*n +: NBITS ] ),								\
											 .B3( E_store[ 3*o +: NBITS ] ),								\
											 .C3( F_store[ 3*p +: NBITS ] ),								\
											 .CORR0( CORR_R1[ a ] ),										\
											 .CORR1( CORR_R1[ e ] ),										\
											 .CORR2( CORR_R1[ i ] ),										\
											 .CORR3( CORR_R1[ m ] ))

	`R0_QUAD_CORRELATOR( 0 , 0 , 30, 42,
								1 , 0 , 29, 41,
								2 , 0 , 29, 40,
								3 , 0 , 28, 39 );
	`R0_QUAD_CORRELATOR( 4 , 0 , 28, 38,
								5 , 0 , 27, 37,
								6 , 0 , 27, 36,
								7 , 0 , 26, 36);
	`R1_QUAD_CORRELATOR( 0 , 0 , 30, 42,
								1 , 0 , 29, 41,
								2 , 0 , 29, 40,
								3 , 0 , 28, 39 );
	`R1_QUAD_CORRELATOR( 4 , 0 , 28, 38,
								5 , 0 , 27, 37,
								6 , 0 , 27, 36,
								7 , 0 , 26, 36);

	RITC_compare_tree #(.NUM_CORR(NCORR),.NUM_BITS(NCORRBITS)) u_compare_R0(.clk_i(sysclk_i),
																					 .corr_i(CORR_R0_CONCAT),
																					 .max_o(max_R0));
	RITC_compare_tree #(.NUM_CORR(NCORR),.NUM_BITS(NCORRBITS)) u_compare_R1(.clk_i(sysclk_i),
																					 .corr_i(CORR_R1_CONCAT),
																					 .max_o(max_R1));
	//assign debug_o = {max_R1, max_R0};
	assign R0_MAX = max_R0;
	assign R1_MAX = max_R1;
	// Moron buffer storage. There's no pretrigger anything here: nothing smart, nothing intelligent, nothing.
	// Implementing a pretrigger is the next step.
	
	wire [47:0] sample_out_R0;
	wire [47:0] sample_out_R1;
	
	// We have 96 output bits, or 3 32-bit words.
	// Data is read out in chunks:
	// sample_out_R0[31:0] from 0-511
	// sample_out_R0/R1 from 512-1023
	// sample_out_R1 from 1024-1535
	// sample_out_R1/R0 from 1536-2047
	wire [31:0] STORCTRL;
	reg storage_trigger = 0;
	wire storage_done;
	reg storage_clear = 0;
	wire storage_sync_latch;
	always @(posedge user_clk_i) begin
		if (user_sel_i && user_wr_i) begin
			storage_trigger <= user_dat_i[0];
			storage_clear <= user_dat_i[2];
		end else begin
			storage_trigger <= 0;
			storage_clear <= 0;
		end
	end
	assign STORCTRL = {{28{1'b0}},storage_sync_latch,1'b0,storage_done,1'b0};
	
	assign user_dat_o = STORCTRL;
	
	wire [63:0] storage_debug_o;
	
	RITC_sample_storage u_storage(.A(A),.B(B),.C(C),.D(D),.E(E),.F(F),.sysclk_i(sysclk_i),.sync_i(sync_i),
											.trig_i(storage_trigger),
											.clear_i(storage_clear),
											.done_o(storage_done),
											.sync_latch_o(storage_sync_latch),
											.user_clk_i(user_clk_i),
											.user_addr_i(user_addr_i),
											.user_sel_i(sample_sel_i),
											.user_rd_i(user_rd_i),
											.user_wr_i(user_wr_i),
											.user_dat_o(sample_dat_o),
											.debug_o(storage_debug_o));
	assign debug_o = storage_debug_o;
	
endmodule
