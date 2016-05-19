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

// 2x RITC correlators. v3 has dynamic INL correction (code-by-code remapping) located in the quadcorrs.
module dual_RITC_correlator_v3(
		input sysclk_i,
		input sync_i,
		input [47:0] A,
		input [47:0] B,
		input [47:0] C,
		input [47:0] D,
		input [47:0] E,
		input [47:0] F,
		output [11:0] R0_MAX,
		output [5:0] R0_MAX_CORR,
		output [11:0] R1_MAX,
		output [5:0] R1_MAX_CORR,
		
		input user_clk_i,
		input user_sel_i,
		input user_wr_i,
		input user_rd_i,
		input [11:0] user_addr_i,
		input [31:0] user_dat_i,
		output [31:0] user_dat_o,
		input sample_sel_i,
		output [31:0] sample_dat_o,
		input [1:0] train_i,
		
		input trigger_i,
		input ext_trigger_i,
		
		output[70:0] debug_o
    );


	localparam NCORRBITS = 12;
    localparam INDEXBITS = 6;
	localparam INBITS = 3;
	// Number of samples per clock.
	localparam DEMUX = 16;
	// This is the total width of a channel = 48 bits.
	localparam NBITS = INBITS*DEMUX;
	
	// Only 4 correlations currently. Note that the "old" setup used 58 correlations,
	// but those were clearly crap. So we'll have to refigure this stuff anyway.
	localparam NCORR = 64;
		
	localparam A_MAX_DELAY = 0;
	localparam B_MAX_DELAY = 30;
	localparam C_MAX_DELAY = 37;
	localparam D_MAX_DELAY = 0;
	localparam E_MAX_DELAY = 30;
	localparam F_MAX_DELAY = 37;
	
	// Divide by 16 and take ceiling.
	function integer cdiv16;
		input integer num;
		integer i;
		begin
			cdiv16 = 0;
			for (i=0;16*i<num;i=i+1) begin
				cdiv16 = cdiv16 + 1;
			end
		end
	endfunction
	
	//% Number of storage stages for A.
	localparam A_STAGES = cdiv16(A_MAX_DELAY);
    //% Number of storage stages for B.
	localparam B_STAGES = cdiv16(B_MAX_DELAY);
    //% Number of storage stages for C.
	localparam C_STAGES = cdiv16(C_MAX_DELAY);
    //% Number of storage stages for D.
	localparam D_STAGES = cdiv16(D_MAX_DELAY);
    //% Number of storage stages for E.
	localparam E_STAGES = cdiv16(E_MAX_DELAY);
    //% Number of storage stages for F.
	localparam F_STAGES = cdiv16(F_MAX_DELAY);

    //% Storage output for A.	
	wire [(A_STAGES+1)*NBITS-1:0] A_store;			// A goes from 0-15. 
    //% Storage output for B.	
	wire [(B_STAGES+1)*NBITS-1:0] B_store;		// B goes from 0-47. Offsets can be from 0->32.
    //% Storage output for C.	
	wire [(C_STAGES+1)*NBITS-1:0] C_store;		// C goes from 0-63. Offsets can be from 0->48.

    //% Storage output for D.	
	wire [(D_STAGES+1)*NBITS-1:0] D_store;			// D goes from 0-15. 
    //% Storage output for E.	
	wire [(E_STAGES+1)*NBITS-1:0] E_store;		// E goes from 0-47. Offsets can be from 0->32.
    //% Storage output for F.	
	wire [(F_STAGES+1)*NBITS-1:0] F_store;		// F goes from 0-63. Offsets can be from 0->48.

	// Dynamic corrector signals.

    //% Clock enable for DINL.
	wire dinl_ce;
	//% DINL data inputs for the quad correlations.
	wire [31:0] dinl_cdi;

    //% Reset all pedestals.
    wire ped_reset;
    //% Pedestal address.
    wire [4:0] ped_addr;
    //% Pedestal data.
    wire [47:0] ped_data;
    //% Pedestal update flag.
    wire ped_update;

    //% Correlation outputs for R0.
	wire [NCORRBITS-1:0] CORR_R0[NCORR-1:0];
    //% Correlation outputs for R1.
	wire [NCORRBITS-1:0] CORR_R1[NCORR-1:0];
    //% Concatenation of all R0 correlations into a large vector.
	wire [NCORRBITS*NCORR-1:0] CORR_R0_CONCAT;
	//% Concatenation of all R1 correlations into a large vector.
	wire [NCORRBITS*NCORR-1:0] CORR_R1_CONCAT;

    //% Max of all R0 correlations.
	wire [NCORRBITS-1:0] max_R0;
	//% Index of maximum of R0 correlations.
	wire [INDEXBITS-1:0] max_index_R0;
	//% Max of all R1 correlations.
	wire [NCORRBITS-1:0] max_R1;
	//% Index of maximum of R1 correlations.
	wire [INDEXBITS-1:0] max_index_R1;
	
	generate
		genvar ci;
		for (ci=0;ci<NCORR;ci=ci+1) begin : CORR_CONCAT
			assign CORR_R0_CONCAT[NCORRBITS*ci +: NCORRBITS] = CORR_R0[ci];
			assign CORR_R1_CONCAT[NCORRBITS*ci +: NCORRBITS] = CORR_R1[ci];
		end
	endgenerate
	
	//% Storage to keep data from previous clocks. Note that a bunch of these get merged with other registers.
	RITC_input_storage_v2 #(.NBITS(NBITS),.A_STAGES(A_STAGES),.B_STAGES(B_STAGES),.C_STAGES(C_STAGES))
												u_storage_R0(.clk_i(sysclk_i),.sync_i(sync_i),										
																 .A_i(A),.B_i(B),.C_i(C),
															    .AS_o(A_store),.BS_o(B_store),.CS_o(C_store));
	//% Storage to keep data from previous clocks. Note that a bunch of these get merged with other registers.
	RITC_input_storage_v2 #(.NBITS(NBITS),.A_STAGES(D_STAGES),.B_STAGES(E_STAGES),.C_STAGES(F_STAGES))
												u_storage_R1(.clk_i(sysclk_i),.sync_i(sync_i),
																 .A_i(D),.B_i(E),.C_i(F),
																 .AS_o(D_store),.BS_o(E_store),.CS_o(F_store));
	`define R0_SIMPLE_QUAD( type, index, achan, aoff, bchan, boff, cchan, coff ) 			                   \
		quad_corr_v11_``type u_r0quadcorr``index ( .clk(sysclk_i),			  					               \
																 .sync(sync_i),			  					   \
																 .cdi(dinl_cdi[index/4]),.ce(dinl_ce),                  \
																 .A( achan``_store[ INBITS*aoff +: NBITS ]),   \
																 .B( bchan``_store[ INBITS*boff +: NBITS ]),   \
																 .C( cchan``_store[ INBITS*coff +: NBITS ]),   \
																 .ped_clk_i(user_clk_i),                       \
																 .ped_rst_i(ped_reset),                        \
																 .ped_i(ped_data),                             \
																 .ped_update_i(ped_update && (ped_addr[3:0] == index/4) && !ped_addr[4]), \
																 .CORR0( CORR_R0[ index ] ),				   \
																 .CORR1( CORR_R0[ index + 1 ] ),			   \
																 .CORR2( CORR_R0[ index + 2 ] ),			   \
																 .CORR3( CORR_R0[ index + 3 ] ))
	`define R1_SIMPLE_QUAD( type, index, achan, aoff, bchan, boff, cchan, coff ) 			\
		quad_corr_v11_``type u_r1quadcorr``index ( .clk(sysclk_i),			  					\
																 .sync(sync_i),			  					\
																 .cdi(dinl_cdi[index/4+16]),.ce(dinl_ce),               \
																 .A( achan``_store[ INBITS*aoff +: NBITS ]), \
																 .B( bchan``_store[ INBITS*boff +: NBITS ]), \
																 .C( cchan``_store[ INBITS*coff +: NBITS ]), \
																 .ped_clk_i(user_clk_i),                       \
                                                                 .ped_rst_i(ped_reset),                        \
                                                                 .ped_i(ped_data),                             \
                                                                 .ped_update_i(ped_update && (ped_addr[3:0] == index/4) && ped_addr[4]), \
																 .CORR0( CORR_R1[ index ] ),				\
																 .CORR1( CORR_R1[ index + 1 ] ),			\
																 .CORR2( CORR_R1[ index + 2 ] ),			\
																 .CORR3( CORR_R1[ index + 3 ] ))

	// treat R0 as upper, R1 as lower right now
	`R0_SIMPLE_QUAD( typeA,  0, A,  0, C,  2, B,  3 );
	`R0_SIMPLE_QUAD( typeA,  4, A,  0, B,  5, C,  4 );
	`R0_SIMPLE_QUAD( typeA,  8, A,  0, B,  7, C,  6 );
	`R0_SIMPLE_QUAD( typeB, 12, A,  0, B,  9, C,  8 );
	`R0_SIMPLE_QUAD( typeA, 16, A,  0, C, 11, B, 10 );
	`R0_SIMPLE_QUAD( typeA, 20, A,  0, B, 12, C, 13 );
	`R0_SIMPLE_QUAD( typeA, 24, A,  0, B, 14, C, 15 );
	`R0_SIMPLE_QUAD( typeA, 28, A,  0, C, 18, B, 15 );
	`R0_SIMPLE_QUAD( typeA, 32, A,  0, C, 20, B, 17 );
    `R0_SIMPLE_QUAD( typeA, 36, A,  0, B, 19, C, 22 );
    `R0_SIMPLE_QUAD( typeB, 40, A,  0, B, 21, C, 24 );
    `R0_SIMPLE_QUAD( typeA, 44, A,  0, C, 27, B, 22 );
    `R0_SIMPLE_QUAD( typeA, 48, A,  0, B, 24, C, 29 );
    `R0_SIMPLE_QUAD( typeA, 52, A,  0, B, 26, C, 31 );
    `R0_SIMPLE_QUAD( typeA, 56, A,  0, C, 34, B, 27 );
    `R0_SIMPLE_QUAD( typeA, 60, A,  0, B, 29, C, 36 );

	`R1_SIMPLE_QUAD( typeA,  0, D,  0, E,  7, F,  5 );
	`R1_SIMPLE_QUAD( typeA,  4, D,  0, F,  8, E,  8 );
	`R1_SIMPLE_QUAD( typeC,  8, D,  0, E, 10, F, 10 );
	`R1_SIMPLE_QUAD( typeA, 12, D,  0, E, 12, F, 12 );
	`R1_SIMPLE_QUAD( typeA, 16, D,  0, F, 15, E, 13 );
	`R1_SIMPLE_QUAD( typeC, 20, D,  0, E, 15, F, 17 );
	`R1_SIMPLE_QUAD( typeA, 24, D,  0, E, 17, F, 19 );
	`R1_SIMPLE_QUAD( typeA, 28, D,  0, F, 22, E, 18 );
    `R1_SIMPLE_QUAD( typeA, 32, D,  0, E, 20, F, 24 );
    `R1_SIMPLE_QUAD( typeB, 36, D,  0, E, 22, F, 26 );
    `R1_SIMPLE_QUAD( typeA, 40, D,  0, E, 23, F, 29 );
    `R1_SIMPLE_QUAD( typeA, 44, D,  0, F, 32, E, 24 );

    //% Compare all R0 correlations.
	RITC_compare_tree_by4 #(.NUM_CORR(NCORR),.NUM_BITS(NCORRBITS)) u_compare_R0(.clk_i(sysclk_i),
	                                                                            .train_i(train_i[1]),
																				.corr_i(CORR_R0_CONCAT),
																				.maxcorr_o(max_index_R0),
																				.max_o(max_R0));
    //% Compare all R1 correlations.
	RITC_compare_tree_by4 #(.NUM_CORR(NCORR),.NUM_BITS(NCORRBITS)) u_compare_R1(.clk_i(sysclk_i),
	                                                                            .train_i(train_i[0]),
																				.corr_i(CORR_R1_CONCAT),
																				.maxcorr_o(max_index_R1),
																				.max_o(max_R1));
