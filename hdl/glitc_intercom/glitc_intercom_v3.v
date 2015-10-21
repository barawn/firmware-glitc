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

/** \brief GLITC<->GLITC communication top level module, version 3.
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
 *    Bit  16    : Path Select (0 = PHI_UP, 1 = PHI_DOWN)
 *    Bit  31    : Enable Training
 *
 * Version 3 simplifies a few things.
 * First, we expand to 20 total bits using the clock path.
 * Bits 0-11 are used for the power.
 * Bits 12-17 are used for the correlation.
 * Bits 18-19 are used for commanding.
 *
 * 11 indicates no command (or training pattern)
 * 10 indicates a  Sync command (if training is complete)
 * 01 indicates an Echo command or reseponse (if training is complete)
 * 00 indicates a Max Power command (if training is complete)
 */
module glitc_intercom_v3(
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
		
		//% Bit control.
		input ctrl_i,
		
		//% Training output. Forces max power/corrs into known state.
		output [1:0] train_o,
		
		//% System clock.
		input sysclk_i,
		//% System clock, x2. For OSERDES.
		input sysclkx2_i,
		//% Data capture clock.
		input dataclk_i,
		//% Data capture clock, divided by 2 (SYSCLK-speed)
		input dataclk_div2_i,

		//% Input power from RITC0.
		input [11:0] r0_power_i,
		//% Input correlation from RITC0.
		input [5:0] r0_corr_i,
		//% Input power from RITC1.
		input [11:0] r1_power_i,
		//% Input correlation from RITC1.
		input [5:0] r1_corr_i,

		//% Output power from PHI_DOWN interface.
		output [11:0] phi_down_power_o,
		//% Output correlation from PHI_DOWN interface.
		output [5:0] phi_down_corr_o,
		//% PHI_DOWN output is valid.
		output phi_down_valid_o,

		//% Output power from PHI_UP interface.
		output [11:0] phi_up_power_o,
		//% Output correlation from PHI_UP interface.
		output [5:0] phi_up_corr_o,
		//% PHI_UP output is valid.
		output phi_up_valid_o,
		
		//% Global synchronizer.
		output sync_o,

		output [4:0] PHI_DOWN_OUT_P,
		output [4:0] PHI_DOWN_OUT_N,

		input [4:0] PHI_DOWN_IN_P,
		input [4:0] PHI_DOWN_IN_N,

		output [4:0] PHI_UP_OUT_P,
		output [4:0] PHI_UP_OUT_N,

		input [4:0] PHI_UP_IN_P,
		input [4:0] PHI_UP_IN_N,		
		
		output [70:0] debug_o
    );

	localparam UP = 1'b0;
	localparam DOWN = 1'b1;

    localparam LATENCY_WIDTH = 5;

    localparam [71:0] RLOC_ISERDES = "X0Y0X11Y0";
    localparam [71:0] RLOC_FF = "X17Y2X0Y2";
    // DOWN oserdeses always invert.
    localparam [1:0] OSERDES_INVERT = 2'b10;
    
    function integer rloc_iserdes_bits;
        input integer i;
        begin
            if (i == 0) rloc_iserdes_bits = 40;
            else if (i == 1) rloc_iserdes_bits = 32;
            else rloc_iserdes_bits = 0;
        end
    endfunction
    function integer rloc_ff_bits;
        input integer i;
        begin
            if (i == 0) rloc_ff_bits = 32;
            else if (i == 1) rloc_ff_bits = 40;
            else rloc_ff_bits = 0;
        end
    endfunction
    
    

    //% Pad outputs, + leg.
    wire [4:0] phi_out_p[1:0];
    //% Pad outputs, - leg.
    wire [4:0] phi_out_n[1:0];
    //% Inputs to OBUFDS.
    wire [4:0] phi_out[1:0];

    //% Pad inputs, + leg.
    wire [4:0] phi_in_p[1:0];
    //% Pad inputs, - leg.
    wire [4:0] phi_in_n[1:0];
    //% Outputs from IBUFDS.
    wire [4:0] phi_in[1:0];

    //% Outputs from ISERDES.
	wire [19:0] phi_in_SYSCLK[1:0];    
    //% Inputs to OSERDES.
    wire [19:0] phi_out_SYSCLK[1:0];
    
    // ISERDES/OSERDES/IBUFDS control.
    //% ISERDES reset.
    wire [1:0] iserdes_reset;
    //% ISERDES reset in dataclk_div2 domain.
    wire [1:0] iserdes_reset_dataclk_div2;
    //% OSERDES reset.
    wire [1:0] oserdes_reset;
    //% OSERDES reset in SYSCLK domain.
    wire [1:0] oserdes_reset_SYSCLK;
    //% IBUFDS disable.
    wire [1:0] input_buffer_disable;
    //% OSERDES clock enable.
    wire [1:0] oserdes_clock_enable;

    // GLITC intercom status details
    //% Reset status flags.
    wire [1:0] status_reset;
    //% Reset status flags in SYSCLK domain.
    wire [1:0] status_reset_SYSCLK;
    //% Sync input
    wire [1:0] sync_in;
    //% Global sync
    wire sync;
    //% Sync has been received since last status reset
    wire [1:0] sync_received;
    //% We have been resynced since last reset
    wire [1:0] resynced;

    //% Send an echo.
    wire [1:0] send_echo;
    //% Send an echo in SYSCLK domain
    wire [1:0] send_echo_SYSCLK;
    //% Echo status ready in SYSCLK.
    wire [1:0] echo_ready_SYSCLK;
    //% Echo input from other GLITCs.
    wire [1:0] echo_in;
    //% Echo status ready in user_clk
    wire [1:0] echo_ready;
    //% Echo response was seen
    wire [1:0] echo_seen;
    //% Sending an echo response.
    wire [1:0] echoing;
    //% Echo latency
    wire [2*LATENCY_WIDTH-1:0] echo_latency;
    
    //% Send a sync.
    wire [1:0] send_sync;
    //% Send a sync in SYSCLK domain
    wire [1:0] send_sync_SYSCLK;
    //% Actually send the sync message
    wire [1:0] sync_command;
    //% Sync input from other GLITCs.
    wire [1:0] sync_in;

    //% Enable correlation output (and disable commanding).
    wire [1:0] corr_enable;
    
    //% Indicate that training is complete.
    wire [1:0] training_done;
    //% Flag to indicate that latched data is ready and stable
    wire [1:0] train_latch;
    //% Flag to indicate that latched data is ready in SYSCLK domain
    wire [1:0] train_latch_SYSCLK;
    //% Flag to indicate that the latch flag has been seen.
    wire [1:0] train_latch_seen;
    //% Flag to indicate that latch has been seen in SYSCLK domain
    wire [1:0] train_latch_seen_SYSCLK;
        
    //% Training data
    wire [39:0] train;

    //% Outputs to up/down glitc command bits.
    wire [1:0] command_out[1:0];

    //% Correlation outputs
    wire [5:0] corr_out[1:0];

    //% Power outputs
    wire [11:0] power_out[1:0];
    
    //% Valid outputs for adjacent phi sector inputs.
    wire [1:0] power_valid;
    
    //% Intercom controller (registers, etc.)
    glitc_intercom_control #(.LATENCY_WIDTH(LATENCY_WIDTH)) u_controller(.user_clk_i(user_clk_i),
                                        .user_sel_i(user_sel_i),
                                        .user_wr_i(user_wr_i),
                                        .user_addr_i(user_addr_i),
                                        .user_dat_i(user_dat_i),
                                        .user_dat_o(user_dat_o),
                                        
                                        .iserdes_reset_o(iserdes_reset),
                                        .oserdes_reset_o(oserdes_reset),
                                        .oserdes_ce_o(oserdes_clock_enable),
                                        
                                        .status_reset_o(status_reset),
                                        .send_sync_o(send_sync),
                                        .sync_received_i(sync_received),
                                        .resynced_i(resynced),
                                        
                                        .send_echo_o(send_echo),
                                        .echo_ready_i(echo_ready),
                                        .echo_seen_i(echo_seen),
                                        .latency_i(echo_latency),
                                        
                                        .enable_o(corr_enable),
                                        .train_o(train_o),
                                        .training_done_o(training_done),
                                        .train_latch_i(train_latch),
                                        .train_latch_seen_o(train_latch_seen),
                                        .train_i(train));
    // Map.
    assign phi_in_p[UP] = PHI_UP_IN_P;    
    assign phi_in_p[DOWN] = PHI_DOWN_IN_P;
    assign phi_in_n[UP] = PHI_UP_IN_N;
    assign phi_in_n[DOWN] = PHI_DOWN_IN_N;
    assign PHI_UP_OUT_P = phi_out_p[UP];
    assign PHI_DOWN_OUT_P = phi_out_p[DOWN];
    assign PHI_UP_OUT_N = phi_out_n[UP];
    assign PHI_DOWN_OUT_N = phi_out_n[DOWN];
    
    // Note that power_out[0] is R1: we send R1 UP
    assign power_out[UP] = r1_power_i;
    assign corr_out[UP] = r1_corr_i;
    assign power_out[DOWN] = r0_power_i;
    assign corr_out[DOWN] = r0_corr_i;
    
    generate
        genvar i;
        for (i=0;i<2;i=i+1) begin : PATH    
            reg [1:0] corr_enable_SYSCLK = {2{1'b0}};
            reg [1:0] training_done_SYSCLK = {2{1'b0}};
            reg [1:0] oserdes_clock_enable_SYSCLK = {2{1'b0}};
            
            always @(posedge sysclk_i) begin : ENABLE
                corr_enable_SYSCLK <= {corr_enable_SYSCLK[0],corr_enable[i]};
                training_done_SYSCLK <= {training_done_SYSCLK[0],training_done[i]};
                oserdes_clock_enable_SYSCLK <= {oserdes_clock_enable_SYSCLK[0],oserdes_clock_enable[i]};
            end

            assign sync_in[i] = (phi_in_SYSCLK[i][19] && !phi_in_SYSCLK[i][18]) && training_done_SYSCLK[1];
            assign echo_in[i] = (!phi_in_SYSCLK[i][19] && phi_in_SYSCLK[i][18]) && training_done_SYSCLK[1];
            assign power_valid[i] = (!phi_in_SYSCLK[i][19] && !phi_in_SYSCLK[i][18]) && training_done_SYSCLK[1];
            
            //% Status reset flag clock crossing.
            flag_sync u_status_reset(.in_clkA(status_reset[i]),.clkA(user_clk_i),
                                     .out_clkB(status_reset_SYSCLK[i]),.clkB(sysclk_i));
            //% Echo flag clock crossing.
            flag_sync u_do_echo(.in_clkA(send_echo[i]),.clkA(user_clk_i),
                                .out_clkB(send_echo_SYSCLK[i]),.clkB(sysclk_i));
            //% Sync flag clock crossing.
            flag_sync u_do_sync(.in_clkA(send_sync[i]),.clkA(user_clk_i),
                                .out_clkB(send_sync_SYSCLK[i]),.clkB(sysclk_i));
            //% ISERDES reset clock crossing
            flag_sync u_iserdes_reset(.in_clkA(iserdes_reset[i]),.clkA(user_clk_i),
                                      .out_clkB(iserdes_reset_dataclk_div2[i]),.clkB(dataclk_div2_i));                                
            //% OSERDES reset clock crossing
            flag_sync u_oserdes_reset(.in_clkA(oserdes_reset[i]),.clkA(user_clk_i),
                                      .out_clkB(oserdes_reset_SYSCLK[i]),.clkB(sysclk_i));
            //% Echo ready clock crossing
            flag_sync u_echo_ready(.in_clkA(echo_ready_SYSCLK[i]),.clkA(sysclk_i),
                                   .out_clkB(echo_ready[i]),.clkB(user_clk_i));
                                   
            //% Train latch flag clock crossing
            flag_sync u_train_latch(.in_clkA(train_latch_SYSCLK[i]),.clkA(sysclk_i),
                                    .out_clkB(train_latch[i]),.clkB(user_clk_i));
            //% Train latch seen flag clock crossing
            flag_sync u_train_latch_seen(.in_clkA(train_latch_seen[i]),.clkA(user_clk_i),
                                         .out_clkB(train_latch_seen_SYSCLK[i]),.clkB(sysclk_i));
                                         
            //% Echo handler.
            glitc_intercom_echo_handler #(.LATENCY_WIDTH(LATENCY_WIDTH)) u_echo_handler(.clk_i(sysclk_i),
                                                       .status_rst_i(status_reset_SYSCLK[i]),
                                                       .echo_in_i(echo_in[i]),
                                                       .echo_out_o(echoing[i]),
                                                       .echo_send_i(send_echo_SYSCLK[i]),
                                                       .echo_ready_o(echo_ready_SYSCLK[i]),
                                                       .echo_seen_o(echo_seen[i]),
                                                       .echo_latency_o(echo_latency[LATENCY_WIDTH*i +: LATENCY_WIDTH]));
            //% Training handler.
            glitc_intercom_training u_training(.clk_i(sysclk_i),
                                               .dat_i(phi_in_SYSCLK[i]),
                                               .training_done_i(training_done_SYSCLK[1]),
                                               .train_latch_o(train_latch_SYSCLK[i]),
                                               .train_latch_seen_i(train_latch_seen_SYSCLK[i]),
                                               .train_o(train[20*i +: 20]));
            //% Buffers.
            glitc_intercom_input_buffers #(.NBITS(5)) u_buffers(.IN_P(phi_in_p[i]),.IN_N(phi_in_n[i]),
                                                                .OUT_P(phi_out_p[i]),.OUT_N(phi_out_n[i]),
                                                                .in_o(phi_in[i]),.out_i(phi_out[i]),
                                                                .disable_i(input_buffer_disable[i]));
            //% ISERDES
            glitc_intercom_iserdes_v2 #(.RLOC_ISERDES(RLOC_ISERDES[rloc_iserdes_bits(i-1) +: rloc_iserdes_bits(i)]),
                                        .RLOC_FF(RLOC_FF[rloc_ff_bits(i-1) +: rloc_ff_bits(i)]),
                                        .NBITS(5)) 
                  u_iserdes(.user_clk_i(user_clk_i),
                            .ctrl_i(ctrl_i),
                            .chan_i(4*i + 3),
                            .en_i(1'b1),
                            .dataclk_i(dataclk_i),
                            .dataclk_div2_i(dataclk_div2_i),
                            .sysclk_i(sysclk_i),
                            .rst_dataclk_div2_i(iserdes_reset_dataclk_div2[i]),
                            .in_i(phi_in[i]),
                            .oq_o(phi_in_SYSCLK[i]));
            //% OSERDES
            glitc_intercom_oserdes_v2 #(.INVERT(OSERDES_INVERT[i]),.NBITS(5))
                  u_oserdes(.sysclk_i(sysclk_i),
                            .sysclkx2_i(sysclkx2_i),
                            .en_i(oserdes_clock_enable_SYSCLK[1]),
                            .rst_i(oserdes_reset_SYSCLK[i]),
                            .command_i(command_out[i]),
                            .corr_i(corr_out[i]),
                            .power_i(power_out[i]),
                            .oq_o(phi_out[i]));
            // Simple command mapping.
            // 00 if corr_enable_SYSCLK[1]
            // 01 if we're sending an echo
            // 10 if we're sending a sync
            // can't send sync and echo at the same time.
            assign command_out[i] = { !corr_enable_SYSCLK[1] && !echoing[i],
                                      !corr_enable_SYSCLK[1] && !sync_command[i] };
        end
    endgenerate       

    //% Sync generator. There's only one of these.
    glitc_intercom_sync_generator u_sync_generator(.clk_i(sysclk_i),.status_rst_i(status_reset_SYSCLK),
                                                   .sync_o(sync),                                                   
                                                   .sync_in_i(sync_in),
                                                   .send_sync_i(send_sync_SYSCLK),
                                                   .sync_command_o(sync_command),
                                                   .sync_received_o(sync_received),
                                                   .resynced_o(resynced));                                                   

    // debugging
    wire debug_bitslip;
    wire debug_load;
    wire [4:0] debug_idelay;
    RITC_bit_control u_debug(.sysclk_i(sysclk_i),.ctrl_clk_i(user_clk_i),
                             .ctrl_i(ctrl_i),
                             .bitslip_o(debug_bitslip),
                             .load_o(debug_load),
                             .delay_o(debug_idelay),
                             .channel_i(3'd3),
                             .bit_i(4'd10));

	reg [19:0] phi_up_in_debug = {20{1'b0}};
	reg [19:0] phi_down_in_debug = {20{1'b0}};
    reg [1:0] train_latch_debug = {2{1'b0}};
	reg [1:0] train_latch_seen_debug = {2{1'b0}};
	reg [1:0] echo_in_debug = {2{1'b0}};
    reg [1:0] sync_in_debug = {2{1'b0}};
    reg [1:0] ctrl_reg_debug = {2{1'b0}};
    reg [1:0] echoing_debug = {2{1'b0}};
    reg sync_debug = 0;
	always @(posedge sysclk_i) begin
        ctrl_reg_debug <= {ctrl_reg_debug[0],ctrl_i};
		phi_up_in_debug <= phi_in_SYSCLK[0];
		phi_down_in_debug <= phi_in_SYSCLK[1];
        train_latch_debug <= train_latch_SYSCLK;
        train_latch_seen_debug <= train_latch_seen_SYSCLK;
        echo_in_debug <= echo_in;
	    sync_in_debug <= sync_in;
        sync_debug <= sync;
        echoing_debug <= echoing;
	end

	assign debug_o = {sync_debug, echoing, ctrl_reg_debug[1],debug_idelay,debug_bitslip,debug_load,sync_in_debug, echo_in_debug, train_latch_seen_debug, train_latch_debug, phi_down_in_debug, phi_up_in_debug};
	assign sync_o = sync;
endmodule
