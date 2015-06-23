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
 * 0x5	: DPSCALER[31:0]
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
		// VCDL duplicates.
		output [1:0] VCDL_Q_PS,
		// Clock and duplicate inputs
		input [5:0] CLK,
		input [5:0] CLK_B,
		// Latched clock duplicate output.
		output [5:0] CLK_B_Q,
		// Global sync input
		input SYNC,
		// Input buffer disable
		output disable_o,
		// Interface (both IDELAY and datapath)
		input user_clk_i,
		input user_sel_i,
		input user_wr_i,
		input user_rd_i,
		input [3:0] user_addr_i,
		input [31:0] user_dat_i,
		output [31:0] user_dat_o,
		output [15:0] debug_o
    );
	 
	localparam NUM_CH=6;
	localparam NUM_BIT=12;
	
	// SYNC value in SYSCLK domain the first 4 samples are on the ISERDES output.
	localparam SYNC_FIRST_SAMPLE = 0;
	
	
	// THIS IS MAGIC
	// ch0 = 000
	// ch1 = 000
	// ch2 = FEF (bit 4 is inverted, and all ch2 outputs are inverted
	// ch3 = 000
	// ch4 = 000
	// ch5 = FFF (all ch2 outputs are inverted)
	localparam [NUM_CH*NUM_BIT-1:0] BIT_POLARITY = 72'hFFF000000FEF000000;
	
	
	//< IDELAY loads.
	wire [11:0] data_idelay_load[5:0];
	//< REFCLK idelay load.
	wire [5:0] clock_idelay_load;
	//< Bitslip flags.
	wire [11:0] data_iserdes_bitslip[5:0];
	//< SERDES reset.
	reg serdes_reset = 0;
	//< SERDES reset, in DATACLK_DIV2 domain (out of flag_sync).
	wire serdes_reset_DATACLK_DIV2;
	//< SERDES reset, reclocked in DATACLK_DIV2 domain.
	reg serdes_reset_flag_DATACLK_DIV2 = 0;
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
	//< Training latch for every input. This is sadly very big (8x12=96 bits for every channel, equiv. to 2x 16 samples x 3 bits per).
	reg [7:0] train_latch[5:0][11:0];
	//< Expanded array, to fill up to powers of 2. 16 bits (12 real), 4 channels (3 real), 2 RITC
	wire [7:0] train_latch_expanded[1:0][3:0][15:0];
	//< Rearranged training latch for sample view.
	wire [2:0] sample_latch[5:0][31:0];
	//< Expanded array, to fill up to powers of 2. 32 samples, 4 channels (3 real), 2 RITC
	wire [2:0] sample_latch_expanded[1:0][3:0][31:0];
	//< Training sync
	reg [7:0] train_sync = {8{1'b0}};
	//< Training select
	reg [7:0] train_bit_select = {8{1'b0}};
	//< Training select, in sample view mode.
	wire [7:0] train_sample_select = {train_bit_select[6:4],train_bit_select[7],train_bit_select[3:0]};

	//// NOTE: Scalers ONLY WORK in sample view. 
	// They add 1024 instances of train_sync[2:0], and reset after user_rd_i (when counting is done)
	// or any write to the DPTRAINING register. This means that they can have up to 13 bits. Bit 16
	// indicates that the count is finished. So you read, and if bit 16 is set, it's valid, else
	// you read again.
	//< Scaler counter.
	reg [9:0] scaler_counter = {10{1'b0}};
	//< Scaler counter plus one (for overflow detection)
	wire [10:0] scaler_counter_plus_one = scaler_counter + 1;
	//< Scaler (OK, actually accumulator).
	reg [12:0] scaler = {13{1'b0}};
	//< Add enable for scaler.
	reg scaler_add = 0;
	//< Reset for scaler.
	reg scaler_reset = 0;
	
	//< Bitslip.
	reg bitslip = 0;
	//< Training disable
	reg train_disable = 0;	
	//< Training disable in the SYSCLK domain.
	reg train_disable_SYSCLK = 0;
	//< Training latch enable.
	reg train_latch_enable = 0;
	//< Training latch is busy.
	reg train_latch_busy = 0;
	// 1 when train_latch_enable has been seen.
	reg train_latch_enable_seen_SYSCLK = 0;
	// 1 when train_latch_enable is high, and SYNC is seen. This disables train_latch_enable_seen_SYSCLK and flags back to user_clk.
	reg train_latch_has_seen_SYNC = 0;
	// Flag to latch an incoming training sample.
	wire train_latch_enable_SYSCLK;
	// Flag to indicate that the latching is complete.
	wire train_latch_done_user_clk;
	//< Sample view.
	reg sample_view = 0;
	//< IOFIFO resets
	reg fifo_reset = 0;
	//< IOFIFO reset request, in SYSCLK domain.
	wire fifo_reset_request_SYSCLK;
	//< IOFIFO enable
	reg fifo_enable = 0;
	//< IOFIFO enable, in SYSCLK.
	reg [1:0] fifo_enable_SYSCLK = {2{1'b0}};
	//< IOFIFO reset shift register.
	reg [3:0] fifo_reset_shift_reg = {4{1'b0}};
	//< IOFIFO reset.
	reg fifo_reset_SYSCLK = 0;
	//< Input buffer disable.
	reg datapath_disable = 1;

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
	//< Initiate single VCDL pulse for R0.
	reg vcdl_pulse_R0 = 0;
	//< Initiate single VCDL pulse for R1.
	reg vcdl_pulse_R1 = 0;
	//< VCDL pulse signal, in SYSCLK domain, for R0.
	wire vcdl_pulse_flag_SYSCLK_R0;
	//< VCDL pulse signal, in SYSCLK domain, for R1.
	wire vcdl_pulse_flag_SYSCLK_R1;
	//< Continuous VCDL for R0.
	reg vcdl_enable_R0 = 0;
	//< Continuous VCDL for R1.
	reg vcdl_enable_R1 = 0;
	//< VCDL pulse request seen (in SYSCLK domain) for R0.
	reg vcdl_pulse_seen_R0 = 0;
	//< VCDL pulse request seen (in SYSCLK domain) for R1.
	reg vcdl_pulse_seen_R1 = 0;

	//< Continuous VCDL enable, in SYSCLK domain, for R0.
	reg [1:0] vcdl_enable_SYSCLK_R0 = {2{1'b0}};
	//< Continuous VCDL enable, in SYSCLK domain, for R1.
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
	// DPCTRL0[5] = Datapath disable (disable input buffers).
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
	// DPTRAINING[30] 	= BITSLIP the selected channel (in bit view).
	// DPTRAINING[29]    = Enable sample view (1=sample view, 0=bit view).
	// DPTRAINING[28]    = Disable training latch.
	// DPTRAINING[23:16] = Bit or sample select.
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
	wire [31:0] DPSCALER;
	
	assign data_out[0] = DPCTRL0;
	assign data_out[1] = DPCTRL1;
	assign data_out[2] = DPTRAINING;
	assign data_out[3] = DPCOUNTER;
	assign data_out[4] = DPIDELAY;
	assign data_out[5] = DPSCALER;
	assign data_out[6] = DPTRAINING;
	assign data_out[7] = DPCOUNTER;
	assign data_out[8] = DPCTRL0;
	assign data_out[9] = DPCTRL1;
	assign data_out[10] = DPTRAINING;
	assign data_out[11] = DPCOUNTER;
	assign data_out[12] = DPIDELAY;
	assign data_out[13] = DPSCALER;
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
			datapath_disable <= user_dat_i[5];
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
			vcdl_pulse_R1 <= 0;
			vcdl_pulse_R0 <= 0;
			r0_vcdl_delay_load <= 0;
			r1_vcdl_delay_load <= 0;
		end
		// Counter select register. This is register 3.
		if (refclk_select_wr) begin
			refclk_select <= user_dat_i[19:16];
		end
		// Training bit select register.
		if (user_sel_i && user_wr_i && user_addr_i == 4'd2) begin
			train_bit_select[6:0] <= user_dat_i[22:16];
			train_bit_select[7] <= (user_dat_i[29] && user_dat_i[23]);
			train_disable <= user_dat_i[31];
			bitslip <= user_dat_i[30] && !user_dat_i[29];
			sample_view <= user_dat_i[29];
			train_latch_enable <= user_dat_i[28];
		end else bitslip <= 0;		
		// IDELAY control register.
		if (user_sel_i && user_wr_i && user_addr_i == 4'd4) begin
			delay_in <= user_dat_i[4:0];
			delay_bit_select <= user_dat_i[22:16];
			delay_load <= user_dat_i[31];
		end else delay_load <= 0;
		// Scaler counter.
		if (scaler_reset)
			 scaler_counter <= {10{1'b0}};
		else if (scaler_add)
			scaler_counter <= scaler_counter_plus_one;
		// Reset on a write to the DPTRAINING register or a read from the DPSCALER register
		// when the count was complete.
		scaler_reset <= 
			 (user_sel_i && user_wr_i && user_addr_i == 4'd2) ||
			 ((user_sel_i && user_rd_i && user_addr_i == 4'd5) && scaler_counter_plus_one[10]);
		// Scaler/accumulator enable.
		scaler_add <= (train_latch_done_user_clk && !scaler_counter_plus_one[10] && sample_view);
		// Scaler/accumulator.
		if (scaler_reset) scaler <= {13{1'b0}};
		else if (scaler_add) scaler <= scaler + train_sync[2:0];
		
		if (train_latch_done_user_clk && !sample_view) 
			train_sync <= train_latch_expanded[train_bit_select[6]][train_bit_select[5:4]][train_bit_select[3:0]];
		else if (train_latch_done_user_clk)
			// Note that train_sample_select is a reorganized train_bit_select.
			train_sync <= {{5{1'b0}}, sample_latch_expanded[train_sample_select[7]][train_sample_select[6:5]][train_sample_select[4:0]]};
			
		if (train_latch_done_user_clk || !train_latch_enable) train_latch_busy <= 0;
		else if (train_latch_enable) train_latch_busy <= 1;
	end
	
	always @(posedge DATACLK_DIV2) begin
		serdes_reset_flag_DATACLK_DIV2 <= serdes_reset_DATACLK_DIV2;
	end
	
	always @(posedge SYSCLK) begin
		// So the 2 possible sequences here are:
		// clk sync train_latch_enable_SYSCLK train_latch_enable_seen_SYSCLK train_latch_has_seen_SYNC
		// 0 1 0 0 0
		// 1 0 1 0 0
		// 2 1 0 1 0
		// 3 0 0 1 1
		// 4 1 0 0 0
		// And
		// 0 0 0 0 0
		// 1 1 1 0 0
		// 2 0 0 1 0 
		// 3 1 0 1 0
		// 4 0 0 1 1
		// 5 1 0 0 0
		// In the second case train_latch_enable is high for 3 cycles (as opposed to 2) but the pattern
		// latched is still SYNC, ~SYNC.
		// Note that I HAVE NO IDEA if this is the right grouping. I need to find a way to figure this out...
		if (train_latch_has_seen_SYNC) train_latch_enable_seen_SYSCLK <= 0;
		else if (train_latch_enable_SYSCLK) train_latch_enable_seen_SYSCLK <= 1;
		
		if (SYNC && train_latch_enable_seen_SYSCLK) train_latch_has_seen_SYNC <= 1;
		else train_latch_has_seen_SYNC <= 0;

		if (vcdl_pulse_SYSCLK_R0) vcdl_pulse_seen_R0 <= 1;
		else if (SYNC) vcdl_pulse_seen_R0 <= 0;
		
		if (vcdl_pulse_SYSCLK_R1) vcdl_pulse_seen_R1 <= 1;
		else if (SYNC) vcdl_pulse_seen_R1 <= 0;
		
		vcdl_enable_SYSCLK_R0 <= { vcdl_enable_SYSCLK_R0[0], vcdl_enable_R0};
		
		vcdl_enable_SYSCLK_R1 <= { vcdl_enable_SYSCLK_R1[0], vcdl_enable_R1};
		
		train_disable_SYSCLK <= train_disable;
		
		fifo_enable_SYSCLK <= {fifo_enable_SYSCLK[0],fifo_enable};

		// FIFO reset. Reset must be held high for 4 SYSCLK cycles.
		if (fifo_reset_request_SYSCLK && !fifo_reset_SYSCLK) fifo_reset_shift_reg[0] <= 1;
		else fifo_reset_shift_reg <= 0;
		
		fifo_reset_shift_reg[3:1] <= fifo_reset_shift_reg[2:0];

		if (fifo_reset_shift_reg[0]) fifo_reset_SYSCLK <= 1;
		else if (fifo_reset_shift_reg[3]) fifo_reset_SYSCLK <= 0;
	end


	// Flag SYSCLK that it should latch data.
	flag_sync u_train_latch(.in_clkA(train_latch_enable && !train_latch_busy), .clkA(user_clk_i),
									.out_clkB(train_latch_enable_SYSCLK), .clkB(SYSCLK));
	// Flag user_clock back that the train latch is done.
	flag_sync u_train_latch_done(.in_clkA(train_latch_has_seen_SYNC),.clkA(SYSCLK),
										  .out_clkB(train_latch_done_user_clk),.clkB(user_clk_i));
		
	//< Flag synchronizer (user_clk -> SYSCLK) for the VCDL pulse requeset for R0.
	flag_sync u_vcdl_pulse_sync_R0(.in_clkA(vcdl_pulse_R0),.clkA(user_clk_i),
											.out_clkB(vcdl_pulse_SYSCLK_R0), .clkB(SYSCLK));
	//< Flag synchronizer (user_clk -> SYSCLK) for the VCDL pulse request for R1.
	flag_sync u_vcdl_pulse_sync_R1(.in_clkA(vcdl_pulse_R1),.clkA(user_clk_i),
											.out_clkB(vcdl_pulse_SYSCLK_R1), .clkB(SYSCLK));										
	//< Flag synchronizer (user_clk -> SYSCLK) for the FIFO reset.
	flag_sync u_fifo_reset(.in_clkA(fifo_reset),.clkA(user_clk_i),
								  .out_clkB(fifo_reset_request_SYSCLK),.clkB(SYSCLK));
	//< Flag synchronizer (user_clk -> SYSCLK) for the SERDES reset.
	flag_sync u_serdes_reset(.in_clkA(serdes_reset),.clkA(user_clk_i),
									 .out_clkB(serdes_reset_DATACLK_DIV2),.clkB(DATACLK_DIV2));


	// Full VCDL outputs.
	// These are hard macros, which put the flipflop for the VCDL output
	// in the nearest slice, route its output through an IDELAY, back through
	// the ILOGIC (which also registers it using SYSCLK_DIV2_PS for the phase
	// scanner) and over to the OLOGIC.
	//
	// This gives a tunable output delay for the VCDL to allow for compensating
	// for RITC-to-RITC delay differences.
	//
	// The macros differ for the 2 VCDL outputs, since they are located on different
	// sides of the chip and the location of the slice flipflop is obviously different.
	
	// VCDL[0] (left side of chip).
	vcdl_0_wrapper u_vcdl0( .vcdl_i( SYNC & (vcdl_enable_SYSCLK_R0[1] || vcdl_pulse_seen_R0 )),
									.vcdl_clk_i(SYSCLK),
									
									.delay_i(r0_vcdl_delay),
									.delay_ld_i(r0_vcdl_delay_load),
									.delay_clk_i(user_clk_i),
									
									.vcdl_fb_clk_i(SYSCLK_DIV2_PS),
									.vcdl_fb_q_o(VCDL_Q_PS[0]),
									
									.VCDL(VCDL[0]));
	// VCDL[1] (right side of chip).
	vcdl_1_wrapper u_vcdl1( .vcdl_i( SYNC & (vcdl_enable_SYSCLK_R1[1] || vcdl_pulse_seen_R1 )),
									.vcdl_clk_i(SYSCLK),
									
									.delay_i(r1_vcdl_delay),
									.delay_ld_i(r1_vcdl_delay_load),
									.delay_clk_i(user_clk_i),
									
									.vcdl_fb_clk_i(SYSCLK_DIV2_PS),
									.vcdl_fb_q_o(VCDL_Q_PS[1]),
									
									.VCDL(VCDL[1]));
	
	generate
		genvar i_bit, j_ch, k_samp;
		for (j_ch=0;j_ch<NUM_CH;j_ch=j_ch+1) begin : CH_LOOP
			for (i_bit=0;i_bit<NUM_BIT;i_bit=i_bit+1) begin : BIT_LOOP
				// bit_select[3:0] == bit (from 0-11, 15 is special)
				// bit_select[6:4] == channel (from 0-7).
				//                    channels 0-3 are RITC0 (3 is unused)
				//                    channels 4-7 are RITC1 (7 is unused)
				assign data_idelay_load[j_ch][i_bit] = 
					delay_load && (delay_bit_select[3:0] == i_bit) && 
					(((j_ch >= 3) && delay_bit_select[6] && (delay_bit_select[5:4] == (j_ch-3))) ||
					 ((j_ch < 3) && !delay_bit_select[6] && (delay_bit_select[5:4] == j_ch)));
				assign data_iserdes_bitslip[j_ch][i_bit] = 
					bitslip && (train_bit_select[3:0] == i_bit) && 
					(((j_ch >= 3) && train_bit_select[6] && (train_bit_select[5:4] == (j_ch-3))) ||
					 ((j_ch < 3) && !train_bit_select[6] && (train_bit_select[5:4] == j_ch)));
				// Data path for this bit.
				glitc_data_path_wrapper #(.USE_HARD_MACRO("NO"), .POLARITY(BIT_POLARITY[j_ch*12+i_bit])) u_dp(.SYSCLK(SYSCLK),.DATACLK(DATACLK),
																					  .DATACLK_DIV2(DATACLK_DIV2),.SYSCLK_DIV2_PS(SYSCLK_DIV2_PS),
																					  .IN_P(ch_in[j_ch][i_bit]), .IN_N(ch_in_b[j_ch][i_bit]),
																					  .clk_i(user_clk_i),
																					  .delay_clk_i(delay_in),
																					  .load_clk_i(data_idelay_load[j_ch][i_bit]),
																					  .bitslip_clk_i(data_iserdes_bitslip[j_ch][i_bit]),
																					  .serdes_rst_DATACLK_DIV2_i(serdes_reset_flag_DATACLK_DIV2),

																					  .serdes_DATACLK_DIV2_o(data_deserdes[j_ch][4*i_bit +: 4]),
																					  .q_SYSCLK_DIV2_PS_o(ch_b_q[j_ch][i_bit]));
				always @(posedge SYSCLK) begin
					if (valid_o) begin
						// Store the train latch in 'ISERDES order' (first sample in MSB).
						if (SYNC == SYNC_FIRST_SAMPLE) train_latch[j_ch][i_bit][7:4] <= data_buffered[j_ch][4*i_bit +: 4];
						else		 train_latch[j_ch][i_bit][3:0] <= data_buffered[j_ch][4*i_bit +: 4];
					end
				end
				if (j_ch < 3) begin : R0
					assign train_latch_expanded[0][j_ch][i_bit] = train_latch[j_ch][i_bit];
				end else begin : R1
					assign train_latch_expanded[1][j_ch-3][i_bit] = train_latch[j_ch][i_bit];
				end
			end
			// 12 to 15 copy 4 to 7.
			for (i_bit=12;i_bit<16;i_bit=i_bit+1) begin : EXPAND_SIGNAL
				if (j_ch < 3) begin : R0
					assign train_latch_expanded[0][j_ch][i_bit] = train_latch_expanded[0][j_ch][i_bit-8];
				end else begin : R1
					assign train_latch_expanded[1][j_ch-3][i_bit] = train_latch_expanded[1][j_ch-3][i_bit-8];
				end
			end


			for (k_samp=0;k_samp<4;k_samp=k_samp+1) begin : SAMPLE
				// generate 0,4,8,12
				assign sample_latch[j_ch][4*k_samp + 0] = {train_latch[j_ch][2][3-k_samp],train_latch[j_ch][1][3-k_samp],train_latch[j_ch][0][3-k_samp]};
				// generate 16,20,24,28
				assign sample_latch[j_ch][4*k_samp + 16] = {train_latch[j_ch][2][7-k_samp],train_latch[j_ch][1][7-k_samp],train_latch[j_ch][0][7-k_samp]};

				// generate 1,5,9,13
				assign sample_latch[j_ch][4*k_samp + 1] = {train_latch[j_ch][5][3-k_samp],train_latch[j_ch][4][3-k_samp],train_latch[j_ch][3][3-k_samp]};
				// generate 17,21,25,29
				assign sample_latch[j_ch][4*k_samp + 17] = {train_latch[j_ch][5][7-k_samp],train_latch[j_ch][4][7-k_samp],train_latch[j_ch][3][7-k_samp]};
				
				// generate 2,6,10,14
				assign sample_latch[j_ch][4*k_samp + 2] = {train_latch[j_ch][8][3-k_samp],train_latch[j_ch][7][3-k_samp],train_latch[j_ch][6][3-k_samp]};
				// generate 18,22,26,30
				assign sample_latch[j_ch][4*k_samp + 18] = {train_latch[j_ch][8][7-k_samp],train_latch[j_ch][7][7-k_samp],train_latch[j_ch][6][7-k_samp]};

				// generate 3,7,11,15
				assign sample_latch[j_ch][4*k_samp + 3] = {train_latch[j_ch][11][3-k_samp],train_latch[j_ch][10][3-k_samp],train_latch[j_ch][9][3-k_samp]};
				// generate 19,23,27,31
				assign sample_latch[j_ch][4*k_samp + 19] = {train_latch[j_ch][11][7-k_samp],train_latch[j_ch][10][7-k_samp],train_latch[j_ch][9][7-k_samp]};
			end
			for (k_samp=0;k_samp<32;k_samp=k_samp+1) begin : EXPAND_SAMPLE
				if (j_ch < 3) begin : R0
					assign sample_latch_expanded[0][j_ch][k_samp] = sample_latch[j_ch][k_samp];
				end else begin : R1
					assign sample_latch_expanded[1][j_ch-3][k_samp] = sample_latch[j_ch][k_samp];
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
				delay_load && (delay_bit_select[3:0] == 4'hF) &&
					(((j_ch >= 3) && delay_bit_select[6] && (delay_bit_select[5:4] == (j_ch-3))) ||
					 ((j_ch < 3) && !delay_bit_select[6] && (delay_bit_select[5:4] == j_ch)));


		end
		for (i_bit=0;i_bit<16;i_bit=i_bit+1) begin : EXPAND2
			assign train_latch_expanded[0][3][i_bit] = train_latch_expanded[0][1][i_bit];
			assign train_latch_expanded[1][3][i_bit] = train_latch_expanded[1][1][i_bit];

			assign sample_latch_expanded[0][3][i_bit] = sample_latch_expanded[0][1][i_bit];
			assign sample_latch_expanded[1][3][i_bit] = sample_latch_expanded[1][1][i_bit];
		end
		
	endgenerate
	
	// 
	
	// OK, we now have a bucketload of deserialized data, in the DATACLK_DIV2 domain.
	// We need to get it into the SYSCLK domain.
	GLITC_datapath_buffers u_buffers(.rst_i(fifo_reset_SYSCLK),
												.en_i(fifo_enable_SYSCLK[1]),
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
	assign DPCTRL0[31:6] = {26{1'b0}};
	assign DPCTRL0[5] = datapath_disable;
	assign DPCTRL0[4] = delayctrl_ready;
	assign DPCTRL0[3:2] = 2'b00;
	assign DPCTRL0[1] = fifo_enable;
	assign DPCTRL0[0] = 1'b0;
	// DPCTRL1
	assign DPCTRL1 = {vcdl_enable_R1,1'b0,vcdl_enable_R0,{7{1'b0}},refclk_q,{3{1'b0}},r1_vcdl_delay,{3{1'b0}},r0_vcdl_delay};
	// DPTRAINING
	assign DPTRAINING = {train_disable,1'b0,sample_view,train_latch_enable,{4{1'b0}},train_bit_select,{8{1'b0}},train_sync};
	// DPCOUNTER
	assign DPCOUNTER = {{12{1'b0}},refclk_select,{6{1'b0}},refclk_counter};
	// DPIDELAY
	assign DPIDELAY = {{9{1'b0}},delay_bit_select,{11{1'b0}},delay_in};
	// DPSCALER
	assign DPSCALER = {{15{1'b0}},scaler_counter_plus_one[10],{3{1'b0}},scaler};
	assign CH0_Q = ch_b_q[0];
	assign CH1_Q = ch_b_q[1];
	assign CH2_Q = ch_b_q[2];
	assign CH3_Q = ch_b_q[3];
	assign CH4_Q = ch_b_q[4];
	assign CH5_Q = ch_b_q[5];
	
	function [47:0] reorder_in_samples;
		input [47:0] signal_order;
		integer ris_i;
		begin
			for (ris_i=0;ris_i<4;ris_i=ris_i+1) begin
				reorder_in_samples[12*ris_i +: 3] = {signal_order[8+ris_i],signal_order[4+ris_i],signal_order[0+ris_i]};
				reorder_in_samples[(12*ris_i+3) +: 3] = {signal_order[20+ris_i],signal_order[16+ris_i],signal_order[12+ris_i]};
				reorder_in_samples[(12*ris_i+6) +: 3] = {signal_order[32+ris_i],signal_order[28+ris_i],signal_order[24+ris_i]};
				reorder_in_samples[(12*ris_i+9) +: 3] = {signal_order[44+ris_i],signal_order[40+ris_i],signal_order[36+ris_i]};
			end
		end
	endfunction
	
	assign CH0_OUT = reorder_in_samples(data_buffered[0]);
	assign CH1_OUT = reorder_in_samples(data_buffered[1]);
	assign CH2_OUT = reorder_in_samples(data_buffered[2]);
	assign CH3_OUT = reorder_in_samples(data_buffered[3]);
	assign CH4_OUT = reorder_in_samples(data_buffered[4]);
	assign CH5_OUT = reorder_in_samples(data_buffered[5]);

	assign TRAIN_ON = {2{train_disable}};

	assign disable_o = datapath_disable;

	assign debug_o[0] = fifo_enable_SYSCLK[1];
	assign debug_o[1] = valid_o;
	assign debug_o[2] = train_latch_enable_SYSCLK;
	assign debug_o[3] = train_latch_has_seen_SYNC;
	assign debug_o[4 +: 8] = data_buffered[0][7:0];
	assign debug_o[12] = SYNC;
	assign debug_o[13] = train_latch_enable_seen_SYSCLK;
endmodule
