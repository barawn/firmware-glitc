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
module RITC_phase_scanner_registers_v4(
		input CLK_PS,
		input user_clk_i,

		input [7:0] select_i,
		input select_wr_i,
		input user_scan_i,
		output user_scan_done_o,
		output [6:0] bit_scaler_o,
		output bit_scan_o,
		output [6:0] clk_scaler_o,
		output clk_scan_o,
		output [6:0] vcdl_scaler_o,
		output vcdl_scan_o,
		
		input [2:0] CLK_IN,
		input [11:0] CH0_IN,
		input [11:0] CH1_IN,
		input [11:0] CH2_IN,
		input VCDL_IN
    );

	wire [3:0] clks;
	assign clks[0] = CLK_IN[0];
	assign clks[1] = CLK_IN[1];
	assign clks[2] = CLK_IN[2];
	assign clks[3] = CLK_IN[1];

	// 2-stage decode. The bits are all nearby, so we demux
	// the bits first.
	wire [15:0] channel_bits[2:0];
	assign channel_bits[0] = {CH0_IN[7:4],CH0_IN};
	assign channel_bits[1] = {CH1_IN[7:4],CH1_IN};
	assign channel_bits[2] = {CH2_IN[7:4],CH2_IN};
	
	reg [2:0] channel_bit_scan = {3{1'b0}};
	reg [2:0] channel_bit_scan_sync = {3{1'b0}};
	
	// Now demux the channels.
	wire [3:0] bits;
	assign bits = {channel_bit_scan_sync[1],channel_bit_scan_sync};

	reg bit_latch = 0;
	reg [1:0] bit_latch_user_clk = {2{1'b0}};
	// bits is already non-metastable.
	reg bit_scan = 1'b0;
	reg clk_latch = 0;
	reg [1:0] clk_latch_user_clk = {2{1'b0}};
	// clks is metastable
	reg [1:0] clk_scan = {2{1'b0}};
	reg vcdl_latch = 0;
	reg [1:0] vcdl_latch_user_clk = {2{1'b0}};
	// vcdl is metastable
	reg [1:0] vcdl_scan = {2{1'b0}};
	
	wire scan_request_CLK_PS_flag_out;
	reg scan_request_CLK_PS = 0;
	wire select_wr_CLK_PS;
	reg [7:0] select_CLK_PS_latch = {8{1'b0}};
	reg [7:0] select_CLK_PS = {8{1'b0}};
	reg [6:0] ps_clk_counter = {7{1'b0}};
	wire [7:0] ps_clk_counter_plus_one = ps_clk_counter + 1;
	reg ps_clk_counter_done = 0;
	reg ps_clk_counter_done_flag = 0;
	wire ps_clk_counter_done_flag_user_clk;
	reg user_scan_done = 0;
	flag_sync u_sync_scan_req(.in_clkA(user_scan_i),.clkA(user_clk_i),
						  .out_clkB(scan_request_CLK_PS_flag_out),.clkB(CLK_PS));
	flag_sync u_sync_select_wr(.in_clkA(select_wr_i),.clkA(user_clk_i),
						  .out_clkB(select_wr_CLK_PS),.clkB(CLK_PS));
	flag_sync u_sync_scan_done(.in_clkA(ps_clk_counter_done_flag),.clkA(CLK_PS),
						  .out_clkB(ps_clk_counter_done_flag_user_clk),.clkB(user_clk_i));	
	
	reg [6:0] bit_scaler = {7{1'b0}};
	reg [6:0] clk_scaler = {7{1'b0}};
	reg [6:0] vcdl_scaler = {7{1'b0}};
	reg [6:0] bit_scaler_user_clk = {7{1'b0}};
	reg [6:0] clk_scaler_user_clk = {7{1'b0}};
	reg [6:0] vcdl_scaler_user_clk = {7{1'b0}};
	
	integer cbs_i;
	always @(posedge CLK_PS) begin
		// Multiplex the bits based on the select register.
		for (cbs_i=0;cbs_i<3;cbs_i=cbs_i+1) begin
			channel_bit_scan[cbs_i] <= channel_bits[cbs_i][select_CLK_PS[3:0]];
			channel_bit_scan_sync[cbs_i] <= channel_bit_scan[cbs_i];
		end
		// Multiplex the channels.
		bit_scan <= bits[select_CLK_PS[5:4]];
		// Multiplex the clocks.
		clk_scan <= {clk_scan[0],clks[select_CLK_PS[7:6]]};
		// Scan VCDL.
		vcdl_scan <= {vcdl_scan[0], VCDL_IN};
				
		// Capture the scan request.
		scan_request_CLK_PS <= scan_request_CLK_PS_flag_out;
		
		// Fan out the select register. This should be duplicatable easily.
		if (select_wr_CLK_PS) select_CLK_PS_latch <= select_i;
		select_CLK_PS <= select_CLK_PS_latch;
		
		// Scaler counter.
		if (scan_request_CLK_PS) ps_clk_counter <= {7{1'b0}};
		else if (!ps_clk_counter_plus_one[7]) ps_clk_counter <= ps_clk_counter_plus_one;
		// Register the scaler counter done bit, so we can fan it out.
		ps_clk_counter_done <= ps_clk_counter_plus_one[7];
		ps_clk_counter_done_flag <= ps_clk_counter_plus_one[7] && !ps_clk_counter_done;

		if (scan_request_CLK_PS) bit_latch <= bit_scan;
		if (scan_request_CLK_PS) bit_scaler <= {7{1'b0}};
		else if (!ps_clk_counter_done && bit_scan) bit_scaler <= bit_scaler + 1;
		
		if (scan_request_CLK_PS) clk_latch <= clk_scan[1];
		if (scan_request_CLK_PS) clk_scaler <= {7{1'b0}};
		else if (!ps_clk_counter_done && clk_scan[1]) clk_scaler <= clk_scaler + 1;
		
		if (scan_request_CLK_PS) vcdl_latch <= vcdl_scan[1];
		if (scan_request_CLK_PS) vcdl_scaler <= {7{1'b0}};
		else if (!ps_clk_counter_done && vcdl_scan[1]) vcdl_scaler <= vcdl_scaler + 1;
	end
	always @(posedge user_clk_i) begin
		bit_latch_user_clk <= {bit_latch_user_clk[0],bit_latch};
		clk_latch_user_clk <= {clk_latch_user_clk[0],clk_latch};
		vcdl_latch_user_clk <= {vcdl_latch_user_clk[0],vcdl_latch};
		if (ps_clk_counter_done_flag_user_clk) begin
			bit_scaler_user_clk <= bit_scaler;
			clk_scaler_user_clk <= clk_scaler;
			vcdl_scaler_user_clk <= vcdl_scaler;
		end
		if (user_scan_i) user_scan_done <= 0;
		else if (ps_clk_counter_done_flag_user_clk) user_scan_done <= 1;
	end

	assign bit_scaler_o = bit_scaler_user_clk;
	assign bit_scan_o = bit_latch_user_clk[1];
	assign clk_scaler_o = clk_scaler_user_clk;
	assign clk_scan_o = clk_latch_user_clk[1];
	assign vcdl_scaler_o = vcdl_scaler_user_clk;
	assign vcdl_scan_o = vcdl_latch_user_clk[1];

	assign user_scan_done_o = user_scan_done;
endmodule
