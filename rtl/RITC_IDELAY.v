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
// IDELAY infrastructure for the RITC.
// 
// Note that CH0_CLK is different from CH1_CLK/CH2_CLK. Because par gets 'confused'
// with the routing, we use a hard macro to instantiate the entire ILOGICE3/IDELAY/BUFR
// block. So CH0_CLK_Q is the registered version of CH0_CLK in the CLK_PS domain, and
// CH0_CLK_delay_BUFR is CH0_CLK, passed through the IDELAY, over to the BUFR (to use
// for clock counting).
module RITC_IDELAY(
		input CLK200,
		
		input [11:0] CH0,
		input CH0_CLK,
		input [11:0] CH1,
		input CH1_CLK,
		input [11:0] CH2,
		input CH2_CLK,
		input [2:0] REFCLKDIV2,
				
		output [11:0] CH0_delay,
		output CH0_CLK_delay,
		output [11:0] CH1_delay,
		output CH1_CLK_delay,
		output [11:0] CH2_delay,
		output CH2_CLK_delay,
				
		input CLK,
		input user_sel_i,
		input user_addr_i,
		input [7:0] user_dat_i,
		output [7:0] user_dat_o,
		input user_wr_i,
		input user_rd_i,
		input rst_i
);

 parameter [12:0] CH0_POLARITY = 13'h0000;
 parameter [12:0] CH1_POLARITY = 13'h0000;
 parameter [12:0] CH2_POLARITY = 13'h1FFF;
	// Interface decoder.
	wire [4:0] DELAY_IN;
	wire [5:0] ADDR_IN;
	wire LOAD;
	wire [2:0] idelayctrl_rdy;
	reg delay_rst = 0;
	RITC_IDELAY_interface u_idelay_if(.CLK(CLK),
												 .user_sel_i(user_sel_i),
												 .user_addr_i(user_addr_i),
												 .user_dat_i(user_dat_i),
												 .user_dat_o(user_dat_o),
												 .user_wr_i(user_wr_i),
												 .user_rd_i(user_rd_i),
												 
												 .delay_o(DELAY_IN),
												 .addr_o(ADDR_IN),
												 .load_o(LOAD),
												 .ready_i(idelayctrl_rdy));

	parameter GRP0_NAME = "IODELAY_0";
	parameter GRP0_CLOCK_NAME = "IODELAY_0";
	parameter GRP1_NAME = "IODELAY_1";
	parameter GRP1_CLOCK_NAME = "IODELAY_1";
	parameter GRP2_NAME = "IODELAY_2";
	parameter GRP2_CLOCK_NAME = "IODELAY_2";
	parameter IDELAYCTRL_LOC0 = "IDELAYCTRL_X0Y2";
	parameter IDELAYCTRL_LOC1 = "IDELAYCTRL_X0Y3";
	parameter IDELAYCTRL_LOC2 = "IDELAYCTRL_X0Y4";

	(* IODELAY_GROUP = GRP0_NAME *)
	(* LOC = IDELAYCTRL_LOC0 *)
	IDELAYCTRL u_idelayctrl0(.REFCLK(CLK200),.RST(delay_rst),.RDY(idelayctrl_rdy[0]));
	(* IODELAY_GROUP = GRP1_NAME *)
	(* LOC = IDELAYCTRL_LOC1 *)
	IDELAYCTRL u_idelayctrl1(.REFCLK(CLK200),.RST(delay_rst),.RDY(idelayctrl_rdy[1]));
	(* IODELAY_GROUP = GRP2_NAME *)
	(* LOC = IDELAYCTRL_LOC2 *)
	IDELAYCTRL u_idelayctrl2(.REFCLK(CLK200),.RST(delay_rst),.RDY(idelayctrl_rdy[2]));
		
	wire [2:0] sel_CLK;
	wire [11:0] sel[2:0];
	
	reg [2:0] load_CLK = {3{1'b0}};
	reg [11:0] load_CH_CLK[2:0];
	reg [11:0] load_CH[2:0];
	integer l_i;
	initial begin
		for (l_i=0;l_i<3;l_i=l_i+1) begin
			load_CH_CLK[l_i] <= {12{1'b0}};
			load_CH[l_i] <= {12{1'b0}};
		end
	end
	reg [1:0] load_delay = 0;

	// Extend the input reset pulse long enough for the IDELAYCTRLs.
	reg [3:0] delay_rst_counter = {4{1'b0}};

	always @(posedge CLK) begin : RESET_EXTEND
		if (rst_i) delay_rst <= 1;
		else if (delay_rst_counter == {4{1'b1}}) delay_rst <= 0;

		if (delay_rst) delay_rst_counter <= delay_rst_counter + 1;
		else delay_rst_counter <= {4{1'b0}};
	end


	// Extend the LOAD pulses for the data by 1 clock.
	// They need to cross a clock domain.
	always @(posedge CLK) begin : LOAD_EXTEND_LOGIC
		load_delay <= {load_delay[0],LOAD};
	end
	integer j,k;
	always @(posedge CLK) begin : LOAD_LOGIC
		for (k=0;k<3;k=k+1) begin
			for (j=0;j<12;j=j+1) begin
				if (sel[k][j] && LOAD) load_CH_CLK[k][j] <= 1;
				else if (load_delay[1]) load_CH_CLK[k][j] <= 0;
			end
			load_CLK[k] <= sel_CLK[k] && LOAD;
		end
	end
	always @(posedge REFCLKDIV2[0]) load_CH[0] <= load_CH_CLK[0];
	always @(posedge REFCLKDIV2[1]) load_CH[1] <= load_CH_CLK[1];
	always @(posedge REFCLKDIV2[2]) load_CH[2] <= load_CH_CLK[2];
	
	wire [2:0] REFCLK_polarity_sel;
	wire [11:0] CH_polarity_sel[2:0];
	
	generate
		genvar i;
		assign REFCLK_polarity_sel[0] = CH0_POLARITY[12] ^  CH0_CLK;
		assign CH_polarity_sel[0] = CH0_POLARITY[11:0] ^ CH0;
		assign REFCLK_polarity_sel[1] = CH1_POLARITY[12] ^ CH1_CLK;
		assign CH_polarity_sel[1] = CH1_POLARITY[11:0] ^ CH1;
		assign REFCLK_polarity_sel[2] = CH2_POLARITY[12] ^ CH2_CLK;
		assign CH_polarity_sel[2] = CH2_POLARITY[11:0] ^ CH2;
		// We're going to place VCDL_REG_Q right under CH0_CLK_delay.
		// That way it has reproducible timing.
		assign sel_CLK[0] = (ADDR_IN[5:4] == 2'b00) && (ADDR_IN[3:0] == 4'hF);
		(* IODELAY_GROUP = GRP0_CLOCK_NAME *)
		IDELAYE2 #(.IDELAY_TYPE("VAR_LOAD"),
						.DELAY_SRC("IDATAIN"),
						.IDELAY_VALUE(0),
						.HIGH_PERFORMANCE_MODE("TRUE"),
						.SIGNAL_PATTERN("DATA"))
							CH0_clk_delay(.IDATAIN(REFCLK_polarity_sel[0]),.DATAIN(1'b0),
											  .DATAOUT(CH0_CLK_delay),
											  .CNTVALUEIN(DELAY_IN),.LD(load_CLK[0]),
											  .C(CLK),.CINVCTRL(1'b0),.CE(1'b0),.INC(1'b0));
		assign sel_CLK[1] = (ADDR_IN[5:4] == 2'b01) && (ADDR_IN[3:0] == 4'hF);
		(* IODELAY_GROUP = GRP1_CLOCK_NAME *)
		IDELAYE2 #(.IDELAY_TYPE("VAR_LOAD"),
						.DELAY_SRC("IDATAIN"),
						.IDELAY_VALUE(0),
						.HIGH_PERFORMANCE_MODE("TRUE"),
						.SIGNAL_PATTERN("DATA"))
							CH1_clk_delay(.IDATAIN(REFCLK_polarity_sel[1]),.DATAIN(1'b0),
											  .DATAOUT(CH1_CLK_delay),
											  .CNTVALUEIN(DELAY_IN),.LD(load_CLK[1]),
											  .C(CLK),.CINVCTRL(1'b0),.CE(1'b0),.INC(1'b0));
		assign sel_CLK[2] = (ADDR_IN[5:4] == 2'b10) && (ADDR_IN[3:0] == 4'hF);
		(* IODELAY_GROUP = GRP2_CLOCK_NAME *)
		IDELAYE2 #(.IDELAY_TYPE("VAR_LOAD"),
						.DELAY_SRC("IDATAIN"),
						.IDELAY_VALUE(0),
						.HIGH_PERFORMANCE_MODE("TRUE"),
						.SIGNAL_PATTERN("DATA"))
							CH2_clk_delay(.IDATAIN(REFCLK_polarity_sel[2]),.DATAIN(1'b0),
											  .DATAOUT(CH2_CLK_delay),
											  .CNTVALUEIN(DELAY_IN),.LD(load_CLK[2]),
											  .C(CLK),.CINVCTRL(1'b0),.CE(1'b0),.INC(1'b0));
		for (i=0;i<12;i=i+1) begin : LOOP
			assign sel[0][i] = (ADDR_IN[5:4] == 2'b00) && (ADDR_IN[3:0] == i);
			(* IODELAY_GROUP = GRP0_NAME *)
			IDELAYE2 #(.IDELAY_TYPE("VAR_LOAD"),
							.DELAY_SRC("IDATAIN"),
							.IDELAY_VALUE(0),
							.HIGH_PERFORMANCE_MODE("TRUE"),
							.SIGNAL_PATTERN("DATA"))
							CH0_bit_delay(.IDATAIN(CH_polarity_sel[0][i]),.DATAIN(1'b0),
											.DATAOUT(CH0_delay[i]),
											.CNTVALUEIN(DELAY_IN),.LD(load_CH[0][i]),
											.C(REFCLKDIV2[0]),.CINVCTRL(1'b0),.CE(1'b0),.INC(1'b0));
			assign sel[1][i] = (ADDR_IN[5:4] == 2'b01) && (ADDR_IN[3:0] == i);
			(* IODELAY_GROUP = GRP1_NAME *)
			IDELAYE2 #(.IDELAY_TYPE("VAR_LOAD"),
							.DELAY_SRC("IDATAIN"),
							.IDELAY_VALUE(0),
							.HIGH_PERFORMANCE_MODE("TRUE"),
							.SIGNAL_PATTERN("DATA"))
							CH1_bit_delay(.IDATAIN(CH_polarity_sel[1][i]),.DATAIN(1'b0),
											.DATAOUT(CH1_delay[i]),
											.CNTVALUEIN(DELAY_IN),.LD(load_CH[1][i]),
											.C(REFCLKDIV2[1]),.CINVCTRL(1'b0),.CE(1'b0),.INC(1'b0));
			assign sel[2][i] = (ADDR_IN[5:4] == 2'b10) && (ADDR_IN[3:0] == i);
			(* IODELAY_GROUP = GRP2_NAME *)
			IDELAYE2 #(.IDELAY_TYPE("VAR_LOAD"),
							.DELAY_SRC("IDATAIN"),
							.IDELAY_VALUE(0),
							.HIGH_PERFORMANCE_MODE("TRUE"),
							.SIGNAL_PATTERN("DATA"))
							CH2_bit_delay(.IDATAIN(CH_polarity_sel[2][i]),.DATAIN(1'b0),
											.DATAOUT(CH2_delay[i]),
											.CNTVALUEIN(DELAY_IN),.LD(load_CH[2][i]),
											.C(REFCLKDIV2[2]),.CINVCTRL(1'b0),.CE(1'b0),.INC(1'b0));
		end
	endgenerate

endmodule