//	assign debug_o = {max_R1, max_R0};
	assign R0_MAX = max_R0;
	assign R0_MAX_CORR = max_index_R0;
	assign R1_MAX = max_R1;
	assign R1_MAX_CORR = max_index_R1;
	
	wire [70:0] storage_debug;
	
    //% Sample ('event') storage and triggering.
	RITC_sample_storage_v2 u_storage(.A(A),.B(B),.C(C),.D(D),.E(E),.F(F),.sysclk_i(sysclk_i),.sync_i(sync_i),
	                                   .dinl_cdi_o(dinl_cdi),
	                                   .dinl_ce_o(dinl_ce),
	                                   .ped_rst_o(ped_reset),
	                                   .ped_update_o(ped_update),
	                                   .ped_o(ped_data),
	                                   .ped_addr_o(ped_addr),
	                                   .trigger_i(trigger_i),
	                                   .ext_trigger_i(ext_trigger_i),
                                        .user_clk_i(user_clk_i),
                                        .user_addr_i(user_addr_i),
                                        .user_sel_i(user_sel_i),
                                        .sample_sel_i(sample_sel_i),
                                        .user_rd_i(user_rd_i),
                                        .user_wr_i(user_wr_i),
                                        .user_dat_i(user_dat_i),
                                        .user_dat_o(user_dat_o),
                                        .sample_dat_o(sample_dat_o),
                                        .debug_o(storage_debug));
    assign debug_o = storage_debug;
endmodule
