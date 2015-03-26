`timescale 1ns / 1ps
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
// RITC IDELAY interface, v2.
// 6 total channels.
module RITC_IDELAY_v2(
		input clk_i,
		input addr_i,
		input [31:0] dat_i,
		output [31:0] dat_o,
		input wr_i,
		
		input CLK200,		
		
		input DATACLK_DIV2,		
		input [11:0] CH0,
		input [11:0] CH1,
		input [11:0] CH2,
		input [11:0] CH3,
		input [11:0] CH4,
		input [11:0] CH5,
		input [5:0] CH_CLK,
		
		output [11:0] CH0_delay,
		output [11:0] CH1_delay,
		output [11:0] CH2_delay,
		output [11:0] CH3_delay,
		output [11:0] CH4_delay,
		output [11:0] CH5_delay,
		output [5:0] CH_CLK_delay		
    );
	parameter GRP0_CLK_NAME = "IODELAY_14";
	parameter GRP0_NAME = "IODELAY_14";
	parameter GRP1_CLK_NAME = "IODELAY_15";
	parameter GRP1_NAME = "IODELAY_15";
	parameter GRP2_CLK_NAME = "IODELAY_16";
	parameter GRP2_NAME = "IODELAY_16";
	parameter GRP3_CLK_NAME = "IODELAY_34";
	parameter GRP3_NAME = "IODELAY_34";
	parameter GRP4_CLK_NAME = "IODELAY_35";
	parameter GRP4_NAME = "IODELAY_35";
	parameter GRP5_CLK_NAME = "IODELAY_13";
	parameter GRP5_NAME = "IODELAY_13";
	
	parameter [12:0] CH0_POLARITY = 13'h0000;
	parameter [12:0] CH1_POLARITY = 13'h0000;
	parameter [12:0] CH2_POLARITY = 13'h1FFF;
	parameter [12:0] CH3_POLARITY = 13'h0000;
	parameter [12:0] CH4_POLARITY = 13'h0000;
	parameter [12:0] CH5_POLARITY = 13'h1FFF;

	localparam [5:0] CLK_POLARITY = {CH5_POLARITY[12],CH4_POLARITY[12],CH3_POLARITY[12],CH2_POLARITY[11],CH1_POLARITY[12],CH0_POLARITY[12]};
	localparam [71:0] CH_POLARITY = {CH5_POLARITY[11:0],
												CH4_POLARITY[11:0],
												CH3_POLARITY[11:0],
												CH2_POLARITY[11:0],
												CH1_POLARITY[11:0],
												CH0_POLARITY[11:0]};

	wire [11:0] CH_in[5:0];
	wire [11:0] CH_out[5:0];
	assign CH_in[0] = CH0;
	assign CH_in[1] = CH1;
	assign CH_in[2] = CH2;
	assign CH_in[3] = CH3;
	assign CH_in[4] = CH4;
	assign CH_in[5] = CH5;
	assign CH0_delay = CH_out[0];
	assign CH1_delay = CH_out[1];
	assign CH2_delay = CH_out[2];
	assign CH3_delay = CH_out[3];
	assign CH4_delay = CH_out[4];
	assign CH5_delay = CH_out[5];

	// 6 bits for delay value, and then 2 bits for channel, and 4 bits for bit select, and 1 bit for RITC select,
	// and 1 bit to verify load.
	reg [5:0] delay_val = {6{1'b0}};
	reg [3:0] bit_val = {4{1'b0}};
	reg [1:0] ch_val = {2{1'b0}};
	reg ritc_val = 0;
	reg load_value = 0;
	
	reg delay_rst_reg = 0;
	reg [3:0] delay_rst_counter = {4{1'b0}};
	wire [4:0] delay_rst_counter_plus1 = delay_rst_counter + 1;

	wire [5:0] idelayctrl_rdy;	
	wire [31:0] status_data = {{26{1'b0}},idelayctrl_rdy};
	wire [31:0] delay_data = {{18{1'b0}},load_value,ritc_val,ch_val,bit_val,delay_val}; 
	//% Interface logic.
	always @(posedge clk_i) begin : INTERFACE_LOGIC
		if (addr_i && wr_i) begin
			delay_val <= dat_i[0 +: 6];
			bit_val <= dat_i[6 +: 4];
			ch_val <= dat_i[10 +: 2];
			ritc_val <= dat_i[11];
		end
		load_value <= addr_i && wr_i && dat_i[12];

		if (!addr_i && wr_i) delay_rst_reg <= dat_i[0];
		else if (delay_rst_counter_plus1[4]) delay_rst_reg <= 0;
		
		if (delay_rst_reg) delay_rst_counter <= delay_rst_counter_plus1;
		else delay_rst_counter <= {4{1'b0}};
	end
	assign dat_o = (addr_i) ? delay_data : status_data;
	
	// Load logic. load_value is much slower than
	// DATACLK_DIV2, so it shouldn't be a problem
	// crossing.
	wire [5:0] sel_CLK;
	wire [11:0] sel[5:0];
	
	reg [5:0] load_clk_i = {6{1'b0}};
	
	reg [5:0] load_CLK_clk_i = {6{1'b0}};
	reg [5:0] load_CLK = {6{1'b0}};
	reg [11:0] load_CH_clk_i[5:0];
	reg [11:0] load_CH[5:0];
	integer l_i;
	initial begin
			 for (l_i=0;l_i<6;l_i=l_i+1) begin
						load_CH_clk_i[l_i] <= {12{1'b0}};
						load_CH[l_i] <= {12{1'b0}};
			 end
	end
`define IDELAY_CLK( x ) \
		(* IODELAY_GROUP = GRP``x``_CLK_NAME *)  									\
		IDELAYE2 #(.IDELAY_TYPE("VAR_LOAD"),	  										\
					.DELAY_SRC("IDATAIN"),  		  										\
					.IDELAY_VALUE(0),					  										\
					.HIGH_PERFORMANCE_MODE("FALSE"),										\
					.SIGNAL_PATTERN("DATA"))												\
				CH``x``_clk_delay(.IDATAIN(CLK_pol_sel[ x ]),.DATAIN(1'b0),  \
								  .DATAOUT(CH_CLK_delay[ x ]),							\
								  .CNTVALUEIN(delay_val),.LD(load_CLK[ x ]),		\
								  .C(DATACLK_DIV2),.CINVCTRL(1'b0),.CE(1'b0),.INC(1'b0))
