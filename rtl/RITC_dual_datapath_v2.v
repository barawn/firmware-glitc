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

/** \brief Datapath controller for 2xRITCs, v2.
 *
 * RITC_dual_datapath_v2 is a controller for the datapath for 2 RITCs.
 * The 'datapath' here means everything from where the data enters until
 * it ends up as a 48-bit, 162.5 MHz bitstream.
 *
 * It also handles VCDL generation and the VCDL counter.
 *
 * Register map:
 * 0x0	: DPCTRL0[31:0]
 * 0x1	: DPCTRL1[31:0]
 * 0x2	: DPTRAINING[31:0]
 * 0x3	: DPCOUNTER[31:0]
 * 0x4	: DPIDELAY[31:0]
 *
 */
(* SHREG_EXTRACT = "NO" *)
module RITC_dual_datapath_v2(
		input SYSCLK,
		input DATACLK,
		input DATACLK_DIV2,
		input SYSCLK_DIV2_PS,
		input CLK200,
		// Training output.
		output [1:0] TRAIN_ON,
		output [1:0] VCDL,
		// Primary inputs and deserialized outputs.
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
		output valid_o,
		// Secondary inputs and clocked outputs.
		input [11:0] CH0_B,
		input [11:0] CH1_B,
		input [11:0] CH2_B,
		input [11:0] CH3_B,
		input [11:0] CH4_B,
		input [11:0] CH5_B,
		output [11:0] CH0_Q,
		output [11:0] CH1_Q,
		output [11:0] CH2_Q,
		output [11:0] CH3_Q,
		output [11:0] CH4_Q,
		output [11:0] CH5_Q,
		// Clock and duplicate inputs
		input [5:0] CLK,
		input [5:0] CLK_B,
		// Latched clock duplicate output.
		output [5:0] CLK_B_Q,
		// Global sync input
		input SYNC,
		// Interface (both IDELAY and datapath)
		input rst_i,
		input user_clk_i,
		input user_sel_i,
		input user_wr_i,
		input [3:0] user_addr_i,
		input [31:0] user_dat_i,
		output [31:0] user_dat_o,
		output [11:0] debug_o
    );
	 
	localparam NUM_CH=6;
	localparam NUM_BIT=12;
	 
	//< IDELAY loads.
	wire [11:0] data_idelay_load[5:0];
	//< REFCLK idelay load.
	wire [5:0] clock_idelay_load;
	//< Bitslip flags.
	wire [11:0] data_iserdes_bitslip[5:0];
	//< SERDES reset.
	reg serdes_reset = 0;
	//< Delayctrl reset.
	reg delayctrl_reset = 0;
	//< Delayctrl ready.
	wire delayctrl_ready;
	//< Delay inputs.
	reg [4:0] delay_in = {5{1'b0}};
	//< Delay select.
	reg [6:0] delay_bit_select = {7{1'b0}};
	//< Delay load.
	reg delay_load = 0;
	//< Training latch for every input. This is sadly very big.
	reg [7:0] train_latch[5:0][11:0];
	//< Expanded array, to fill up to powers of 2. 16 bits (12 real), 4 channels (3 real), 2 RITC
	wire [7:0] train_latch_expanded[1:0][3:0][15:0];
	//< Training sync
	reg [7:0] train_sync = {8{1'b0}};
	//< Training select
	reg [6:0] train_bit_select = {7{1'b0}};
	//< Bitslip.
	reg bitslip = 0;
	//< Training disable
	reg train_disable = 0;	
	//< Training disable in the SYSCLK domain.
	reg train_disable_SYSCLK = 0;
	//< IOFIFO resets
	reg fifo_reset = 0;
	//< IOFIFO enable
	reg fifo_enable = 0;

	//< Latched REFCLK.
	wire [5:0] refclk_q;
	
	//// REFCLK counter stuff. This grew too large,
	//// so we moved it off into its own module. These
	//// are just the interface bits.
	
	//< REFCLKs through a regional clock.
	wire [5:0] refclk_bufr;
	//< REFCLK select.
	reg [3:0] refclk_select = {4{1'b0}};
	//< Selected refclk counter.
	wire [9:0] refclk_counter;
	//< Write flag.
	wire refclk_select_wr;

	//< VCDL delay for R0.
	reg [4:0] r0_vcdl_delay = {5{1'b0}};
	//< VCDL load for R0.
	reg r0_vcdl_delay_load = 0;
	//< VCDL delay for R1.
	reg [4:0] r1_vcdl_delay = {5{1'b0}};
	//< VCDL load for R1.
	reg r1_vcdl_delay_load = 0;
	//< Initiate single VCDL pulse.
	reg vcdl_pulse_R0 = 0;
	reg vcdl_pulse_R1 = 0;
	//< VCDL pulse signal, in SYSCLK domain.
	wire vcdl_pulse_flag_SYSCLK_R0;
	wire vcdl_pulse_flag_SYSCLK_R1;
	//< Continuous VCDL.
	reg vcdl_enable_R0 = 0;
	reg vcdl_enable_R1 = 0;
	//< Continuous VCDL enable, in SYSCLK domain.
	//reg [1:0] vcdl_enable_SYSCLK = {2{1'b0}};
	reg [1:0] vcdl_enable_SYSCLK_R0 = {2{1'b0}};
	reg [1:0] vcdl_enable_SYSCLK_R1 = {2{1'b0}};

	//< Deserialized data for each bit.
	wire [47:0] data_deserdes[5:0];
	//< Latched duplicate for each bit.
	wire [11:0] ch_b_q[5:0];
	//< Deserialized data, out of the FIFO, partially vectorized.
	wire [47:0] data_buffered[5:0];
	//< Vectorized input data.
	wire [11:0] ch_in[5:0];
	//< Vectorized duplicate input data.
	wire [11:0] ch_in_b[5:0];
	
	// Register map:
	// Register 0: DPCTRL0[31:0].
	// Register 1: DPCTRL1[31:0]
	// Register 2: DPTRAINING[31:0]
	// Register 3: DPCOUNTER[31:0]
	// Register 4: DPIDELAY[31:0]
	// DPCTRL0[0] = FIFO Reset.
	// DPCTRL0[1] = FIFO Enable.
	// DPCTRL0[2] = SERDES Reset.
	// DPCTRL0[3] = DELAYCTRL Reset.
	// DPCTRL0[4] = DELAYCTRL Ready.
	//
	// DPCTRL1[4:0]  = R0 VCDL delay register
	// DPCTRL1[5]    = R0 VCDL delay load
	// DPCTRL1[12:8] = R1 VCDL delay register
	// DPCTRL1[13]   = R1 VCDL delay load
	// DPCTRL1[21:16]= Latched reference clocks.
	// DPCTRL1[28]   = R0 Single VCDL pulse.
	// DPCTRL1[29]   = R0 Continuous VCDL.
	// DPCTRL1[30]	  = R1 Single VCDL pulse.
	// DPCTRL1[31]	  = R1 Continuous VCDL.
	// 
	// DPTRAINING[31] 	= Disable training.
	// DPTRAINING[30] 	= BITSLIP the selected channel.
	// DPTRAINING[22:16] = Bit select.
	// DPTRAINING[7:0]	= Training pattern.
	//
	// DPCOUNTER[15:0]	= REFCLK counter.
	// DPCOUNTER[19:16]  = REFCLK select.
	//
	// DPIDELAY[4:0] 		= Data IDELAY register.
	// DPIDELAY[22:16] 	= Bit select.
	// DPIDELAY[31]		= Load delay.
	wire [31:0] data_out[15:0];
	assign user_dat_o = data_out[user_addr_i];

	wire [31:0] DPCTRL0;
	wire [31:0] DPCTRL1;
	wire [31:0] DPTRAINING;
	wire [31:0] DPCOUNTER;
	wire [31:0] DPIDELAY;

	assign data_out[0] = DPCTRL0;
	assign data_out[1] = DPCTRL1;
	assign data_out[2] = DPTRAINING;
	assign data_out[3] = DPCOUNTER;
	assign data_out[4] = DPIDELAY;
	assign data_out[5] = DPCTRL1;
	assign data_out[6] = DPTRAINING;
	assign data_out[7] = DPCOUNTER;
	assign data_out[8] = DPCTRL0;
	assign data_out[9] = DPCTRL1;
	assign data_out[10] = DPTRAINING;
	assign data_out[11] = DPCOUNTER;
	assign data_out[12] = DPIDELAY;
	assign data_out[13] = DPCTRL1;
	assign data_out[14] = DPTRAINING;
	assign data_out[15] = DPCOUNTER;

	assign ch_in[0] = CH0;
	assign ch_in_b[0] = CH0_B;
	assign ch_in[1] = CH1;
	assign ch_in_b[1] = CH1_B;
	assign ch_in[2] = CH2;
	assign ch_in_b[2] = CH2_B;
	assign ch_in[3] = CH3;
	assign ch_in_b[3] = CH3_B;
	assign ch_in[4] = CH4;
	assign ch_in_b[4] = CH4_B;
	assign ch_in[5] = CH5;
	assign ch_in_b[5] = CH5_B;

	integer ii,jj;
	initial begin
		for (ii=0;ii<6;ii=ii+1)
			for (jj=0;jj<12;jj=jj+1)
				train_latch[ii][jj] <= {8{1'b0}};
	end
	
	assign refclk_select_wr = user_sel_i && user_wr_i && user_addr_i == 4'd3;
	
	always @(posedge user_clk_i) begin
		// Resets.
		if (user_sel_i && user_wr_i && user_addr_i == 4'd0) begin
			fifo_reset <= user_dat_i[0];
			fifo_enable <= user_dat_i[1];
			serdes_reset <= user_dat_i[2];
			delayctrl_reset <= user_dat_i[3];
		end else begin
			fifo_reset <= 0;
			serdes_reset <= 0;
			delayctrl_reset <= 0;
		end
		// VCDL control register.
		if (user_sel_i && user_wr_i && user_addr_i == 4'd1) begin
			r0_vcdl_delay <= user_dat_i[4:0];
			r0_vcdl_delay_load <= user_dat_i[5];
			r1_vcdl_delay <= user_dat_i[12:8];
			r1_vcdl_delay_load <= user_dat_i[13];
			vcdl_pulse_R0 <= user_dat_i[28];
			vcdl_enable_R0 <= user_dat_i[29];
			vcdl_pulse_R1 <= user_dat_i[30];
			vcdl_enable_R1 <= user_dat_i[31];
		end else begin
			r0_vcdl_delay_load <= 0;
			r1_vcdl_delay_load <= 0;
		end
		// Counter select register. This is register 3.
		if (refclk_select_wr) begin
			refclk_select <= user_dat_i[19:16];
		end
		// Training bit select register.
		if (user_sel_i && user_wr_i && user_addr_i == 4'd2) begin
			train_bit_select <= user_dat_i[22:16];
			train_disable <= user_dat_i[31];
			bitslip <= user_dat_i[30];
		end else bitslip <= 0;		
		// IDELAY control register.
		if (user_sel_i && user_wr_i && user_addr_i == 4'd4) begin
			delay_in <= user_dat_i[4:0];
			delay_bit_select <= user_dat_i[22:16];
			delay_load <= user_dat_i[31];
		end else delay_load <= 0;

		if (!train_disable) 
			train_sync <= train_latch_expanded[train_bit_select[6]][train_bit_select[5:4]][train_bit_select[3:0]];
	end

	// SYSCLK logic.
	flag_sync u_vcdl_pulse_sync_R0(.in_clkA(vcdl_pulse_R0),.clkA(user_clk_i),
											.out_clkB(vcdl_pulse_SYSCLK_R0), .clkB(SYSCLK));
	flag_sync u_vcdl_pulse_sync_R1(.in_clkA(vcdl_pulse_R1),.clkA(user_clk_i),
											.out_clkB(vcdl_pulse_SYSCLK_R1), .clkB(SYSCLK));										
	
	reg vcdl_pulse_seen_R0 = 0;
	reg vcdl_pulse_seen_R1 = 0;
	(* IOB = "TRUE" *)
	reg [1:0] vcdl_out = {2{1'b0}};
	//reg vcdl_out_R0 = 0;
	//reg vcdl_out_R1 = 1'b1;

	//always @(posedge SYSCLK) begin
		//if (vcdl_pulse_SYSCLK) vcdl_pulse_seen <= 1;
		//else if (SYNC) vcdl_pulse_seen <= 0;
		
		// This is still a prototype for the full VCDL output.
		//vcdl_out <= {2{SYNC && (vcdl_enable_SYSCLK[1] || vcdl_pulse_seen) }};

		//vcdl_enable_SYSCLK <= { vcdl_enable_SYSCLK[0], vcdl_enable };
	
		//train_disable_SYSCLK <= train_disable;
	//end
	
	always @(posedge SYSCLK) begin
		if (vcdl_pulse_SYSCLK_R0) vcdl_pulse_seen_R0 <= 1;
		else if (SYNC) vcdl_pulse_seen_R0 <= 0;
		
		if (vcdl_pulse_SYSCLK_R1) vcdl_pulse_seen_R1 <= 1;
		else if (SYNC) vcdl_pulse_seen_R1 <= 0;
		
		vcdl_out[0] <={SYNC & (vcdl_enable_SYSCLK_R0[1] || vcdl_pulse_seen_R0)};
		vcdl_enable_SYSCLK_R0 <= { vcdl_enable_SYSCLK_R0[0], vcdl_enable_R0};
		
		vcdl_out[1] <={SYNC & (vcdl_enable_SYSCLK_R0[1] || vcdl_pulse_seen_R1)};
		vcdl_enable_SYSCLK_R1 <= { vcdl_enable_SYSCLK_R0[0], vcdl_enable_R1};
		
		train_disable_SYSCLK <= train_disable;
	end

	generate
		genvar i_bit, j_ch;
		for (j_ch=0;j_ch<NUM_CH;j_ch=j_ch+1) begin : CH_LOOP
			for (i_bit=0;i_bit<NUM_BIT;i_bit=i_bit+1) begin : BIT_LOOP
				// bit_select[3:0] == bit (from 0-11, 15 is special)
				// bit_select[6:4] == channel (from 0-5)
				assign data_idelay_load[j_ch][i_bit] = 
					delay_load && (delay_bit_select[3:0] == i_bit) && (delay_bit_select[6:4]==j_ch);
				assign data_iserdes_bitslip[j_ch][i_bit] = 
					bitslip && (train_bit_select[3:0] == i_bit) && (train_bit_select[6:4]==j_ch);
				// Data path for this bit.
				glitc_data_path_wrapper u_dp(.SYSCLK(SYSCLK),.DATACLK(DATACLK),
													  .DATACLK_DIV2(DATACLK_DIV2),.SYSCLK_DIV2_PS(SYSCLK_DIV2_PS),
													  .IN_P(ch_in[j_ch][i_bit]), .IN_N(ch_in_b[j_ch][i_bit]),
													  .clk_i(user_clk_i),
													  .delay_clk_i(delay_in),
													  .load_clk_i(data_idelay_load[j_ch][i_bit]),
													  .bitslip_clk_i(data_iserdes_bitslip[j_ch][i_bit]),
													  .serdes_rst_clk_i(serdes_reset),

													  .serdes_DATACLK_DIV2_o(data_deserdes[j_ch][4*i_bit +: 4]),
													  .q_SYSCLK_DIV2_PS_o(ch_b_q[j_ch][i_bit]));
				always @(posedge SYSCLK) begin
					if (!train_disable && valid_o) begin
						if (SYNC) train_latch[j_ch][i_bit][7:4] <= data_buffered[j_ch][4*i_bit +: 4];
						else		 train_latch[j_ch][i_bit][3:0] <= data_buffered[j_ch][4*i_bit +: 4];
					end
				end
				if (j_ch < 3) begin : R0
					assign train_latch_expanded[0][j_ch][i_bit] = train_latch[j_ch][i_bit];
				end else begin : R1
					assign train_latch_expanded[1][j_ch-3][i_bit] = train_latch[j_ch][i_bit];
				end
			end
			glitc_clock_path_wrapper u_cp(.SYSCLK_DIV2_PS(SYSCLK_DIV2_PS),
													.IN_P(CLK[j_ch]),.IN_N(CLK_B[j_ch]),
													.clk_i(user_clk_i),
													.delay_clk_i(delay_in),
													.load_clk_i(clock_idelay_load[j_ch]),
													
													.p_bufr_o(refclk_bufr[j_ch]),
													.p_q_o(refclk_q[j_ch]),
													.n_q_o(CLK_B_Q[j_ch]));													

			assign clock_idelay_load[j_ch] = 
				delay_load && (delay_bit_select[3:0] == 4'hF) && (delay_bit_select[6:4] == j_ch);
		end
		for (i_bit=12;i_bit<16;i_bit=i_bit+1) begin : EXPAND
			assign train_latch_expanded[0][3][i_bit] = {8{1'b0}};
			assign train_latch_expanded[1][3][i_bit] = {8{1'b0}};
		end
	endgenerate
	// OK, we now have a bucketload of deserialized data, in the DATACLK_DIV2 domain.
	// We need to get it into the SYSCLK domain.
	GLITC_datapath_buffers u_buffers(.rst_i(fifo_reset),
												.en_i(fifo_enable),
												.valid_o(valid_o),
												.DATACLK_DIV2(DATACLK_DIV2),
												.SYSCLK(SYSCLK),
												.IN0(data_deserdes[0]),
												.IN1(data_deserdes[1]),
												.IN2(data_deserdes[2]),
												.IN3(data_deserdes[3]),
												.IN4(data_deserdes[4]),
												.IN5(data_deserdes[5]),
												.OUT0(data_buffered[0]),
												.OUT1(data_buffered[1]),
												.OUT2(data_buffered[2]),
												.OUT3(data_buffered[3]),
												.OUT4(data_buffered[4]),
												.OUT5(data_buffered[5]));												
	// Clock counters.
	GLITC_refclk_counters u_counters(.clk_i(user_clk_i),
												.SYSCLK(SYSCLK),
												.refclk_bufr_i(refclk_bufr),
												.refclk_select_i(refclk_select),
												.refclk_select_wr_i(refclk_select_wr),
												.refclk_count_o(refclk_counter));

	// IDELAYCTRL. Only one for whole project. Map replicates the rest.
	IDELAYCTRL u_idelayctrl(.REFCLK(CLK200),.RST(delayctrl_reset),.RDY(delayctrl_ready));

	// Register definitions.
	// DPCTRL0
	assign DPCTRL0[31:5] = {27{1'b0}};
	assign DPCTRL0[4] = delayctrl_ready;
	assign DPCTRL0[3:2] = 2'b00;
	assign DPCTRL0[1] = fifo_enable;
	assign DPCTRL0[0] = 1'b0;
	// DPCTRL1
	assign DPCTRL1 = {vcdl_enable_R0,vcdl_enable_R1,{6{1'b0}},refclk_q,{3{1'b0}},r1_vcdl_delay,{3{1'b0}},r0_vcdl_delay};
	// DPTRAINING
	assign DPTRAINING = {train_disable,{9{1'b0}},train_bit_select,{8{1'b0}},train_sync};
	// DPCOUNTER
	assign DPCOUNTER = {{12{1'b0}},refclk_select,{6{1'b0}},refclk_counter};
	// DPIDELAY
	assign DPIDELAY = {{9{1'b0}},delay_bit_select,{11{1'b0}},delay_in};
	
	assign CH0_Q = ch_b_q[0];
	assign CH1_Q = ch_b_q[1];
	assign CH2_Q = ch_b_q[2];
	assign CH3_Q = ch_b_q[3];
	assign CH4_Q = ch_b_q[4];
	assign CH5_Q = ch_b_q[5];
	
	assign CH0_OUT = data_buffered[0];
	assign CH1_OUT = data_buffered[1];
	assign CH2_OUT = data_buffered[2];
	assign CH3_OUT = data_buffered[3];
	assign CH4_OUT = data_buffered[4];
	assign CH5_OUT = data_buffered[5];

	assign TRAIN_ON = {2{train_disable}};

	assign VCDL = vcdl_out;
	assign debug_o[0] = vcdl_enable_R0;
	assign debug_o[1] = vcdl_enable_R1;
	assign debug_o[2] = vcdl_out[0];
	assign debug_o[3] = vcdl_out[1];
	assign debug_o[5:4] = vcdl_enable_SYSCLK_R0;
	assign debug_o[7:6] = vcdl_enable_SYSCLK_R1;
endmodule
