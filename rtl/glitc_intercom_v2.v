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

/** \brief GLITC<->GLITC communication top level module (v2: v1 was for simulation only).
 *
 * This module handles the GLITC<->GLITC communication path.
 * Register map:
 * 0x00 : GICTRL0
 * 0x01 : GICTRL1
 * 0x02 : GITRAIN
 * 0x03 : GIDELAY
 * 
 * Note: This module in many ways looks very similar to the datapath control
 *       registers, but training is fairly different. This is because there are
 *       no real process variables to deal with, BUT we have 2 synchronization
 *       issues to deal with. First, the phase of the 81.25 MHz VCDL. Second,
 *       (in the local clocking case) the phase of the generated 162.5 MHz clock.
 *       
 *       The phase of the 162.5 MHz clock is dealt with by fine phase-shifting
 *       of the multiplier clock (stepping a bajillion steps forward!).
 *
 *       The phase of VCDL is dealt with by resyncing the SYNC input when a
 *       specific code word is received.
 *
 * Basic sequence:
 *    1: Issue SERDES reset.
 *    2: Issue BITSLIP to all bits 3 times. (write to GITRAIN 0xF000000 3 times, write 0xF10000 3 times)
 *    3: Load nominal delays into IDELAY (24 for onboard links, 13 for D->D link, 6 for A->A link, 10 for A->D link)
 *    4: Reset status.
 *    5: Enable Output SERDES.
 *    6: Enable Input Buffers.
 *    7: Start with Phi2 GLITC. If PHI_DOWN is Aligned, continue with next GLITC (increasing phi).
 *       If PHI_DOWN is *not* aligned:
 *          Disable input buffers.
 *          Disable output SERDES.
 *          Issue phase shift to multiplier MMCM.
 *          
 *       
 * GICTRL0:
 *    Bit 0 : PHI_UP ISERDES reset (flag).
 *    Bit 1 : PHI_UP OSERDES reset (static).
 *    Bit 2 : PHI_UP Enable Input Buffers.
 *    Bit 3 : PHI_UP OSERDES clock enable.
 *    Bit 4 : PHI_UP Reset Status.
 *    Bit 5 : PHI_UP Aligned.
 *    Bit 6 : Send Sync to PHI_UP
 *    Bit 7 : PHI_UP received a Sync.
 *    Bit 8 : PHI_UP Correlation Out Enable.
 *    Bit 16: PHI_DOWN ISERDES reset (flag).
 *    Bit 17: PHI_DOWN OSERDES reset (static).
 *    Bit 18: PHI_DOWN Enable Input Buffers.
 *    Bit 19: PHI_DOWN OSERDES clock enable.
 *    Bit 20: PHI_DOWN Reset Status.
 *    Bit 21: PHI_DOWN Aligned.
 *    Bit 22: Send Sync to PHI_DOWN
 *    Bit 23: PHI_DOWN received a Sync.
 *    Bit 24: PHI_DOWN Correlation Out Enable.
 * GICTRL1:
 *    Bits 3:0   : Latency Measurement from last Ping
 *    Bit   8    : Pong seen from last Ping
 *    Bit  18    : Path Select (0 = PHI_UP, 1 = PHI DOWN)
 *    Bit  31    : Ping
 * GITRAIN:
 *    Bits 15:0  : Received Word
 *    Bit  18    : Path Select (0 = PHI_UP, 1 = PHI_DOWN)
 *    Bit  27:24 : Bitslip selected bit in path (24=bit0, 25=bit1, etc.)
 *    Bit  31    : Enable Training
 * GIDELAY:
 *    Bits 4:0   : Delay value to load.
 *    Bits 17:16 : Bit select.
 *    Bit  18    : Path Select (0 = PHI_UP, 1 = PHI_DOWN)
 *    Bit  31    : Delay load.
 */