`define IDELAY_CH( x , y ) \
		(* IODELAY_GROUP = GRP``x``_NAME *)													\
		IDELAYE2 #(.IDELAY_TYPE("VAR_LOAD"),													\
					  .DELAY_SRC("IDATAIN"),														\
					  .IDELAY_VALUE(0),																\
					  .HIGH_PERFORMANCE_MODE("FALSE"),											\
					  .SIGNAL_PATTERN("DATA"))														\
			  CH``x``_bit_delay(.IDATAIN(CH_pol_sel[ x ][ y ]),.DATAIN(1'b0),		\
								 .DATAOUT(CH_out[ x ][ y ]),									\
								 .CNTVALUEIN(delay_val),.LD(load_CH[ x ][ y ]),			\
								 .C(DATACLK_DIV2),.CINVCTRL(1'b0),.CE(1'b0),.INC(1'b0))


	generate
		genvar i,j,k,l;
		wire [6:0] CLK_pol_sel;
		wire [11:0] CH_pol_sel[6:0];
		
		for (i=0;i<2;i=i+1) begin : RLOOP
			for (j=0;j<3;j=j+1) begin : CHLOOP
				assign CLK_pol_sel[3*i+j] = CLK_POLARITY[3*i+j] ^ CH_CLK[3*i+j];
				assign sel_CLK[3*i+j] = (bit_val == 4'hF) && (ch_val == j) && (ritc_val == i);
				always @(posedge clk_i) begin : LOAD_CLK
					if (sel_CLK[3*i+j] && load_value) load_CLK_clk_i[3*i+j] <= 1;
					else load_CLK_clk_i[3*i+j] <= 0;
				end
				always @(posedge clk_i) begin : LOAD_CLK_DATACLK_DIV2
					load_CLK[3*i+j] <= load_CLK_clk_i[3*i+j];
				end
				for (k=0;k<12;k=k+1) begin : BITLOOP
					assign CH_pol_sel[3*i+j][k] = CH_POLARITY[12*(3*i+j)+k] ^ CH_in[3*i+j][k];
					assign sel[3*i+j][k] = (bit_val == k) && (ch_val == j) && (ritc_val == i);
					always @(posedge clk_i) begin : LOAD_CH
							if (sel[3*i+j][k] && load_value) load_CH_clk_i[3*i+j][k] <= 1;
							else load_CH_clk_i[3*i+j][k] <= 0;
					end
					always @(posedge DATACLK_DIV2) begin : LOAD_CH_DATACLK_DIV2
						load_CH[3*i+j][k] <= load_CH_clk_i[3*i+j][k];
					end
				end
			end
		end
		
		`IDELAY_CLK( 0 );
		`IDELAY_CLK( 1	);
		`IDELAY_CLK( 2 );
		`IDELAY_CLK( 3 );
		`IDELAY_CLK( 4 );
		`IDELAY_CLK( 5 );
		for (l=0;l<12;l=l+1) begin : IDBIT
			`IDELAY_CH( 0, l);
			`IDELAY_CH( 1, l);
			`IDELAY_CH( 2, l);
			`IDELAY_CH( 3, l);
			`IDELAY_CH( 4, l);
			`IDELAY_CH( 5, l);
		end
	endgenerate
	
  (* IODELAY_GROUP = GRP0_NAME *)
  IDELAYCTRL u_idelayctrl0(.REFCLK(CLK200),.RST(delay_rst_reg),.RDY(idelayctrl_rdy[0]));
  (* IODELAY_GROUP = GRP1_NAME *)
  IDELAYCTRL u_idelayctrl1(.REFCLK(CLK200),.RST(delay_rst_reg),.RDY(idelayctrl_rdy[1]));
  (* IODELAY_GROUP = GRP2_NAME *)
  IDELAYCTRL u_idelayctrl2(.REFCLK(CLK200),.RST(delay_rst_reg),.RDY(idelayctrl_rdy[2]));
  (* IODELAY_GROUP = GRP3_NAME *)
  IDELAYCTRL u_idelayctrl3(.REFCLK(CLK200),.RST(delay_rst_reg),.RDY(idelayctrl_rdy[3]));
  (* IODELAY_GROUP = GRP4_NAME *)
  IDELAYCTRL u_idelayctrl4(.REFCLK(CLK200),.RST(delay_rst_reg),.RDY(idelayctrl_rdy[4]));
  (* IODELAY_GROUP = GRP5_NAME *)
  IDELAYCTRL u_idelayctrl5(.REFCLK(CLK200),.RST(delay_rst_reg),.RDY(idelayctrl_rdy[5]));

	
endmodule
