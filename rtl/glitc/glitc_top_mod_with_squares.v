`include "glitc_macros.vh"
	
// The GLITC top level module operates with 16 inputs at a time.
module top_glitc_mod_with_square( clk, A, B, C, sum_max , pos_sum_max, zero_delay, map_18_delay, A_18, B_18, C_18, A_45, B_45, C_45, 
//						A_filtered_debug, B_filtered_debug, C_filtered_debug,
//								res_squarer_0,
//		res_squarer_1,
//		res_squarer_2,
//		res_squarer_3,
//		res_squarer_4,
//		res_squarer_5,
//		res_squarer_6,
//		res_squarer_7,
//		res_squarer_8,
//		res_squarer_9,
//		res_squarer_10,
//		res_squarer_11,
//		res_squarer_12,
//		res_squarer_13,
//		res_squarer_14,
//		res_squarer_15,
//                  address, data_i, data_o, sel_i, wr_i, rd_i, ack_o,
//						VCDL, VCDL_OUT, 
						powerA, powerB, powerC, sumA, sumB, sumC, new_power_flag, acc_cnt_debug );
	parameter DEMUX = 16;
	parameter NBITS = 3;
	parameter NCORR = 58;
	localparam NCBITS = DEMUX*NBITS;
	input clk;
	input [DEMUX*NBITS-1:0] A;
	input [DEMUX*NBITS-1:0] B;
	input [DEMUX*NBITS-1:0] C;
//	input [13:0] address;
//	input [7:0] data_i;
//	output [7:0] data_o;
//	input sel_i;
//	input wr_i;
//	input rd_i;
//	output ack_o;
//	output VCDL;
//	input VCDL_OUT;
//	
//	output [DEMUX*NBITS-1:0] A_filtered_debug;
//	output [DEMUX*NBITS-1:0] B_filtered_debug;
//	output [DEMUX*NBITS-1:0] C_filtered_debug;
//
//	output  [5:0] res_squarer_0;
//	output  [5:0] res_squarer_1;
//	output  [5:0]	res_squarer_2;
//	output  [5:0]	res_squarer_3;
//	output  [5:0]	res_squarer_4;
//	output  [5:0]	res_squarer_5;
//	output  [5:0]	res_squarer_6;
//	output  [5:0]	res_squarer_7;
//	output  [5:0]	res_squarer_8;
//	output  [5:0]	res_squarer_9;
//	output  [5:0]	res_squarer_10;
//	output  [5:0]	res_squarer_11;
//	output  [5:0]	res_squarer_12;
//	output  [5:0]	res_squarer_13;
//	output  [5:0]	res_squarer_14;
//	output  [5:0]	res_squarer_15;

	output [11:0] sum_max;
	output [5:0] pos_sum_max;
	output [11:0] zero_delay;
	output [11:0] map_18_delay;
	output [47:0] A_18;
	output [47:0] B_18;
	output [47:0] C_18;
	output [47:0] A_45;
	output [47:0] B_45;
	output [47:0] C_45;
	
	output [30:0] powerA;
	output [30:0] powerB;
	output [30:0] powerC;

	output [30:0] sumA;
	output [30:0] sumB;
	output [30:0] sumC;
	output new_power_flag;
	output [23:0] acc_cnt_debug;
	
	
	
	assign data_o = {8{1'b0}};
	assign ack_o = 1'b0;
	assign VCDL = 1'b0;
	
	wire [DEMUX*NBITS-1:0] A_filtered;
	wire [DEMUX*NBITS-1:0] B_filtered;
	wire [DEMUX*NBITS-1:0] C_filtered;
	
	
	//LM this reorders the bits, as glitc requires the [0] position being the most RECENT,
	//while the "scrambling" done at the datapath puts A in 0 poisition instead od D (more recent)
	// So the order of arriving data is - from MSaddress to LSaddress:
	// D3 C3 B3 A3 D2 C2 B2 A2 D1 C1 B1 A1 D0 C0 B0 A0
	// 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
	// While it should be
	// A3 B3 C3 D3 A2 B2 C2 D2 A1 B1 C1 D1 A0 B0 C0 D0
	// 15 14 13 12 11 10  9  8  7  6  5  4  0  1  2  3
	// So we need to change X[4i+j] -> X_reordered[4i+3-j] (j ranging on A,B,C,D).
	
	
	reg [DEMUX*NBITS-1:0] A_reordered;
	reg [DEMUX*NBITS-1:0] B_reordered;
	reg [DEMUX*NBITS-1:0] C_reordered;
	
	integer ii;
	integer ij;
	integer ib;
//	always @(*)
always @(posedge clk) 
	begin
	for (ii=0; ii < 4; ii=ii+1)
	for (ij=0; ij < 4; ij=ij+1)
	for (ib=0; ib < 3; ib=ib+1)
		begin
		A_reordered[(4*ii+3-ij)*3+ib]<=A[(4*ii+ij)*3+ib];	
		B_reordered[(4*ii+3-ij)*3+ib]<=B[(4*ii+ij)*3+ib];	
		C_reordered[(4*ii+3-ij)*3+ib]<=C[(4*ii+ij)*3+ib];	
		end
	end 
	
	// These do nothing, just look at the code. Placeholders only.
//	glitc_dedisperse(.raw_i(A),.filter_o(A_filtered),.clk_i(clk));
//	glitc_dedisperse(.raw_i(B),.filter_o(B_filtered),.clk_i(clk));
//	glitc_dedisperse(.raw_i(C),.filter_o(C_filtered),.clk_i(clk));
//	glitc_dedisperse(.raw_i(A_reordered),.filter_o(A_filtered),.clk_i(clk)); //LM get the new scrambling in
//	glitc_dedisperse(.raw_i(B_reordered),.filter_o(B_filtered),.clk_i(clk));
//	glitc_dedisperse(.raw_i(C_reordered),.filter_o(C_filtered),.clk_i(clk));	
	
		assign A_filtered =A_reordered; 
		assign B_filtered =B_reordered; 
		assign C_filtered =C_reordered; 

//	assign A_filtered =A; 
//	assign B_filtered =B; 
//	assign C_filtered =C; 

	wire [NBITS-1:0] inA[DEMUX-1:0];
	wire [NBITS-1:0] inB[DEMUX-1:0];
	wire [NBITS-1:0] inC[DEMUX-1:0];
/*	
	assign inA[00] = A[ 00*NBITS +: NBITS ];
	assign inA[01] = A[ 01*NBITS +: NBITS ];
	assign inA[02] = A[ 02*NBITS +: NBITS ];
	assign inA[03] = A[ 03*NBITS +: NBITS ];
	assign inA[04] = A[ 04*NBITS +: NBITS ];
	assign inA[05] = A[ 05*NBITS +: NBITS ];
	assign inA[06] = A[ 06*NBITS +: NBITS ];
	assign inA[07] = A[ 07*NBITS +: NBITS ];
	assign inA[08] = A[ 08*NBITS +: NBITS ];
	assign inA[09] = A[ 09*NBITS +: NBITS ];
	assign inA[10] = A[ 10*NBITS +: NBITS ];
	assign inA[11] = A[ 11*NBITS +: NBITS ];
	assign inA[12] = A[ 12*NBITS +: NBITS ];
	assign inA[13] = A[ 13*NBITS +: NBITS ];
	assign inA[14] = A[ 14*NBITS +: NBITS ];
	assign inA[15] = A[ 15*NBITS +: NBITS ];

	assign inB[00] = B[ 00*NBITS +: NBITS ];
	assign inB[01] = B[ 01*NBITS +: NBITS ];
	assign inB[02] = B[ 02*NBITS +: NBITS ];
	assign inB[03] = B[ 03*NBITS +: NBITS ];
	assign inB[04] = B[ 04*NBITS +: NBITS ];
	assign inB[05] = B[ 05*NBITS +: NBITS ];
	assign inB[06] = B[ 06*NBITS +: NBITS ];
	assign inB[07] = B[ 07*NBITS +: NBITS ];
	assign inB[08] = B[ 08*NBITS +: NBITS ];
	assign inB[09] = B[ 09*NBITS +: NBITS ];
	assign inB[10] = B[ 10*NBITS +: NBITS ];
	assign inB[11] = B[ 11*NBITS +: NBITS ];
	assign inB[12] = B[ 12*NBITS +: NBITS ];
	assign inB[13] = B[ 13*NBITS +: NBITS ];
	assign inB[14] = B[ 14*NBITS +: NBITS ];
	assign inB[15] = B[ 15*NBITS +: NBITS ];

	assign inC[00] = C[ 00*NBITS +: NBITS ];
	assign inC[01] = C[ 01*NBITS +: NBITS ];
	assign inC[02] = C[ 02*NBITS +: NBITS ];
	assign inC[03] = C[ 03*NBITS +: NBITS ];
	assign inC[04] = C[ 04*NBITS +: NBITS ];
	assign inC[05] = C[ 05*NBITS +: NBITS ];
	assign inC[06] = C[ 06*NBITS +: NBITS ];
	assign inC[07] = C[ 07*NBITS +: NBITS ];
	assign inC[08] = C[ 08*NBITS +: NBITS ];
	assign inC[09] = C[ 09*NBITS +: NBITS ];
	assign inC[10] = C[ 10*NBITS +: NBITS ];
	assign inC[11] = C[ 11*NBITS +: NBITS ];
	assign inC[12] = C[ 12*NBITS +: NBITS ];
	assign inC[13] = C[ 13*NBITS +: NBITS ];
	assign inC[14] = C[ 14*NBITS +: NBITS ];
	assign inC[15] = C[ 15*NBITS +: NBITS ];
*/	
	generate
		genvar dm_i;
		for (dm_i=0;dm_i<DEMUX;dm_i=dm_i+1) begin : MAP
			assign inA[dm_i][NBITS-1:0] = A_filtered[dm_i*NBITS +: NBITS];
			assign inB[dm_i][NBITS-1:0] = B_filtered[dm_i*NBITS +: NBITS];
			assign inC[dm_i][NBITS-1:0] = C_filtered[dm_i*NBITS +: NBITS];
		end
	endgenerate
	
	// Our main goal here is to work with things only 16 at a time, building up the total sum
	// over 2 clock cycles. This is basically trading LUTs for FFs and latency, since it will require fewer
	// LUTs for each single clock, but more FFs to store the data for the extra clock required.
	// The previous design, however, was LUT-heavy and FF-poor.
	// Theoretically, so far, this should end up using ~4000 slices or so, which is less than half
	// of the previous design.
	
	// For example, corr_1 uses
	// A[31:0]
	// B[61:30]
	// C[73:42]
	// This can be built up by adding
	// A[15:0][3] and A[15:0][2]
	// B[30] is B[14][2], so add {B[14:0][2],B[15][1]} and {B[14:0][1],B[15][0]} (note a pattern?)
	// All of the correlations can be built by just summing 16 twice, so we only need to *give* them
	// 16 to sum.
	
	// Maximum/minimums:
	// Antenna A[0] is multiplied by B[30] or C[42] at maximum, or B[-4] or C[-11] at minimum.
	// This means we need to store A[0] for only 1 clock.
	// A[0]*B[30]*C[42] would use A[0][0] (the most recent A[0], with the C sample from a long time previous).
	// A[0]*B[-4]*C[-11] would use A[0][1] (the A[0] from the previous clock).
	
	//% Number of 16-entry windows to store for channel A. Only need 2.
	localparam AMAX = 2;
	// Antenna B needs 3 stages. To multiply A[0]*B[30]*C[42],
	// we would use A[0][0], B[14][1], and C[10][2].
	// We need 3 stages because A[15][0] multiplies B[13][2].
	// To multiply A[0],B[-4], and C[-11], we use A[0][1], B[12][0], and C[5][0].
	localparam BMAX = 3;
	// Antenna C needs 4 stages.
	localparam CMAX =4;
	// Note that this is decently less than in correlator_v5.vhd:
	// A contains only 32 entries (as opposed to 48).
	// B contains only 48 entries (as opposed to 84).
	// C contains only 64 entries (as opposed to 96).
	wire [NBITS-1:0] sr_A[DEMUX-1:0][AMAX-1:0];
	wire [NBITS-1:0] sr_B[DEMUX-1:0][BMAX-1:0];
	wire [NBITS-1:0] sr_C[DEMUX-1:0][CMAX-1:0];
	reg [NBITS-1:0] sreg_A[DEMUX-1:0][AMAX-2:0];
	reg [NBITS-1:0] sreg_B[DEMUX-1:0][BMAX-2:0];
	reg [NBITS-1:0] sreg_C[DEMUX-1:0][CMAX-2:0];
	generate
		genvar in_i, A_in, B_in, C_in;
		for (in_i=0;in_i<DEMUX;in_i=in_i+1) begin : INIT
			assign sr_A[in_i][0] = inA[in_i];
			assign sr_B[in_i][0] = inB[in_i];
			assign sr_C[in_i][0] = inC[in_i];
			for (A_in=1;A_in<AMAX;A_in=A_in+1) begin : ALOOP
				assign sr_A[in_i][A_in] = sreg_A[in_i][A_in-1];
			end
			for (B_in=1;B_in<BMAX;B_in=B_in+1) begin : BLOOP
				assign sr_B[in_i][B_in] = sreg_B[in_i][B_in-1];
			end
			for (C_in=1;C_in<CMAX;C_in=C_in+1) begin : CLOOP
				assign sr_C[in_i][C_in] = sreg_C[in_i][C_in-1];
			end
		end
	endgenerate
	
	integer sr_i, A_i, B_i, C_i;
	always @(posedge clk) begin
		for (sr_i=0;sr_i<DEMUX;sr_i=sr_i+1) begin
			for (A_i=1;A_i<AMAX;A_i=A_i+1) sreg_A[sr_i][A_i-1] <= sr_A[sr_i][A_i-1];
			for (B_i=1;B_i<BMAX;B_i=B_i+1) sreg_B[sr_i][B_i-1] <= sr_B[sr_i][B_i-1];
			for (C_i=1;C_i<CMAX;C_i=C_i+1) sreg_C[sr_i][C_i-1] <= sr_C[sr_i][C_i-1];
		end
	end

	// OK, so let's now map things.
	// We'll do it by hand at first.
	wire [NBITS-1:0] corr_inputA[NCORR-1:0][DEMUX-1:0];
	wire [NBITS-1:0] corr_inputB[NCORR-1:0][DEMUX-1:0];
	wire [NBITS-1:0] corr_inputC[NCORR-1:0][DEMUX-1:0];
	
	`define CMAP_INPUT_PREFIX( name ) corr_input``name
	`define CMAP_SR_PREFIX( name ) sr_``name
	`define MAP( corrnum , Astart , Bstart , Cstart ) \
		`CMAP16( A , corrnum , Astart ); \
		`CMAP16( B , corrnum , Bstart ); \
		`CMAP16( C , corrnum , Cstart )
	// The macro here needs to have some trickery added to manage the delays needed for some of
	// the correlations as well.
	// Only map the first 16 entries: obviously the next 16 entries occur one clock later.
	`MAP( 0 , 0 , 30 , 42 );
	`MAP( 1 , 0 , 29 , 41 );
	`MAP( 2 , 0 , 29 , 40 );
	`MAP( 3 , 0 , 28 , 39 );
	`MAP( 4 , 0 , 28 , 38 );
	`MAP( 5 , 0 , 27 , 37 );
	`MAP( 6 , 0 , 27 , 36 );
	`MAP( 7 , 0 , 26 , 36 );
	`MAP( 8 , 0 , 26 , 35 );
	`MAP( 9 , 0 , 25 , 34 );
	`MAP( 10 , 0 , 25 , 33 );
	`MAP( 11 , 0 , 24 , 32 );
	`MAP( 12 , 0 , 23 , 31 );
	`MAP( 13 , 0 , 23 , 30 );
	`MAP( 14 , 0 , 22 , 29 );
	`MAP( 15 , 0 , 22 , 28 );
	`MAP( 16 , 0 , 21 , 27 );
	`MAP( 17 , 0 , 20 , 26 );
	`MAP( 18 , 0 , 20 , 25 );
	`MAP( 19 , 0 , 19 , 24 );
	`MAP( 20 , 0 , 18 , 23 );
	`MAP( 21 , 0 , 18 , 22 );
	`MAP( 22 , 0 , 17 , 21 );
	`MAP( 23 , 0 , 17 , 20 );
	`MAP( 24 , 0 , 16 , 20 );
	`MAP( 25 , 0 , 16 , 19 );
	`MAP( 26 , 0 , 15 , 18 );
	`MAP( 27 , 0 , 15 , 17 );
	`MAP( 28 , 0 , 14 , 16 );
	`MAP( 29 , 0 , 13 , 15 );
	`MAP( 30 , 0 , 13 , 14 );
	`MAP( 31 , 0 , 12 , 13 );
	`MAP( 32 , 0 , 12 , 12 );
	`MAP( 33 , 0 , 11 , 11 );
	`MAP( 34 , 0 , 10 , 10 );
	`MAP( 35 , 0 , 9 , 9 );
	`MAP( 36 , 0 , 9 , 8 );
	`MAP( 37 , 0 , 8 , 7 );
	`MAP( 38 , 0 , 8 , 6 );
	`MAP( 39 , 0 , 7 , 5 );
	`MAP( 40 , 0 , 6 , 4 );
	`MAP( 41 , 0 , 6 , 3 );
	`MAP( 42 , 0 , 5 , 3 );
	`MAP( 43 , 0 , 5 , 2 );
	`MAP( 44 , 0 , 4 , 1 );