module glitc_intercom_v2(
		//% User interface clock.
		input user_clk_i,
		//% User data input.
		input [31:0] user_dat_i,
		//% User register address.
		input [3:0] user_addr_i,
		//% User interface active.
		input user_sel_i,
		//% User interface write strobe.
		input user_wr_i,
		//% User data output.
		output [31:0] user_dat_o,
		
		//% System clock.
		input sysclk_i,
		//% System clock, x2. For OSERDES.
		input sysclkx2_i,
		//% Data capture clock.
		input dataclk_i,
		//% Data capture clock, divided by 2 (SYSCLK-speed)
		input dataclk_div2_i,

		//% Input power from RITC0.
		input [10:0] r0_power_i,
		//% Input correlation from RITC0.
		input [4:0] r0_corr_i,
		//% Input power from RITC1.
		input [10:0] r1_power_i,
		//% Input correlation from RITC1.
		input [4:0] r1_corr_i,

		//% Output power from PHI_DOWN interface.
		output [10:0] phi_down_power_o,
		//% Output correlation from PHI_DOWN interface.
		output [4:0] phi_down_corr_o,
		//% PHI_DOWN output is valid.
		output phi_down_valid_o,

		//% Output power from PHI_UP interface.
		output [10:0] phi_up_power_o,
		//% Output correlation from PHI_UP interface.
		output [4:0] phi_up_corr_o,
		//% PHI_UP output is valid.
		output phi_up_valid_o,
		
		//% Global synchronizer.
		output sync_o,

		output [3:0] PHI_DOWN_OUT_P,
		output [3:0] PHI_DOWN_OUT_N,
		input [3:0] PHI_DOWN_IN_P,
		input [3:0] PHI_DOWN_IN_N,
		output [3:0] PHI_UP_OUT_P,
		output [3:0] PHI_UP_OUT_N,		
		input [3:0] PHI_UP_IN_P,
		input [3:0] PHI_UP_IN_N,
		
		
		output [31:0] debug_o
    );

	// The output data corresponds to 16 bits, 4 lines x 4 bits/cycle.
	// The maximum value using the proper assignments on the half-bit
	// yields 3528, which needs 12 bits.
	// However every sum is even (every square is even, so it's a sum 
	// of 16 squares), so we really only need 11 bits.
	// Therefore the maximum is really 1764.
	// In addition every square has a "0.25" which is dropped from the square.
	// This means that the value that is passed around is really "sum32/2 - 4".
	// So the maximum value is really 1760, or 0x6E0.
	//
	// The top 5 bits are used to indicate which correlation produced the maximum.
	// If 2 correlations produced the same maximum, the preference is hardcoded.
	//
	// The nice thing about 0x6E0 being the maximum (out of 0x7FF = 2047) is that
	// we can immediately recognize a 'control' pattern in 3 bits - 0x7 - which
	// will never occur in normal operation.
	//
	// So our 'valid' output is simply checking for those 3 bits high.
	// 
	// The bit patterning is then:
	// bit [3]: 15, 14, 13, 12
	// bit [2]: 11, 10, 9, 8
	// bit [1]: 7, 6, 5, 4
	// bit [0]: 3, 2, 1, 0
	//
	// and valid is then !(bit[10] && bit[9] && bit[8]).
	// 
	// There are 5 'command' patterns:
	// 'ping', 'pong', 'train', 'sync', and 'null'
	// The nominal 'train' pattern is
	// bit [3]: 1011
	// bit [2]: 0111
	// bit [1]: 1110
	// bit [0]: 1101
	// or 0xB7ED
	// The nominal 'null' pattern is 0xFFXX.
	// The nominal 'ping' pattern is 0x07XX.
	// The nominal 'pong' pattern is 0x17XX.
	// The nominal 'sync' pattern is 0x27XX.
	// (The top 5 bits can be used to determine the commanding).
	// If we ever manage to be super-clever, post trigger the command path could be used to transfer
	// up to 8 bits per clock cycle, maybe to do smart things like request the *fully aligned* power.
	// But I make the bold prediction that given manpower issues, we will never be this clever.
	//
	// The 'null' pattern exists to disable the input for a phi sector automatically. It doesn't do anything.
	
	localparam UP = 1'b0;
	localparam DOWN = 1'b1;
	
	wire [31:0] register_data[3:0];
	wire [31:0] GICTRL0;
	wire sel_GICTRL0 = (user_sel_i && user_addr_i[1:0] == 2'b00);
	wire [31:0] GICTRL1;
	wire sel_GICTRL1 = (user_sel_i && user_addr_i[1:0] == 2'b01);
	wire [31:0] GITRAIN;
	wire sel_GITRAIN = (user_sel_i && user_addr_i[1:0] == 2'b10);
	wire [31:0] GIDELAY;
	wire sel_GIDELAY = (user_sel_i && user_addr_i[1:0] == 2'b11);
	assign register_data[0] = GICTRL0;
	assign register_data[1] = GICTRL1;
	assign register_data[2] = GITRAIN;
	assign register_data[3] = GIDELAY;
	assign user_dat_o = register_data[user_addr_i[1:0]];
	
	wire [3:0] phi_down_out;
	wire [3:0] phi_down_in;
	wire [15:0] phi_down_in_SYSCLK;
	wire [3:0] phi_up_out;
	wire [3:0] phi_up_in;
	wire [15:0] phi_up_in_SYSCLK;
		

	reg [1:0] iserdes_reset = {2{1'b0}};
	wire [1:0] iserdes_reset_dataclk_div2;

	reg [1:0] oserdes_reset = {2{1'b1}};
	reg [1:0] oserdes_reset_sync_SYSCLK = {2{1'b1}};
	reg [1:0] oserdes_reset_SYSCLK = {2{1'b1}};

	reg [1:0] input_buffer_disable = {2{1'b1}};

	reg [1:0] oserdes_clock_enable = {2{1'b0}};
	reg [1:0] oserdes_clock_enable_sync_SYSCLK = {2{1'b0}};
	(* SHREG_EXTRACT = "FALSE" *)
	(* EQUIVALENT_REGISTER_REMOVAL = "FALSE" *)
	reg [7:0] oserdes_clock_enable_SYSCLK = {8{1'b0}};
	
	reg [1:0] status_reset = {2{1'b0}};
	wire [1:0] status_reset_SYSCLK;
	
	reg [1:0] send_sync = {2{1'b0}};
	wire [1:0] send_sync_SYSCLK;
	
	reg [1:0] sync_received = {2{1'b0}};
	reg [1:0] sync_seen_SYSCLK = {2{1'b0}};
	wire [1:0] sync_seen;
	
	reg [1:0] aligned = {2{1'b0}};
	reg [1:0] aligned_sync = {2{1'b0}};
	reg [1:0] aligned_SYSCLK = {2{1'b0}};
	
	reg [1:0] corr_out_enable = {2{1'b0}};
	reg [1:0] corr_out_enable_sync_SYSCLK = {2{1'b0}};
	reg [1:0] corr_out_enable_SYSCLK = {2{1'b0}};
	
	//% Flags to send a ping via the selected path.
	reg [1:0] send_ping = {2{1'b0}};
	//% Flags in SYSCLK domain.
	wire [1:0] send_ping_SYSCLK;
	//% Indicates that selected path is waiting for a pong.
	reg [1:0] waiting_for_pong_SYSCLK = 2'b00;
	//% Pong detectors in SYSCLK domain.
	reg [1:0] pong_seen_SYSCLK = 1'b0;
	//% Edge detect seeing any pong.
	reg [1:0] any_pong_seen_SYSCLK = {2{1'b0}};
	//% Flag in user clock domain that pong has been seen.
	wire pong_seen_flag;
	//% Indicates that the last ping had a pong.
	reg pong_seen = 0;
	//% Flags to send a pong response.
	reg [1:0] send_pong_SYSCLK = {2{1'b0}};	
	//% Latency timer in the SYSCLK domain.
	reg [3:0] latency_timer_SYSCLK = {4{1'b0}};
	//% Latency timer plus 1 (in SYSCLK domain)
	wire [4:0] latency_timer_SYSCLK_plus_one = latency_timer_SYSCLK + 1;
	//% Latency timer in the user clock domain.
	reg [3:0] latency_timer = {4{1'b0}};
	
	//% Indicates that training should be on for the selected path.
	reg send_train = 0;
	//% Indicates that training is active for selected path, and all commands should be ignored.
	reg training = 0;
	//% Selects which path to turn training on.
	reg train_sel = 0;
	//% Activates latching sequence.
	reg train_latch_enable = 0;
	//% Synchronize training
	reg [1:0] training_SYSCLK = {2{1'b0}};
	//% Path-specific version of 'training' in SYSCLK domain.
	reg [1:0] path_is_training_SYSCLK = {2{1'b0}};
	//% Registered versions of send_train in SYSCLK domain.
	reg [1:0] train_SYSCLK = 2'b00;
	//% Registered versions of path select in SYSCLK domain.
	reg [1:0] train_sel_SYSCLK = {2{1'b0}};
	//% Logic to activate train in SYSCLK domain.
	wire [1:0] send_train_SYSCLK = { train_SYSCLK[1] && train_sel_SYSCLK[1], train_SYSCLK[1] && !train_sel_SYSCLK[1] };
	//% 'train_waiting' goes high when send_train goes, and is cleared by do_train_latch.
	reg train_waiting = 0;
	//% Flag to tell SYSCLK to latch pattern.
	wire do_train_latch = (train_latch_enable && !train_waiting);
	//% Flag in SYSCLK domain to latch pattern.
	wire do_train_latch_SYSCLK;
	//% Flag in SYSCLK domain that pattern has been latched.
	reg train_ready_SYSCLK = 0;
	//% Flag back in user_clock domain that train is ready.
	wire train_ready;
	//% Pattern in SYSCLK domain.
	reg [15:0] train_latch_SYSCLK = {16{1'b0}};
	//% Pattern in user_clock domain.
	reg [15:0] train_latch = {16{1'b0}};
	//% Bitslip flags in user_clock domain.
	reg [3:0] bitslip_flag = {4{1'b0}};
	//% Bitslip flags in dataclk_div2 domain.
	wire [3:0] bitslip_flag_dataclk_div2[1:0];


	//% Delay value to be loaded.
	reg [5:0] delay_value = {6{1'b0}};
	//% Which delay gets loaded.
	reg [2:0] delay_sel = {3{1'b0}};
	//% Load the delay.
	reg delay_load = 0;
	
	
	//% Global SYNC flop.
	reg sync = 0;
	
	wire [1:0] do_command;
	assign do_command = (~corr_out_enable_SYSCLK | send_ping_SYSCLK | send_train_SYSCLK | send_sync_SYSCLK);
	wire [5:0] cmd[1:0];
	wire [7:0] cmd_data[1:0];	
	// We don't use command data right now.
	assign cmd_data[0] = 8'hED;
	assign cmd_data[1] = 8'hED;

	wire [1:0] command_in_seen;
	wire [5:0] command_in[1:0];
	
	assign command_in_seen[UP] = (phi_up_in_SYSCLK[10] && phi_up_in_SYSCLK[9] && phi_up_in_SYSCLK[8]) && !path_is_training_SYSCLK[UP];
	assign command_in_seen[DOWN] = phi_down_in_SYSCLK[10] && phi_down_in_SYSCLK[9] && phi_down_in_SYSCLK[8] && !path_is_training_SYSCLK[DOWN];
	assign command_in[UP] = phi_up_in_SYSCLK[15:11];
	assign command_in[DOWN] = phi_down_in_SYSCLK[15:11];

	///////////////////////////////////////////////////////////
	//
	// user_clk logic
	//
	///////////////////////////////////////////////////////////

	assign GICTRL0 = { 7'h00, corr_out_enable[DOWN],
							 sync_received[DOWN],1'b0,aligned[DOWN],1'b0,
							 oserdes_clock_enable[DOWN],input_buffer_disable[DOWN],oserdes_reset[DOWN],1'b0,
						    7'h00, corr_out_enable[UP],
							 sync_received[UP],1'b0,aligned[UP],1'b0,
							 oserdes_clock_enable[UP],input_buffer_disable[UP],oserdes_reset[UP],1'b0 };
	assign GICTRL1 = { 23'h000000, pong_seen, 4'h0, latency_timer };
	assign GITRAIN = { send_train, {12{1'b0}}, train_sel, 2'b00, train_latch };
	// 18-16 and 4-0
	assign GIDELAY = { 13'h0000, delay_sel, 11'h000, delay_value };

	always @(posedge user_clk_i) begin
		// GICTRL0
		if (sel_GICTRL0 && user_wr_i) begin
			iserdes_reset <= {user_dat_i[16],user_dat_i[0]};
			oserdes_reset <= {user_dat_i[17],user_dat_i[1]};
			input_buffer_disable <= {user_dat_i[18], user_dat_i[2]};
			oserdes_clock_enable <= {user_dat_i[19], user_dat_i[3]};
			status_reset <= {user_dat_i[20],user_dat_i[4]};
			send_sync <= {user_dat_i[22],user_dat_i[6]};
			corr_out_enable <= {user_dat_i[24],user_dat_i[8]};
		end else begin
			iserdes_reset <= {2{1'b0}};
			status_reset <= {2{1'b0}};
			send_sync <= {2{1'b0}};
		end
		if (status_reset[UP]) sync_received[UP] <= 0;
		else if (sync_seen[UP]) sync_received[UP] <= 1;
		
		if (status_reset[DOWN]) sync_received[DOWN] <= 0;
		else if (sync_seen[DOWN]) sync_received[DOWN] <= 1;
		
		// GICTRL1
		if (sel_GICTRL1 && user_wr_i) begin
			send_ping <= {user_dat_i[31] && user_dat_i[18], user_dat_i[31] && !user_dat_i[18]};
		end else begin
			send_ping <= {2{1'b0}};
		end
		if (|send_ping) pong_seen <= 0;
		else if (pong_seen_flag) pong_seen <= 1;
		if (pong_seen_flag) latency_timer <= latency_timer_SYSCLK;
		
		// GITRAIN
		if (sel_GITRAIN && user_wr_i) begin
			train_sel <= user_dat_i[18];
			train_latch_enable <= user_dat_i[28];
			send_train <= user_dat_i[31];
			bitslip_flag <= user_dat_i[27:24];
		end else begin
			bitslip_flag <= {4{1'b0}};
		end
		
		if (train_ready) train_waiting <= 0;
		else if (train_latch_enable) train_waiting <= 1;
		if (train_ready) train_latch <= train_latch_SYSCLK;
		
		// GIDELAY
		if (sel_GIDELAY && user_wr_i) begin
			delay_value <= user_dat_i[5:0];
			delay_sel <= user_dat_i[18:16];
			delay_load <= user_dat_i[31];
		end else begin
			delay_load <= 0;
		end
	end
	
	///////////////////////////////////////////////////////////
	//
	// sysclk logic
	//
	///////////////////////////////////////////////////////////
	
	always @(posedge sysclk_i) begin
		corr_out_enable_sync_SYSCLK <= corr_out_enable;
		corr_out_enable_SYSCLK <= corr_out_enable_sync_SYSCLK;
	
		oserdes_reset_sync_SYSCLK <= oserdes_reset;
		oserdes_reset_SYSCLK <= oserdes_reset_sync_SYSCLK;
		
		oserdes_clock_enable_sync_SYSCLK <= oserdes_clock_enable;
		oserdes_clock_enable_SYSCLK <= {{4{oserdes_clock_enable_sync_SYSCLK[DOWN]}},{4{oserdes_clock_enable_sync_SYSCLK[UP]}}};
		
		if (status_reset_SYSCLK[UP]) aligned_SYSCLK[UP] <= 0;
		else if (command_in_seen[UP] && (command_in[UP] == 5'h13)) aligned_SYSCLK[UP] <= 1;
		
		if (status_reset_SYSCLK[DOWN]) aligned_SYSCLK[DOWN] <= 0;
		else if (command_in_seen[DOWN] && (command_in[DOWN] == 5'h13)) aligned_SYSCLK[DOWN] <= 1;

		if (status_reset_SYSCLK[UP]) sync_seen_SYSCLK[UP] <= 0;
		else if (command_in_seen[UP] && (command_in[UP] == 5'h04)) sync_seen_SYSCLK[UP] <= 1;
		
		if (status_reset_SYSCLK[DOWN]) sync_seen_SYSCLK[DOWN] <= 0;
		else if (command_in_seen[DOWN] && (command_in[DOWN] == 5'h04)) sync_seen_SYSCLK[DOWN] <= 1;
		
		if (send_ping_SYSCLK[UP]) waiting_for_pong_SYSCLK[UP] <= 1;
		else if (pong_seen_SYSCLK[UP]) waiting_for_pong_SYSCLK[UP] <= 0;
		pong_seen_SYSCLK[UP] <= (command_in_seen[UP] && command_in[UP] == 5'h02);
		
		if (send_ping_SYSCLK[DOWN]) waiting_for_pong_SYSCLK[DOWN] <= 1;
		else if (pong_seen_SYSCLK[DOWN]) waiting_for_pong_SYSCLK[DOWN] <= 0;
		pong_seen_SYSCLK[DOWN] <= (command_in_seen[DOWN] && command_in[DOWN] == 5'h02);
				
		if (|send_ping_SYSCLK)
			latency_timer_SYSCLK <= {4{1'b0}};
		else if (|waiting_for_pong_SYSCLK && !latency_timer_SYSCLK_plus_one[4])
			latency_timer_SYSCLK <= latency_timer_SYSCLK_plus_one;
		any_pong_seen_SYSCLK <= {any_pong_seen_SYSCLK[0], |pong_seen_SYSCLK};		

		send_pong_SYSCLK[UP] <= (command_in_seen[UP] && command_in[UP] == 5'h00);
		send_pong_SYSCLK[DOWN] <= (command_in_seen[DOWN] && command_in[DOWN] == 5'h00);

		train_SYSCLK <= {train_SYSCLK[0],send_train};
		train_sel_SYSCLK <= {train_sel_SYSCLK[0],train_sel};
		train_ready_SYSCLK <= do_train_latch_SYSCLK;
		
		if ((train_sel_SYSCLK == UP) && do_train_latch_SYSCLK) train_latch_SYSCLK <= phi_up_in_SYSCLK;
		else if ((train_sel_SYSCLK == DOWN) && do_train_latch_SYSCLK) train_latch_SYSCLK <= phi_down_in_SYSCLK;

		sync_seen_SYSCLK[UP] <= (command_in_seen[UP] && command_in[UP] == 5'h04);
		sync_seen_SYSCLK[DOWN] <= (command_in_seen[DOWN] && command_in[DOWN] == 5'h04);
		
		if (sync_seen_SYSCLK[UP] || sync_seen_SYSCLK[DOWN]) sync <= 1;
		else sync <= ~sync;

	end
	
	flag_sync u_pong(.in_clkA(any_pong_seen_SYSCLK[0] && !any_pong_seen_SYSCLK[1]),.clkA(sysclk_i),
						  .out_clkB(pong_seen_flag),.clkB(user_clk_i));
	flag_sync u_train_latch(.in_clkA(do_train_latch),.clkA(user_clk_i),
									.out_clkB(do_train_latch_SYSCLK),.clkB(sysclk_i));
	flag_sync u_train_ready(.in_clkA(train_ready_SYSCLK),.clkA(sysclk_i),
									.out_clkB(train_ready),.clkB(user_clk_i));

	glitc_intercom_input_buffers u_up_iobs(.IN_P(PHI_UP_IN_P),.IN_N(PHI_UP_IN_N),.in_o(phi_up_in),
														.OUT_P(PHI_UP_OUT_P),.OUT_N(PHI_UP_OUT_N),.out_i(phi_up_out),
														.disable_i(input_buffer_disable[UP]));
	glitc_intercom_input_buffers u_down_iobs(.IN_P(PHI_DOWN_IN_P),.IN_N(PHI_DOWN_IN_N),.in_o(phi_down_in),
														.OUT_P(PHI_DOWN_OUT_P),.OUT_N(PHI_DOWN_OUT_N),.out_i(phi_down_out),
														.disable_i(input_buffer_disable[DOWN]));
	generate
		genvar i,j;
		for (i=0;i<2;i=i+1) begin : LP
			flag_sync u_iserdes_reset(.in_clkA(iserdes_reset[i]),.clkA(user_clk_i),
											  .out_clkB(iserdes_reset_dataclk_div2[i]),.clkB(dataclk_div2_i));
			flag_sync u_sync(.in_clkA(send_sync[i]),.clkA(user_clk_i),
								  .out_clkB(send_sync_SYSCLK[i]),.clkB(sysclk_i));
			flag_sync u_sync_seen(.in_clkA(sync_seen_SYSCLK[i]),.clkA(sysclk_i),
										 .out_clkB(sync_seen[i]),.clkB(user_clk_i));
			flag_sync u_ping(.in_clkA(send_ping[i]),.clkA(user_clk_i),
								  .out_clkB(send_ping_SYSCLK[i]),.clkB(sysclk_i));
			
			glitc_intercom_command_map u_map(.sync_i(send_sync_SYSCLK[i]),
														.ping_i(send_ping_SYSCLK[i]),
														.pong_i(send_pong_SYSCLK[i]),
														.train_i(send_train_SYSCLK[i]),
														.cmd_o(cmd[i]));
			for (j=0;j<4;j=j+1) begin : BT
				flag_sync u_bitslip(.in_clkA(bitslip_flag[j] && (train_sel == i)),.clkA(user_clk_i),
										  .out_clkB(bitslip_flag_dataclk_div2[i][j]),.clkB(dataclk_div2_i));
			end
		end
	endgenerate

	glitc_intercom_oserdes u_up_out_oserdes(.sysclk_i(sysclk_i),
														 .sysclkx2_i(sysclkx2_i),
														 .en_i(oserdes_clock_enable_SYSCLK[4*UP +: 4]),
														 .rst_i(oserdes_reset_SYSCLK[UP]),
														 .do_cmd_i(do_command[UP]),
														 .cmd_i(cmd[UP]),
														 .cmd_dat_i(cmd_data[UP]),
														 .power_i(r1_power_i),
														 .corr_i(r1_corr_i),
														 .oq_o(phi_up_out));

	glitc_intercom_iserdes #(.RLOC_ISERDES("X11Y0"),.RLOC_FF("X0Y2")) u_up_in_iserdes(.user_clk_i(user_clk_i),
														  .load_i(delay_load && (delay_sel[2] == UP)),
														  .delay_sel_i(delay_sel[1:0]),
														  .delay_i(delay_value),
														  .dataclk_i(dataclk_i),
															.dataclk_div2_i(dataclk_div2_i),
															.bitslip_i(bitslip_flag_dataclk_div2[UP]),
															.sysclk_i(sysclk_i),
															.rst_dataclk_div2_i(iserdes_reset_dataclk_div2[UP]),
															.en_i(1'b1),
															.in_i(phi_up_in),
															.oq_o(phi_up_in_SYSCLK));

	glitc_intercom_oserdes #(.INVERT(1)) u_down_out_oserdes(.sysclk_i(sysclk_i),
														 .sysclkx2_i(sysclkx2_i),
														 .en_i(oserdes_clock_enable_SYSCLK[4*DOWN +: 4]),
														 .rst_i(oserdes_reset_SYSCLK[DOWN]),
														 .do_cmd_i(do_command[DOWN]),
														 .cmd_i(cmd[DOWN]),
														 .cmd_dat_i(cmd_data[DOWN]),
														 .power_i(r0_power_i),
														 .corr_i(r0_corr_i),
														 .oq_o(phi_down_out));

	glitc_intercom_iserdes #(.RLOC_ISERDES("X0Y0"),.RLOC_FF("X17Y2")) u_down_in_iserdes(.user_clk_i(user_clk_i),
														  .load_i(delay_load && (delay_sel[2] == DOWN)),
														  .delay_sel_i(delay_sel[1:0]),
														  .delay_i(delay_value),
														  .dataclk_i(dataclk_i),
															.dataclk_div2_i(dataclk_div2_i),
															.bitslip_i(bitslip_flag_dataclk_div2[DOWN]),
															.sysclk_i(sysclk_i),
															.rst_dataclk_div2_i(iserdes_reset_dataclk_div2[DOWN]),
															.en_i(1'b1),
															.in_i(phi_down_in),
															.oq_o(phi_down_in_SYSCLK));

	assign phi_down_power_o = phi_down_in_SYSCLK[10:0];
	assign phi_down_corr_o = phi_down_in_SYSCLK[15:11];
	assign phi_down_valid_o = !command_in_seen[DOWN];

	assign phi_up_power_o = phi_up_in_SYSCLK[10:0];
	assign phi_up_corr_o = phi_up_in_SYSCLK[15:11];
	assign phi_up_valid_o = !command_in_seen[UP];

	reg [15:0] phi_up_in_debug = {16{1'b0}};
	reg [15:0] phi_down_in_debug = {16{1'b0}};

	always @(posedge sysclk_i) begin
		phi_up_in_debug <= phi_up_in_SYSCLK;
		phi_down_in_debug <= phi_down_in_SYSCLK;
	end

	assign debug_o = {phi_down_in_debug, phi_up_in_debug};
	assign sync_o = sync;
endmodule
