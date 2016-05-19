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
 * RITC_dual_datapath_v3 is a controller for the datapath for 2 RITCs.
 * The 'datapath' here means everything from where the data enters until
 * it ends up as a 48-bit, 162.5 MHz bitstream.
 *
 * v3 is significantly more modular to clean things up.
 */
(* SHREG_EXTRACT = "NO" *)
module RITC_dual_datapath_v3(
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
		output ctrl_o,
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
	parameter [NUM_CH*NUM_BIT-1:0] BIT_POLARITY = 72'hFFF000000FEF000000;
	
	//< IOFIFO reset.
	wire fifo_reset;
	//< IOFIFO enable.
	wire fifo_enable;
	//< SERDES reset.
	wire serdes_reset;
	//< IDELAYCTRL reset.
	wire delayctrl_reset;
	//< IDELAYCTRL ready.
	wire delayctrl_ready;
	//< IBUFDS input disable.
	wire datapath_disable;
	
	//< Scaler sample select.
	wire [6:0] scaler_sel;
	//< Scaler sample update (accumulator reset).
	wire scaler_wr;
	//< Scaler finished indicator.
	wire scaler_done;
	
	//< Training mode disable.
	wire disable_training;
	//< Latched reference clocks.
	wire [5:0] refclk_q;
	
	//< VCDL single pulse flag.
	wire [1:0] vcdl_pulse;
	//< VCDL enables.
	wire [1:0] vcdl_enable;
	
	//< REFCLKs through a regional clock.
	wire [5:0] refclk_bufr;	
	//< Select which REFCLK to use for counter.
	wire [2:0] refclk_select;
	//< REFCLK select write flag (reset counter).
	wire refclk_select_wr;
	//< Count output.
	wire [9:0] refclk_count;
	
	//< Raw scaler out.
	wire [63:0] scaler_out;
	//< Scaler value.
	wire [31:0] scaler = (scaler_sel[0]) ? scaler_out[32 +: 32] : scaler_out[0 +: 32];

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

	//< Serial bitstream for controlling IDELAYs and ISERDES bitslipping.
	wire bit_control;

	RITC_datapath_control u_control(.clk_i(user_clk_i),
											  .user_wr_i(user_wr_i),
											  .user_sel_i(user_sel_i),
											  .user_addr_i(user_addr_i),
											  .user_dat_i(user_dat_i),
											  .user_dat_o(user_dat_o),
											  
											  .fifo_reset_o(fifo_reset),
											  .fifo_enable_o(fifo_enable),
											  .serdes_reset_o(serdes_reset),
											  .delayctrl_reset_o(delayctrl_reset),
											  .delayctrl_ready_i(delayctrl_ready),
											  .datapath_disable_o(datapath_disable),
											  
											  .scaler_sel_o(scaler_sel),
											  .scaler_wr_o(scaler_wr),
											  .scaler_done_i(scaler_done),
											  .disable_training_o(disable_training),
											  .refclk_q_i(refclk_q),
											  .vcdl_pulse_o(vcdl_pulse),
											  .vcdl_enable_o(vcdl_enable),
											  
											  .refclk_select_o(refclk_select),
											  .refclk_select_wr_o(refclk_select_wr),
											  .refclk_count_i(refclk_count),
											  
											  .scaler_i(scaler),
											  .ctrl_o(bit_control));
	
	//< SERDES reset, in DATACLK_DIV2 domain (out of flag_sync).
	wire serdes_reset_DATACLK_DIV2;
	//< SERDES reset, reclocked in DATACLK_DIV2 domain.
	reg serdes_reset_flag_DATACLK_DIV2 = 0;

	// Vectorize inputs.
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
			
	//< Flag synchronizer (user_clk -> SYSCLK) for the SERDES reset.
	flag_sync u_serdes_reset(.in_clkA(serdes_reset),.clkA(user_clk_i),
									 .out_clkB(serdes_reset_DATACLK_DIV2),.clkB(DATACLK_DIV2));
	//< Register reset to maximize fanout.
	always @(posedge DATACLK_DIV2) begin
		serdes_reset_flag_DATACLK_DIV2 <= serdes_reset_DATACLK_DIV2;
	end

	// VCDL outputs.
	// VCDL delays are channel 0/bit 14 and channel 4/bit 14 respectively.
	RITC_vcdl #(.SIDE("LEFT")) u_vcdl_R0(.sysclk_i(SYSCLK),
													 .user_clk_i(user_clk_i),
													 .clk_ps_i(SYSCLK_DIV2_PS),
													 .sync_i(SYNC),
													 .vcdl_enable_i(vcdl_enable[0]),
													 .vcdl_pulse_i(vcdl_pulse[0]),
													 .ctrl_i(bit_control),
													 .vcdl_ps_q(VCDL_Q_PS[0]),
													 .VCDL(VCDL[0]));
	RITC_vcdl #(.SIDE("RIGHT")) u_vcdl_R1(.sysclk_i(SYSCLK),
													 .user_clk_i(user_clk_i),
													 .clk_ps_i(SYSCLK_DIV2_PS),
													 .sync_i(SYNC),
													 .vcdl_enable_i(vcdl_enable[1]),
													 .vcdl_pulse_i(vcdl_pulse[1]),
													 .ctrl_i(bit_control),
													 .vcdl_ps_q(VCDL_Q_PS[1]),
													 .VCDL(VCDL[1]));
	
	// Dramatically simplified data/clock paths.
	// In this case there's a tight bit of logic (the RITC_bit_control)
	// which transforms a serialized control (bit_control)
	// into the idelay value, the load flag, and a bitslip flag.
	//
	// Also the entire train_latch infrastructure goes away. That's embedded in
	// the RITC sample storage. The scalers stick around over here though,
	// created via the dsp_accumulator_mux.
	generate
		genvar i_bit, j_ch, k_samp;
		for (j_ch=0;j_ch<NUM_CH;j_ch=j_ch+1) begin : CH_LOOP
			for (i_bit=0;i_bit<NUM_BIT;i_bit=i_bit+1) begin : BIT_LOOP
				glitc_data_path_wrapper_v2 #(.POLARITY(BIT_POLARITY[j_ch*12+i_bit])) 
						u_dp(.SYSCLK(SYSCLK),.DATACLK(DATACLK),
							  .DATACLK_DIV2(DATACLK_DIV2),.SYSCLK_DIV2_PS(SYSCLK_DIV2_PS),
							  .IN_P(ch_in[j_ch][i_bit]), .IN_N(ch_in_b[j_ch][i_bit]),
							  .clk_i(user_clk_i),
							  .ctrl_i(bit_control),
							  .channel_i((j_ch<3) ? j_ch : j_ch+1),
							  .bit_i(i_bit),
							  .serdes_rst_DATACLK_DIV2_i(serdes_reset_flag_DATACLK_DIV2),
							  .serdes_DATACLK_DIV2_o(data_deserdes[j_ch][4*i_bit +: 4]),
							  .q_SYSCLK_DIV2_PS_o(ch_b_q[j_ch][i_bit]));
			end
			// Note that clocks are bit 15.
			// VCDL is bit 
			glitc_clock_path_wrapper_v2 u_cp(.SYSCLK_DIV2_PS(SYSCLK_DIV2_PS),
													.IN_P(CLK[j_ch]),.IN_N(CLK_B[j_ch]),
													.clk_i(user_clk_i),
													.ctrl_i(bit_control),
													.channel_i((j_ch<3) ? j_ch : j_ch+1),
													.p_bufr_o(refclk_bufr[j_ch]),
													.p_q_o(refclk_q[j_ch]),
													.n_q_o(CLK_B_Q[j_ch]));													
		end		
	endgenerate
	
	// 
	
	// OK, we now have a bucketload of deserialized data, in the DATACLK_DIV2 domain.
	// We need to get it into the SYSCLK domain.
	GLITC_datapath_buffers_v2 u_buffers(.rst_i(fifo_reset),
												.en_i(fifo_enable),
												.valid_o(valid_o),
												.user_clk_i(user_clk_i),
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
												.refclk_count_o(refclk_count));

	// IDELAYCTRL. Only one for whole project. Map replicates the rest.
	IDELAYCTRL u_idelayctrl(.REFCLK(CLK200),.RST(delayctrl_reset),.RDY(delayctrl_ready));

    wire [47:0] mux_in[5:0];

	dsp_accumulator_mux u_scaler(.A(mux_in[0]),
										  .B(mux_in[1]),
										  .C(mux_in[2]),
										  .D(mux_in[3]),
										  .E(mux_in[4]),
										  .F(mux_in[5]),
										  .clk_i(SYSCLK),
										  .user_clk_i(user_clk_i),
										  .sync_i(SYNC),										  
										  .sel_i(scaler_sel),
										  .sel_wr_i(scaler_wr),
										  .accumulator_done(scaler_done),
										  .acc_o(scaler_out));

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
	
	reg [47:0] ch0_out_reg = {48{1'b0}};
	reg [47:0] ch1_out_reg = {48{1'b0}};
	reg [47:0] ch2_out_reg = {48{1'b0}};
	reg [47:0] ch3_out_reg = {48{1'b0}};
	reg [47:0] ch4_out_reg = {48{1'b0}};
	reg [47:0] ch5_out_reg = {48{1'b0}};
	always @(posedge SYSCLK) begin
		ch0_out_reg <= reorder_in_samples(data_buffered[0]);
		ch1_out_reg <= reorder_in_samples(data_buffered[1]);
		ch2_out_reg <= reorder_in_samples(data_buffered[2]);
		ch3_out_reg <= reorder_in_samples(data_buffered[3]);
		ch4_out_reg <= reorder_in_samples(data_buffered[4]);
		ch5_out_reg <= reorder_in_samples(data_buffered[5]);
	end
	assign mux_in[0] = ch0_out_reg;
	assign mux_in[1] = ch1_out_reg;
	assign mux_in[2] = ch2_out_reg;
	assign mux_in[3] = ch3_out_reg;
	assign mux_in[4] = ch4_out_reg;
	assign mux_in[5] = ch5_out_reg;
/*	
	assign CH0_OUT = ch0_out_reg;
	assign CH1_OUT = ch1_out_reg;
	assign CH2_OUT = ch2_out_reg;
	assign CH3_OUT = ch3_out_reg;
	assign CH4_OUT = ch4_out_reg;
	assign CH5_OUT = ch5_out_reg;
*/
	assign CH0_OUT = reorder_in_samples(data_buffered[0]);
    assign CH1_OUT = reorder_in_samples(data_buffered[1]);
    assign CH2_OUT = reorder_in_samples(data_buffered[2]);
    assign CH3_OUT = reorder_in_samples(data_buffered[3]);
    assign CH4_OUT = reorder_in_samples(data_buffered[4]);
    assign CH5_OUT = reorder_in_samples(data_buffered[5]);
	
	assign TRAIN_ON = {2{disable_training}};

	assign disable_o = datapath_disable;
    assign ctrl_o = bit_control;
endmodule