//	`MAP( 45 , 0 , 4 , 0 ); //LM:Original
	`MAP( 45 , 0 , 0 , 0 ); //LM: new - to try testing at one specific delay line 
	`MAP( 46 , 16, 19, 15 ); // DELAY=0 starts at corrnum = 46
	`MAP( 47 , 16, 18, 14 );
	`MAP( 48 , 16, 18, 13 );
	`MAP( 49 , 16, 17, 12 );
	`MAP( 50 , 16, 17, 11 );
	`MAP( 51 , 16, 16, 11 );
	`MAP( 52 , 16, 15, 10 );
	`MAP( 53 , 16, 15, 9 );
	`MAP( 54 , 16, 14, 8 );
	`MAP( 55 , 16, 14, 7 );
	`MAP( 56 , 16, 13, 6 );
	`MAP( 57 , 16, 12, 5 );
//	`MAP( A , 0 , 0 , 0 );  // corrA[0] = A[15:0]
//	`MAP( B , 0 , 14 , 1 ); // corrB[0] = B[45:30]
//	`MAP( C , 0 , 10 , 2 ); // corrC[0] = C[57:42]
//	
//	`MAP( A , 1 , 0 , 0 );  // corrA[1] = A[15:0]
//	`MAP( B , 1 , 13 , 1 ); // corrB[1] = B[44:29]
//	`MAP( C , 1 , 9 , 2 );  // corrC[1] = C[56:41]
//	
//	`MAP( A , 2 , 0 , 0 );
//	`MAP( B , 2 , 13 , 1 );
//	`MAP( C , 2 , 8 , 2 );
//
//	// corr4 A[15:0] , B[43:28], C[54:39]
//	`MAP( A , 3 , 0 , 0 );
//	`MAP( B , 3 , 12 , 1 );
//	`MAP( C , 3 , 7 , 2 );
//	
//	// corr5 A[15:0] , B[43:28], C[53:38]
//	`MAP( A , 4 , 0 , 0 );
//	`MAP( B , 4 , 12 , 1 );
//	`MAP( C , 4 , 6 , 2 );
//	
//	// corr6 A[15:0] , B[42:27], C[52:37]
//	`MAP( A , 5 , 0 , 0 );
//	`MAP( B , 5 , 11 , 1 );
//	`MAP( C , 5 , 5 , 2 );
//	
//	// corr7 A[15:0] , B[42:27], C[51:36]
//	`MAP( A , 6 , 0 , 0 );
//	`MAP( B , 6 , 11 , 1 );
//	`MAP( C , 6 , 4 , 2 );
//	
//	// corr8 A[15:0] , B[41:26], C[51:36]
//	`MAP( A , 7 , 0 , 0 );
//	`MAP( B , 7 , 10 , 1 );
//	`MAP( C , 7 , 4 , 2 );
//	
//	// corr9 A[15:0] , B[41:26], C[50:35]
//	`MAP( A , 8 , 0 , 0 );
//	`MAP( B , 8 , 10 , 1 );
//	`MAP( C , 8 , 3 , 2 );
//
//	// corr10 A[15:0] , B[40:25], C[49:34]
//	`MAP( A , 9 , 0 , 0 );
//	`MAP( B , 9 , 9 , 1 );
//	`MAP( C , 9 , 2 , 2 );
//
//	// corr11 A[15:0] , B[40:25], C[48:33]
//	`MAP( A , 10 , 0 , 0 );
//	`MAP( B , 10 , 9 , 1 );
//	`MAP( C , 10 , 1 , 2 );
//	
//	// corr12 A[15:0] , B[39:24], C[47:32]
//	`MAP( A , 11 , 0 , 0 );
//	`MAP( B , 11 , 8 , 1 );
//	`MAP( C , 11 , 0 , 2 );
//	
//	// corr13 A[15:0] , B[38:23], C[46:31]
//	`MAP( A , 12 , 0 , 0 );
//	`MAP( B , 12 , 7 , 1 );
//	`MAP( C , 12 , 15 , 1 );
//	
//	// corr14 A[15:0] , B[38:23], C[45:30]
//	`MAP( A , 13 , 0 , 0 );
//	`MAP( B , 13 , 7 , 1 );
//	`MAP( C , 13 , 14 , 1 );
//	
//	// corr15 A[15:0] , B[37:22], C[44:29]
//	`MAP( A , 14 , 0 , 0 );
//	`MAP( B , 14 , 6 , 1 );
//	`MAP( C , 14 , 13 , 1 );
//	
//	// corr16 A[15:0] , B[37:22], C[43:28]
//	`MAP( A , 15 , 0 , 0 );
//	`MAP( B , 15 , 6 , 1 );
//	`MAP( C , 15 , 12 , 1 );
//	
//	// corr17 A[15:0] , B[36:21], C[42:27]
//	`MAP( A , 16 , 0 , 0 );
//	`MAP( B , 16 , 5 , 1 );
//	`MAP( C , 16 , 11 , 1 );
//	
//	// corr18 A[15:0] , B[35:20], C[41:26]
//	`MAP( A , 17 , 0 , 0 );
//	`MAP( B , 17 , 4 , 1 );
//	`MAP( C , 17 , 10 , 1 );
//	
//	// corr19 A[15:0] , B[35:20], C[40:25]
//	`MAP( A , 18 , 0 , 0 );
//	`MAP( B , 18 , 4 , 1 );
//	`MAP( C , 18 , 9 , 1 );
//	
//	// corr20 A[15:0] , B[34:19], C[39:24]
//	`MAP( A , 19 , 0 , 0 );
//	`MAP( B , 19 , 3 , 1 );
//	`MAP( C , 19 , 8 , 1 );
//	
//	// corr21 A[15:0] , B[33:18], C[38:23]
//	`MAP( A , 20 , 0 , 0 );
//	`MAP( B , 20 , 2 , 1 );
//	`MAP( C , 20 , 7 , 1 );
//	
//	// corr22 A[15:0] , B[33:18], C[37:22]
//	`MAP( A , 21 , 0 , 0 );
//	`MAP( B , 21 , 2 , 1 );
//	`MAP( C , 21 , 6 , 1 );
//	
//	// corr23 A[15:0], B[32:17], C[36:21]
//	`MAP( A , 22 , 0 , 0 );
//	`MAP( B , 22 , 1 , 1 );
//	`MAP( C , 22 , 5 , 1 );
//	
//	// corr24 A[15:0], B[32:17], C[35:20]
//	`MAP( A , 23 , 0 , 0 );
//	`MAP( B , 23 , 1 , 1 );
//	`MAP( C , 23 , 4 , 1 );
//	
//	// corr25 A[15:0], B[31:16], C[35:20]
//	`MAP( A , 24 , 0 , 0 );
//	`MAP( B , 24 , 0 , 1 );
//	`MAP( C , 24 , 4 , 1 );
//	
//	// corr26 A[15:0], B[31:16], C[34:19]
//	`MAP( A , 25 , 0 , 0 );
//	`MAP( B , 25 , 0 , 1 );
//	`MAP( C , 25 , 3 , 1 );
//	
//	// corr27 A[15:0], B[30:15], C[33:18]
//	`MAP( A , 26 , 0 , 0 );
//	`MAP( B , 26 , 15 , 0 );
//	`MAP( C , 26 , 2 , 1 );
//	
//	// corr28 A[15:0], B[30:15], C[32:17]
//	`MAP( A , 27 , 0 , 0 );
//	`MAP( B , 27 , 15, 0 );
//	`MAP( C , 27 , 1 , 1 );
//	
//	// corr29 A[15:0], B[29:14], C[31:16]
//	`MAP( A , 28 , 0 , 0 );
//	`MAP( B , 28 , 14 , 0 );
//	`MAP( C , 28 , 0 , 1 );
//	
//	// corr30 A[15:0], B[28:13], C[30:15]
//	`MAP( A , 29 , 0 , 0 );
//	`MAP( B , 29 , 13 , 0 );
//	`MAP( C , 29 , 15 , 0 );
//	
//	// corr31 A[15:0], B[28:13], C[29:14]
//	`MAP( A , 30 , 0 , 0 );
//	`MAP( B , 30 , 13 , 0 );
//	`MAP( C , 30 , 14 , 0 );
//	
//	// corr32 A[15:0], B[27:12], C[28:13]
//	`MAP( A , 31 , 0 , 0 );
//	`MAP( B , 31 , 12 , 0 );
//	`MAP( C , 31 , 13 , 0 );
//	
	`undef MAP
		
	wire [NCBITS-1:0] cinA[NCORR-1:0];
	wire [NCBITS-1:0] cinB[NCORR-1:0];
	wire [NCBITS-1:0] cinC[NCORR-1:0];
	

	wire [11:0] corr_value[NCORR-1:0];
	generate
		genvar v_i;
		for (v_i=0;v_i<NCORR;v_i=v_i+1) begin : VL
			`VEC16( corr_inputA[v_i], cinA[v_i] , NBITS );
			`VEC16( corr_inputB[v_i], cinB[v_i] , NBITS );
			`VEC16( corr_inputC[v_i], cinC[v_i] , NBITS );
	
			if (NCORR < 46) 
			begin : DELAYED
				single_corr_v5 #(.DELAY(1)) 
					corr(.clk(clk), .A(cinA[v_i]), .B(cinB[v_i]), .C(cinC[v_i]), .CORR(corr_value[v_i]));
			end 
			else begin : NODELAY
				single_corr_v5 #(.DELAY(0))
					corr(.clk(clk), .A(cinA[v_i]), .B(cinB[v_i]), .C(cinC[v_i]), .CORR(corr_value[v_i]));
			end
		end 
	endgenerate
