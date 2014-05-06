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
module RITC_Controller(
		input CLK200,
		input CLK,
		input user_sel_i,
		input [1:0] user_addr_i,
		input [7:0] user_dat_i,
		output [7:0] user_dat_o,
		input user_wr_i,
		input user_rd_i,
		
		input [47:0] CH0,
		input [47:0] CH1,
		input [47:0] CH2,
		input [2:0] REFCLK_Q,		
		input SYNC,
		output VCDL_START,
		output VCDL_SYNC,
		output vcdl_debug,
		output TRAINING,
		output [9:0] COUNTER,
		input REFCLK_to_BUFR,
		output [7:0] train_sync_o,
		output bitslip_o,
		output [5:0] bitslip_addr_o,
		output rst_o
    );

	parameter VCDL_IODELAY_GROUP = "IODELAY_0";
	parameter MAKE_IDELAYCTRL = "NO";
	parameter IDELAYE2LOC = "IDELAY_X0Y99";

	wire CLKREF;
	BUFR u_refclk_in(.I(REFCLK_to_BUFR),.O(CLKREF));

	/////////////////////////////////////////////////////////////////////////////
	// CLOCK COUNTER MESS                                                      //
	/////////////////////////////////////////////////////////////////////////////
	
	// This could really be handled better...
	reg [9:0] clkref_counter = {10{1'b0}};
	reg count_enable;
	reg [1:0] count_enable_CLKREF;
	always @(posedge CLKREF) begin
		count_enable_CLKREF <= {count_enable_CLKREF[0],count_enable};
		if (count_enable_CLKREF[1]) clkref_counter <= clkref_counter + 1;
	end
	reg [7:0] sysclk_counter = {8{1'b0}};
	reg [9:0] clkref_counter_SYSCLK;
	reg [9:0] clkref_counter_SYSCLK_OLD;
	reg [9:0] clkref_counter_DIFF;
	// count number of clocks in 128 system clocks. Should be 256.
	reg [1:0] latch_counter;

	reg [7:0] data_out;
	
	always @(posedge CLK) begin
		sysclk_counter <= sysclk_counter + 1;
		count_enable <= sysclk_counter[7];
		// Count from sysclk_counter = 128 to sysclk_counter 256.
		// Latch at sysclk_counter 64.
		latch_counter[0] <= (!sysclk_counter[7] && (sysclk_counter[6]));
		latch_counter[1] <= latch_counter[0];
		if (latch_counter[1:0] == 2'b01) begin
			clkref_counter_SYSCLK <= clkref_counter;
			clkref_counter_SYSCLK_OLD <= clkref_counter_SYSCLK;
		end
		clkref_counter_DIFF <= clkref_counter_SYSCLK - clkref_counter_SYSCLK_OLD;
	end

	///////////////////////////////////////////////////////////////////////////
	// SYSTEM RESET HANDLING                                                 //
	///////////////////////////////////////////////////////////////////////////

	localparam WAIT_AFTER_VCDL_STOP = 15;
	localparam WAIT_AFTER_VCDL_PULSE = 15;
	localparam WAIT_AFTER_RESET = 15;

	localparam FSM_BITS = 4;
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] STOP_VCDL = 1;
	localparam [FSM_BITS-1:0] WAIT1 = 2;
	localparam [FSM_BITS-1:0] SAMPLE_CLOCK_Q = 3;
	localparam [FSM_BITS-1:0] TRY_VCDL_PULSE = 4;
	localparam [FSM_BITS-1:0] WAIT2 = 5;
	localparam [FSM_BITS-1:0] SAMPLE_CLOCK_Q_2 = 6;
	localparam [FSM_BITS-1:0] ISSUE_DATAPATH_RESET = 7;
	localparam [FSM_BITS-1:0] WAIT3 = 8;
	reg [FSM_BITS-1:0] state = IDLE;
	reg [3:0] wait_counter = {4{1'b0}};
	reg reset_request = 0;
	
	// We ONLY check against REFCLK[0] here, because we're going to use it for
	// delay line servoing. The other two aren't used for anything other than fun.
	always @(posedge CLK) begin
		case (state)
			IDLE: if (reset_request) state <= STOP_VCDL;
			STOP_VCDL: state <= WAIT1;
			WAIT1: if (wait_counter == WAIT_AFTER_VCDL_STOP) state <= SAMPLE_CLOCK_Q;
			SAMPLE_CLOCK_Q: if (REFCLK_Q[0] != 0) state <= TRY_VCDL_PULSE;
							  else state <= ISSUE_DATAPATH_RESET;
			TRY_VCDL_PULSE: if (SYNC) state <= WAIT2;
			WAIT2: if (wait_counter == WAIT_AFTER_VCDL_PULSE) state <= SAMPLE_CLOCK_Q_2;
			SAMPLE_CLOCK_Q_2: state <= ISSUE_DATAPATH_RESET;
			ISSUE_DATAPATH_RESET: if (!reset_request) state <= WAIT3;
			WAIT3: if (wait_counter == WAIT_AFTER_RESET) state <= IDLE;
			default: state <= IDLE;
		endcase
	end

	// Wait counter.
	always @(posedge CLK) begin
		if (state == WAIT1 || state == WAIT2 || state == WAIT3) wait_counter <= wait_counter + 1;
		else wait_counter <= {4{1'b0}};
	end
	
	// Determine if REFCLK is inverted or not.
	// If it is, we can try to send one pulse through VCDL and see if that
	// resets everything.
	reg [2:0] refclk_is_inverted = {3{1'b0}};

	///////////////////////////////////////////////////////////////////////////
	// VCDL GENERATION		                                                 //
	///////////////////////////////////////////////////////////////////////////

	reg [4:0] vcdl_delay_reg = {5{1'b0}};
	reg vcdl_delay_load = 0;
	wire vcdl_delay_ready;
	wire vcdl_enable = (state == IDLE || state == TRY_VCDL_PULSE);

	RITC_VCDL_generator #(.VCDL_IODELAY_GROUP(VCDL_IODELAY_GROUP),.MAKE_IDELAYCTRL(MAKE_IDELAYCTRL),.IDELAYE2LOC(IDELAYE2LOC))
							  u_vcdl(.sync_i(SYNC),.en_i(vcdl_enable),.rst_i(rst_o),
										.idelayctrl_rdy_o(vcdl_delay_ready),
										.CLK(CLK), .CLK200(CLK200),
										.delay_i(vcdl_delay_reg),.load_delay_i(vcdl_delay_load),
										.VCDL(VCDL_START),
										.vcdl_sync_o(VCDL_SYNC),
										.vcdl_debug_o(vcdl_debug));

	always @(posedge CLK) begin
		if (state == SAMPLE_CLOCK_Q || state == SAMPLE_CLOCK_Q_2)
			refclk_is_inverted <= REFCLK_Q;
	end

	///////////////////////////////////////////////////////////////////////////
	// TRAINING PATTERN LATCHING		                                        //
	///////////////////////////////////////////////////////////////////////////
	reg bitslip_reg = 0;
	reg [5:0] training_select = {6{1'b0}};
	wire [1:0] ch_select = training_select[5:4];
	wire [3:0] bit_select = training_select[3:0];
	reg [47:0] ch0_deserdes = {48{1'b0}};
	reg [47:0] ch1_deserdes = {48{1'b0}};
	reg [47:0] ch2_deserdes = {48{1'b0}};
	reg [47:0] ch_deserdes_mux = {48{1'b0}};
	reg [3:0] deserdes_mux = {4{1'b0}};
	reg [7:0] train_sync = {8{1'b0}};
	wire [3:0] bit_scramble[15:0];

	reg training_disable = 0;
	
	// We get 4 bits per clock, and 12 total bits. So
	// bit scrambling works by jumping forward 12 in each.
	generate
		genvar bs_i;
		for (bs_i=0;bs_i<12;bs_i=bs_i+1) begin : BIT_SCRAMBLE_LOOP
			assign bit_scramble[bs_i] = { ch_deserdes_mux[ bs_i ],
													ch_deserdes_mux[ 12 + bs_i ],
													ch_deserdes_mux[ 24 + bs_i ],
													ch_deserdes_mux[ 36 + bs_i ] };
		end
	endgenerate
	assign bit_scramble[12] = bit_scramble[4];
	assign bit_scramble[13] = bit_scramble[5];
	assign bit_scramble[14] = bit_scramble[6];
	assign bit_scramble[15] = bit_scramble[7];
	
	always @(posedge CLK) begin
		ch0_deserdes <= CH0;
		ch1_deserdes <= CH1;
		ch2_deserdes <= CH2;
		if (ch_select == 0) ch_deserdes_mux <= ch0_deserdes;
		else if (ch_select == 1 || ch_select == 3) ch_deserdes_mux <= ch1_deserdes;
		else ch_deserdes_mux <= ch2_deserdes;
		deserdes_mux <= bit_scramble[bit_select];
	
		if (SYNC) train_sync[3:0] <= deserdes_mux;
		if (!SYNC) train_sync[7:4] <= deserdes_mux;
	end

	// User interface registers:
	// Register 0: [4:0] VCDL sync delay. [5] VCDL delay load. [6] IDELAYCTRL ready. [7] Reset.
	// Register 1: Training sync (read). Training select (write) + BITSLIP + TRAINING.
	// Register 2: COUNTER[7:0].
	// Register 3: {[6:4] clock_is_inverted,COUNTER[9:8]}
	reg reset_request_reg = 0;
	always @(posedge CLK) begin : INPUT_REGISTERS
		if (user_sel_i && user_wr_i) begin
			if (user_addr_i == 0) begin
				vcdl_delay_reg <= user_dat_i[4:0];
				vcdl_delay_load <= user_dat_i[5];
				reset_request_reg <= user_dat_i[7];
			end
			if (user_addr_i == 1) begin
				training_select <= user_dat_i[5:0];
				training_disable <= user_dat_i[6];
				bitslip_reg <= user_dat_i[7];
			end
		end else begin
			vcdl_delay_load <= 0;
			bitslip_reg <= 0;
		end
	end
	always @(posedge CLK) reset_request <= reset_request_reg;
	always @(*) begin
		case (user_addr_i)
			2'd0: data_out <= {reset_request,vcdl_delay_ready,vcdl_delay_load,vcdl_delay_reg};
			2'd1: data_out <= train_sync;
			2'd2:	data_out <= clkref_counter_DIFF[7:0];
			2'd3: data_out <= {refclk_is_inverted,clkref_counter_DIFF[9:8]};
		endcase
	end
	
	assign user_dat_o = data_out;			 
	assign COUNTER = clkref_counter_DIFF;
	assign bitslip_addr_o = training_select;
	assign bitslip_o = bitslip_reg;
	assign train_sync_o = train_sync;
	assign rst_o = reset_request;
	assign TRAINING = training_disable;
endmodule
