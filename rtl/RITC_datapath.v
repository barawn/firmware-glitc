`timescale 1ns / 1ps
module RITC_datapath(
		input [2:0] REFCLK,
		input DATACLK,
		input DATACLK_DIV2,
		input [11:0] CH0,
		input [11:0] CH1,
		input [11:0] CH2,
		
		input CLK,
		input RST,
		wire BITSLIP,
		wire [5:0] BITSLIP_ADDR,
		output [47:0] CH0_OUT,
		output [47:0] CH1_OUT,
		output [47:0] CH2_OUT,

		output [2:0] SERDES_CLKDIV,
		
		output [11:0] CH0_BYPASS,
		output [11:0] CH1_BYPASS,
		output [11:0] CH2_BYPASS
    );

	parameter USE_IOCLK = "FALSE";

	parameter GRP0_NAME = "IODELAY_0";
	parameter GRP1_NAME = "IODELAY_1";
	parameter GRP2_NAME = "IODELAY_2";
	
	//% High speed clock. Converts serial to parallel.
	wire [2:0] SERIAL_CLK;
	//% Low speed clock. Transfers parallel to system clock domain.
	wire [2:0] PARALLEL_CLK;

	wire [11:0] CH_input_arr[2:0];
	wire [11:0] CH_bypass_arr[2:0];
	wire [47:0] CH_iserdes_out[2:0];
	wire [47:0] CH_fifo_out[2:0];

	
	reg [11:0] bitslip_flag_CLK[2:0];
	wire [11:0] bitslip_flag_REFCLKDIV2[2:0];
	reg [2:0] bitslip_ch_sel = {3{1'b0}};
	reg [3:0] bitslip_addr_pipe = {4{1'b0}};
	
	integer bs_i;
	initial begin
		for (bs_i=0;bs_i<3;bs_i=bs_i+1) begin
			bitslip_flag_CLK[bs_i] <= {12{1'b0}};
		end
	end
	assign CH_input_arr[0] = CH0;
	assign CH_input_arr[1] = CH1;
	assign CH_input_arr[2] = CH2;
	
	generate
		genvar ci;
		if (USE_IOCLK == "TRUE") begin : IOCLK_INFRASTRUCTURE
			for (ci=0;ci<3;ci=ci+1) begin : CLKBUF
				BUFIO u_bufio(.I(REFCLK[ci]),.O(SERIAL_CLK[ci]));
				BUFR #(.BUFR_DIVIDE(2)) u_bufr(.I(REFCLK[ci]),.O(PARALLEL_CLK[ci]),
														 .CLR(RST),.CE(1'b1));
			end
		end else begin : DATACLK_INFRASTRUCTURE
			assign SERIAL_CLK = { DATACLK, DATACLK, DATACLK };
			assign PARALLEL_CLK = { DATACLK_DIV2, DATACLK_DIV2, DATACLK_DIV2 };
		end
	endgenerate

	reg [2:0] reset_flag_PARALLELCLK = {3{1'b0}};
	reg [2:0] reset_rereg_PARALLELCLK = {3{1'b0}};
	always @(posedge PARALLEL_CLK[0] or posedge RST) begin
		if (RST) reset_flag_PARALLELCLK[0] <= 1;
		else if (reset_rereg_PARALLELCLK[0]) reset_flag_PARALLELCLK[0] <= 0;
	end
	always @(posedge PARALLEL_CLK[0]) reset_rereg_PARALLELCLK[0] <= reset_flag_PARALLELCLK[0];
	
	always @(posedge PARALLEL_CLK[1] or posedge RST) begin
		if (RST) reset_flag_PARALLELCLK[1] <= 1;
		else if (reset_rereg_PARALLELCLK[1]) reset_flag_PARALLELCLK[1] <= 0;
	end
	always @(posedge PARALLEL_CLK[1]) reset_rereg_PARALLELCLK[1] <= reset_flag_PARALLELCLK[1];

	always @(posedge PARALLEL_CLK[2] or posedge RST) begin
		if (RST) reset_flag_PARALLELCLK[2] <= 1;
		else if (reset_rereg_PARALLELCLK[2]) reset_flag_PARALLELCLK[2] <= 0;
	end
	always @(posedge PARALLEL_CLK[2]) reset_rereg_PARALLELCLK[2] <= reset_flag_PARALLELCLK[2];


	// Decode the address.
	integer bs_j;
	// Demultiplex the bitslip flag. Still in CLK domain.
	always @(posedge CLK) begin
		bitslip_addr_pipe <= BITSLIP_ADDR[3:0];
		bitslip_ch_sel[0] <= BITSLIP && (BITSLIP_ADDR[5:4] == 2'b00);
		bitslip_ch_sel[1] <= BITSLIP && (BITSLIP_ADDR[5:4] == 2'b01);
		bitslip_ch_sel[2] <= BITSLIP && (BITSLIP_ADDR[5:4] == 2'b10);
		for (bs_j=0;bs_j<12;bs_j=bs_j+1) begin
			bitslip_flag_CLK[0][bs_j] <= (bitslip_ch_sel[0] && bitslip_addr_pipe == bs_j);
			bitslip_flag_CLK[1][bs_j] <= (bitslip_ch_sel[1] && bitslip_addr_pipe == bs_j);
			bitslip_flag_CLK[2][bs_j] <= (bitslip_ch_sel[2] && bitslip_addr_pipe == bs_j);
		end
	end	

	// Unbelievably, you have to *tell* Xilinx not to be a moron here...
	// All of the ISERDESes will get placed in the top component (associated with the + side)
	// We want to put the IODELAYs in the - component. So first step is to create a new
	// submodule that can have its own RLOCs.
	//
	// Then, in the submodule, give the ISERDES each an RLOC constraint (on the RPM grid because
	// the ISERDES and IODELAY are different types).
	//
	// The ISERDES should get placed in the top, the IODELAY should get placed in the bottom, and
	// hopefully no one will be a moron anymore.
	generate
		genvar i,j;
		for (i=0;i<3;i=i+1) begin : CH
			for (j=0;j<12;j=j+1) begin : BIT
				reg bitslip_flag_reg = 0;
				flag_sync u_bitslip_flag_sync(.clkA(CLK),.clkB(PARALLEL_CLK[i]),
														.in_clkA(bitslip_flag_CLK[i][j]),
														.out_clkB(bitslip_flag_REFCLKDIV2[i][j]));
				always @(posedge PARALLEL_CLK[i]) bitslip_flag_reg <= bitslip_flag_REFCLKDIV2[i][j];
				if (i == 0) begin : CH0
					ISERDES_internal_loop #(.LOOP_DELAY(11),.IODELAY_GRP_NAME(GRP0_NAME)) 
																		  u_bit(.CLK_BUFIO(SERIAL_CLK[i]),
																				  .CLK_BUFR(PARALLEL_CLK[i]),
																				  .D(CH_input_arr[i][j]),
																				  .RST(reset_flag_PARALLELCLK[0]),
																				  .BITSLIP(bitslip_flag_reg),
																				  .BYPASS(CH_bypass_arr[i][j]),
																				  .Q(CH_iserdes_out[i][4*j +: 4]));
				end else if (i == 1) begin : CH1
					ISERDES_internal_loop #(.LOOP_DELAY(11),.IODELAY_GRP_NAME(GRP1_NAME)) 
																		  u_bit(.CLK_BUFIO(SERIAL_CLK[i]),
																				  .CLK_BUFR(PARALLEL_CLK[i]),
																				  .D(CH_input_arr[i][j]),
																				  .RST(reset_flag_PARALLELCLK[1]),
																				  .BITSLIP(bitslip_flag_reg),
																				  .BYPASS(CH_bypass_arr[i][j]),
																				  .Q(CH_iserdes_out[i][4*j +: 4]));
				end else if (i == 2) begin : CH2
					ISERDES_internal_loop #(.LOOP_DELAY(11),.IODELAY_GRP_NAME(GRP2_NAME)) 
																		  u_bit(.CLK_BUFIO(SERIAL_CLK[i]),
																				  .CLK_BUFR(PARALLEL_CLK[i]),
																				  .D(CH_input_arr[i][j]),
																				  .RST(reset_flag_PARALLELCLK[2]),
																				  .BITSLIP(bitslip_flag_reg),
																				  .BYPASS(CH_bypass_arr[i][j]),
																				  .Q(CH_iserdes_out[i][4*j +: 4]));
				end
			end
			RITC_simple_fifo #(.WIDTH(48)) u_simple_fifo(.DATA_IN(CH_iserdes_out[i]),
																		.ICLK(PARALLEL_CLK[i]),
																		.RST_ICLK(reset_flag_PARALLELCLK[i]),
																		.DATA_OUT(CH_fifo_out[i]),
																		.RST_OCLK(RST),
																		.OCLK(CLK));
		end
	endgenerate
	
	wire [47:0] CH_scramble[2:0];
	// The MSB of the data out of the SERDES is the first data out.
	// [0],[4],[8] is sample 12.
	// [1],[5],[9] is sample 8.
	// [2],[6],[10] is sample 4.
	// [3],[7],[11] is sample 0.
	//
	// The GLITC module wants the oldest data at the LSB.
	// So we have to scramble the heck out of things here.
	// 
	generate
		genvar bs,ch;
		for (ch=0;ch<3;ch=ch+1) begin : CH_SCR_LP
			for (bs=0;bs<12;bs=bs+1) begin : BIT_SCR_LP
				assign CH_scramble[ch][bs] = CH_fifo_out[ch][4*bs];
				assign CH_scramble[ch][12+bs] = CH_fifo_out[ch][4*bs+1];
				assign CH_scramble[ch][24+bs] = CH_fifo_out[ch][4*bs+2];
				assign CH_scramble[ch][36+bs] = CH_fifo_out[ch][4*bs+3];
			end
		end
	endgenerate
	
	assign CH0_OUT = CH_scramble[0];
	assign CH1_OUT = CH_scramble[1];
	assign CH2_OUT = CH_scramble[2];
	
	assign CH0_BYPASS = CH_bypass_arr[0];
	assign CH1_BYPASS = CH_bypass_arr[1];
	assign CH2_BYPASS = CH_bypass_arr[2];
	
	assign SERDES_CLKDIV = PARALLEL_CLK;
endmodule