//		single_corr_v5 #(.DELAY(0)) 
//					corr(.clk(clk), .A(cinA[18]), .B(cinB[18]), .C(cinC[18]),
//		.res_squarer_0(res_squarer_0),
//		.res_squarer_1(res_squarer_1),
//		.res_squarer_2(res_squarer_2),
//		.res_squarer_3(res_squarer_3),
//		.res_squarer_4(res_squarer_4),
//		.res_squarer_5(res_squarer_5),
//		.res_squarer_6(res_squarer_6),
//		.res_squarer_7(res_squarer_7),
//		.res_squarer_8(res_squarer_8),
//		.res_squarer_9(res_squarer_9),
//		.res_squarer_10(res_squarer_10),
//		.res_squarer_11(res_squarer_11),
//		.res_squarer_12(res_squarer_12),
//		.res_squarer_13(res_squarer_13),
//		.res_squarer_14(res_squarer_14),
//		.res_squarer_15(res_squarer_15));
	// We have 58 correlations. Compare in a tree...
	reg [11:0] max_1[28:0];  // 58/2 = 29
	reg [11:0] max_2[14:0];  // 29/2 = 15
	reg [11:0] max_3[7:0];   // 15/2 = 8
	reg [11:0] max_4[3:0];
	reg [11:0] max_5[1:0];
	reg [11:0] max_6[0:0];

	reg [5:0] pos_max_1[28:0];  // 58/2 = 29
	reg [5:0] pos_max_2[14:0];  // 29/2 = 15
	reg [5:0] pos_max_3[7:0];   // 15/2 = 8
	reg [5:0] pos_max_4[3:0];
	reg [5:0] pos_max_5[1:0];
	reg [5:0] pos_max_6[0:0];
	`define MAX( x , y ) ( ( x ) > ( y ) ) ? ( x ) : ( y )
	`define IS_MAX( x , y ) ( ( x ) > ( y ) ) 

	integer m1,m2,m3,m4,m5;
	always @(posedge clk) begin
			for (m1=0;m1<29;m1=m1+1)
				begin
				max_1[m1] <= `MAX( corr_value[2*m1] , corr_value[2*m1+1] );
				pos_max_1[m1] <= `IS_MAX( corr_value[2*m1] , corr_value[2*m1+1] ) ? 2*m1 : 2*m1+1;
				end
			for (m2=0;m2<14;m2=m2+1)
				begin
				max_2[m2] <= `MAX( max_1[2*m2] , max_1[2*m2+1]);
				pos_max_2[m2] <= `IS_MAX( max_1[2*m2] , max_1[2*m2+1] ) ? pos_max_1[2*m2] : pos_max_1[2*m2+1];				
				end
			pos_max_2[14]<=pos_max_1[28];
			max_2[14] <= max_1[28];
			for (m3=0;m3<7;m3=m3+1)
				begin
				max_3[m3] <= `MAX( max_2[2*m3] , max_2[2*m3+1]);
				pos_max_3[m3] <= `IS_MAX( max_1[2*m3] , max_1[2*m3+1] ) ? pos_max_2[2*m3] : pos_max_2[2*m3+1];				
				end			
			pos_max_3[7]<=pos_max_2[14];
			max_3[7] <= max_2[14];
			for (m4=0;m4<4;m4=m4+1)
				begin
				max_4[m4] <= `MAX( max_3[2*m4] , max_3[2*m4+1]);
				pos_max_4[m4] <= `IS_MAX( max_3[2*m4] , max_3[2*m4+1] ) ? pos_max_3[2*m4] : pos_max_3[2*m4+1];				
				end			
			for (m5=0;m5<2;m5=m5+1)
				begin
				max_5[m5] <= `MAX( max_4[2*m5] , max_4[2*m5+1]);
				pos_max_5[m5] <= `IS_MAX( max_4[2*m5] , max_4[2*m5+1] ) ? pos_max_4[2*m5] : pos_max_4[2*m5+1];				
				end					
			max_6[0] <= `MAX( max_5[0] , max_5[1] );
			pos_max_6[0] <= `IS_MAX( max_5[0] , max_5[1] ) ? pos_max_5[0] : pos_max_5[1];				
			
	end
	
	
	square_accumulate 	powA(.clk(clk), .in_vec(A_filtered), .power(powerA), .sum(sumA), .new_power_flag(new_power_flag), .acc_cnt_debug(acc_cnt_debug));
	square_accumulate 	powB(.clk(clk), .in_vec(B_filtered), .power(powerB), .sum(sumB));
	square_accumulate 	powC(.clk(clk), .in_vec(C_filtered), .power(powerC), .sum(sumC));
	
		
	
	assign sum_max = max_6[0];
	assign pos_sum_max = pos_max_6[0];
	assign zero_delay = corr_value[45];
	assign map_18_delay = corr_value[18];
	assign A_18 = cinA[18];
	assign B_18 = cinB[18];
	assign C_18 = cinC[18];
	assign A_45 = cinA[45];
	assign B_45 = cinB[45];
	assign C_45 = cinC[45];
	assign A_filtered_debug = 	A_filtered;
	assign B_filtered_debug = 	B_filtered;
	assign C_filtered_debug = 	C_filtered;


endmodule
