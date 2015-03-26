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

/** \brief REFCLK counters for all 6 possible input clocks.
 *
 * REFCLK counters work by having small counters in the REFCLK domain,
 * and using the high bit of that, resynchronized in the SYSCLK domain,
 * to indicate a count.
 *
 * That is, REFCLK is divided down by 8 via a 3-bit counter.
 * The top bit (which goes high every 8 cycles) is sent over to
 * the SYSCLK domain. It has a native period of ~25 ns (4 SYSCLK cycles)
 * so a rising edge can always be detected, even if 1 of the 2 "high"
 * cycles is lost due to metastability.
 *
 * Because the count is a multiple of 4 (the number of clocks output in
 * a VCDL cycle) I don't think it's really possible for clocks to be 'lost'
 * when REFCLK is running too fast.
 *
 * In the SYSCLK domain, a rising edge detector watches the resynchronized
 * "high" bit, and upon seeing a rising edge, it increments a counter.
 *
 * After 2048 SYSCLK cycles (after which 512 rising edges should have been
 * seen), the count is passed back to the user clock domain.
 * 
 * Each REFCLK counter only counts when it is enabled.
 */
module GLITC_refclk_counters(
		input clk_i,
		input SYSCLK,
		input [5:0] 	refclk_bufr_i,
		input [3:0] 	refclk_select_i,
		input 			refclk_select_wr_i,
		output [9:0] 	refclk_count_o
    );

	//< REFCLK counter in user_clk_i domain.
	reg [9:0] refclk_counter = {10{1'b0}};
	//< REFCLK counter in SYSCLK domain.
	reg [9:0] refclk_counter_SYSCLK = {10{1'b0}};

	//< Individual REFCLK flags. Expanded to power of 2.
	wire [7:0] refclk_count_flag;
	//< Multiplexed refclk counter flag.
	wire refclk_count_flag_multiplexed;
	//< Individual REFCLK counter enables.
	reg [5:0] refclk_count_enable = {6{1'b0}};
	
	//< Flag to indicate to user_clk_i domain that refclk counter is ready.
	wire refclk_counter_ready_SYSCLK;
	//< Refclk counter ready flag in user_clk domain.
	wire refclk_counter_ready_user_clk;
	//< Flag to indicate to SYSCLK domain that refclk counter can start again.
	reg refclk_counter_ack_user_clk = 0;
	//< Counter ack flag back in SYSCLK domain.
	wire refclk_counter_ack_SYSCLK;
	//< Flag to indicate to SYSCLK that the refclk_select has changed, in SYSCLK domain.
	wire refclk_select_wr_SYSCLK;
	//< Flag indicating that the write has been seen.
	reg [1:0] refclk_select_wr_seen_SYSCLK = 2'b00;
	//< Flag back to user clock domain that SYSCLK has seen write.
	wire refclk_select_wr_seen_user_clk;
	//< Refclk select in SYSCLK domain.
	reg [3:0] refclk_select = {4{1'b0}};
	//< Refclk counter reset in SYSCLK domain.
	wire refclk_counter_reset_SYSCLK = (refclk_counter_ack_SYSCLK || refclk_select_wr_seen_SYSCLK[1]);

	//< SYSCLK domain counter. We count 2048 cycles.
	reg [10:0] refclk_sysclk_counter = {11{1'b0}};
	//< SYSCLK domain counter, plus 1.
	wire [11:0] refclk_sysclk_counter_plus_one = (refclk_sysclk_counter + 1);
	//< Holdoff in SYSCLK domain after measurement complete, before restarting.
	reg sysclk_counter_holdoff = 0;
	//< Holdoff in user_clk domain after a change in clock, before it's acknowledged.
	reg clk_counter_holdoff = 0;
	
	// Synchronizers.
	//< Sync the 'write' of a new clock select over to SYSCLK.
	flag_sync u_wr_sync(.in_clkA(refclk_select_wr_i), .clkA(clk_i),
							  .out_clkB(refclk_select_wr_SYSCLK), .clkB(SYSCLK));
	//< Sync the acknowledgement of the write seen back to user_clk.
	flag_sync u_wr_ack_sync(.in_clkA(refclk_select_wr_seen_SYSCLK[1]),.clkA(SYSCLK),
									.out_clkB(refclk_select_wr_seen_user_clk),.clkB(clk_i));
	//< Sync the flag that the counter is ready to user_clk.
	flag_sync u_ready_sync(.in_clkA(refclk_counter_ready_SYSCLK), .clkA(SYSCLK),
								  .out_clkB(refclk_counter_ready_user_clk),.clkB(clk_i));
	//< Sync the acknowledgement back from user_clk.
	flag_sync u_ack_sync(.in_clkA(refclk_counter_ack_user_clk), .clkA(clk_i),
								.out_clkB(refclk_counter_ack_SYSCLK),.clkB(SYSCLK));

	assign refclk_counter_ready_SYSCLK = refclk_sysclk_counter_plus_one[11];
	// SYSCLK domain.														  
	always @(posedge SYSCLK) begin
			// Counter.
			if (!sysclk_counter_holdoff) refclk_sysclk_counter <= refclk_sysclk_counter_plus_one;
			else	refclk_sysclk_counter <= {11{1'b0}};
			
			// Holdoff logic. We holdoff after we complete a measurement, and also when we change counters.
			if (refclk_sysclk_counter_plus_one[11] || refclk_select_wr_SYSCLK) sysclk_counter_holdoff <= 1;
			else if (refclk_counter_reset_SYSCLK) sysclk_counter_holdoff <= 0;
		
			// Write seen logic.
			refclk_select_wr_seen_SYSCLK <= {refclk_select_wr_seen_SYSCLK[0],refclk_select_wr_SYSCLK};
		
			if (!sysclk_counter_holdoff) begin
				if (refclk_count_flag_multiplexed) refclk_counter_SYSCLK <= refclk_counter_SYSCLK + 1;
			end else if (refclk_counter_reset_SYSCLK) refclk_counter_SYSCLK <= {10{1'b0}};			

			if (refclk_select_wr_SYSCLK) refclk_select <= refclk_select_i;
	end
	// clk_i domain.
	always @(posedge clk_i) begin
			if (refclk_select_wr_i) clk_counter_holdoff <= 1;
			else if (refclk_select_wr_seen_user_clk) clk_counter_holdoff <= 0;
			
			if (refclk_select_wr_i || clk_counter_holdoff) refclk_counter <= {10{1'b0}};
			else if (refclk_counter_ready_user_clk) refclk_counter <= refclk_counter_SYSCLK;
			
			refclk_counter_ack_user_clk <= refclk_counter_ready_user_clk;			
	end
	
	generate
		genvar i;
		for (i=0;i<6;i=i+1) begin : REFCLK
			// clk_i domain
			always @(posedge clk_i) begin : EN
				if (refclk_select_i == i) refclk_count_enable[i] <= 1;
				else refclk_count_enable[i] <= 0;
			end
			// REFCLK domains.
			//< Small counter used to divide down REFCLK.
			reg [2:0] refclk_counter_flag_generator = {3{1'b0}};
			always @(posedge refclk_bufr_i[i]) begin : CF
				if (refclk_count_enable[i]) refclk_counter_flag_generator <= refclk_counter_flag_generator + 1;
				else refclk_counter_flag_generator <= {3{1'b0}};
			end
			// Sysclk domain.
			//< Synchronizer for REFCLK divided by 8.
			reg [2:0] refclk_counter_flag_generator_SYSCLK = {3{1'b0}};
			//< Rising edge of REFCLK/8 flag.
			reg refclk_counter_flag_SYSCLK = 0;
			always @(posedge SYSCLK) begin : CFS
				refclk_counter_flag_generator_SYSCLK <= 
					{ refclk_counter_flag_generator_SYSCLK[1:0], refclk_counter_flag_generator[2] };
				refclk_counter_flag_SYSCLK <= refclk_counter_flag_generator_SYSCLK[1] && !refclk_counter_flag_generator_SYSCLK[2];
			end
			assign refclk_count_flag[i] = refclk_counter_flag_SYSCLK;
		end
	endgenerate
	assign refclk_count_flag[6] = 0;
	assign refclk_count_flag[7] = 0;
	
	assign refclk_count_flag_multiplexed = refclk_count_flag[refclk_select] && !sysclk_counter_holdoff;
		
	assign refclk_count_o = refclk_counter;
endmodule
