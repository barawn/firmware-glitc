`timescale 1ns / 1ps
//% @file glitc_infrastructure Contains glitc_infrastructure module.

//% @brief GLITC input data infrastructure (from RITC).
//%
//% The GLITC infrastructure module takes the input data, from the RITC, and
//% converts it down from 4 inputs/cycle to 16 inputs/cycle. 
//%
//% The GLITC supplies a data pulse at 1/32 of the desired frequency (81.25 MHz)
//% A reference output comes back at 4 times that (325 MHz).
//% The data then comes in DDR relative to that reference output (650 MHz).
//% And we get 4 samples (12 bits) per channel. 
module glitc_infrastructure(
		enable_i,
		A_P, A_N,
		AREF_P, AREF_N,
		B_P, B_N,
		BREF_P, BREF_N,
		C_P, C_N,
		CREF_P, CREF_N,
		clk,
		A_o,
		B_o,
		C_o,
		ACLK,
		BCLK,
		CCLK
	);

	// SKELETON INFRASTRUCTURE ONLY
	// 

	// APPARENTLY THIS SKELETON INFRASTRUCTURE WAS CRAP.
	// Now move to ISERDES2 based version. 
	
	input enable_i;
	input [11:0] A_P;
	input [11:0] A_N;
	input AREF_P;
	input AREF_N;
	
	input [11:0] B_P;
	input [11:0] B_N;
	input BREF_P;
	input BREF_N;
	
	input [11:0] C_P;
	input [11:0] C_N;
	input CREF_P;
	input CREF_N;
	
	input clk;
	output reg [47:0] A_o = {48{1'b0}};
	output reg [47:0] B_o = {48{1'b0}};
	output reg [47:0] C_o = {48{1'b0}};
	output ACLK;
	output BCLK;
	output CCLK;
	
	wire [11:0] inA[1:0];
	wire [11:0] inB[1:0];
	wire [11:0] inC[1:0];

	wire Aref, ArefPBUFIO2, ArefNBUFIO2, AreftoGCLK, ArefGCLK;
	wire Bref, BrefPBUFIO2, BrefNBUFIO2, BreftoGCLK, BrefGCLK;
	wire Cref, CrefPBUFIO2, CrefNBUFIO2, CreftoGCLK, CrefGCLK;

	IBUFGDS ibufAref(.I(AREF_P),.IB(AREF_N),.O(Aref));
	IBUFGDS ibufBref(.I(BREF_P),.IB(BREF_N),.O(Bref));
	IBUFGDS ibufCref(.I(CREF_P),.IB(CREF_N),.O(Cref));
	BUFIO2 #(.DIVIDE_BYPASS("FALSE"),.USE_DOUBLER("TRUE"),.I_INVERT("FALSE"), .DIVIDE(4))	bufio2_ArefP(.I(Aref),.IOCLK(ArefPBUFIO2),.DIVCLK(AreftoGCLK));
	BUFIO2 #(.USE_DOUBLER("FALSE"),.I_INVERT("TRUE")) bufio2_ArefN(.I(Aref),.IOCLK(ArefNBUFIO2));
	BUFIO2 #(.DIVIDE_BYPASS("FALSE"),.USE_DOUBLER("TRUE"),.I_INVERT("FALSE"), .DIVIDE(4)) bufio2_BrefP(.I(Bref),.IOCLK(BrefPBUFIO2),.DIVCLK(BreftoGCLK));
	BUFIO2 #(.USE_DOUBLER("FALSE"),.I_INVERT("TRUE")) bufio2_BrefN(.I(Bref),.IOCLK(BrefNBUFIO2));

	BUFIO2 #(.DIVIDE_BYPASS("FALSE"),.USE_DOUBLER("TRUE"),.I_INVERT("FALSE"), .DIVIDE(4)) bufio2_CrefP(.I(Cref),.IOCLK(CrefPBUFIO2),.DIVCLK(CreftoGCLK));
	BUFIO2 #(.USE_DOUBLER("FALSE"),.I_INVERT("TRUE")) bufio2_CrefN(.I(Cref),.IOCLK(CrefNBUFIO2));

	// RITC clock outputs, divided by 2. Note that the RITC's outputs, provided you're in
	// the range where they give 4 samples per clock, are guaranteed to generate only 4
	// outputs for each VCDL_IN. The sampling speed needs to be locked more precisely by
	// delay-locking VCDL_OUT after a calibration mechanism. 
	//
	// So these are semisynchronous to the system clock.
	BUFG arefgclk(.I(AreftoGCLK),.O(ArefGCLK));
	BUFG brefgclk(.I(BreftoGCLK),.O(BrefGCLK));
	BUFG crefgclk(.I(CreftoGCLK),.O(CrefGCLK));

	wire [47:0] inA_AREF;
	wire [47:0] inB_BREF;
	wire [47:0] inC_CREF;

	generate
		genvar i;
		for (i=0;i<12;i=i+1) begin : ABCIBUF
			wire A_to_FF;
			wire B_to_FF;
			wire C_to_FF;
			IBUFDS ibufA(.I(A_P[i]),.IB(A_N[i]),.O(A_to_FF));
			IBUFDS ibufB(.I(B_P[i]),.IB(B_N[i]),.O(B_to_FF));
			IBUFDS ibufC(.I(C_P[i]),.IB(C_N[i]),.O(C_to_FF));
			ISERDES2 #(.DATA_RATE("DDR"), .DATA_WIDTH(4),.INTERFACE_TYPE("RETIMED")) Aserdes(.CLK0(ArefPBUFIO2),.CLK1(ArefNBUFIO2),
						  .CLKDIV(ArefGCLK),.CE0(1'b1),.D(A_to_FF),
						  .Q4(inA_AREF[3*12+i]),
						  .Q3(inA_AREF[2*12+i]),
						  .Q2(inA_AREF[1*12+i]),
						  .Q1(inA_AREF[0*12+i]));
			ISERDES2 #(.DATA_RATE("DDR"), .DATA_WIDTH(4), .INTERFACE_TYPE("RETIMED")) Bserdes(.CLK0(BrefPBUFIO2),.CLK1(BrefNBUFIO2),
						  .CLKDIV(BrefGCLK),.CE0(1'b1),.D(B_to_FF),
						  .Q4(inB_BREF[3*12+i]),
						  .Q3(inB_BREF[2*12+i]),
						  .Q2(inB_BREF[1*12+i]),
						  .Q1(inB_BREF[0*12+i]));
			ISERDES2 #(.DATA_RATE("DDR"), .DATA_WIDTH(4), .INTERFACE_TYPE("RETIMED")) Cserdes(.CLK0(CrefPBUFIO2),.CLK1(CrefNBUFIO2),
						  .CLKDIV(CrefGCLK),.CE0(1'b1),.D(C_to_FF),
						  .Q4(inC_CREF[3*12+i]),
						  .Q3(inC_CREF[2*12+i]),
						  .Q2(inC_CREF[1*12+i]),
						  .Q1(inC_CREF[0*12+i]));
		end		
	endgenerate

	reg [47:0] A_reg_in = {48{1'b0}};
	reg [47:0] B_reg_in = {48{1'b0}};
	reg [47:0] C_reg_in = {48{1'b0}};

	reg [47:0] A_reg_in_B = {48{1'b0}};
	reg [47:0] B_reg_in_B = {48{1'b0}};
	reg [47:0] C_reg_in_B = {48{1'b0}};

	reg dataA_valid = 0;
	reg dataB_valid = 0;
	reg dataC_valid = 0;
	reg buffer_select_ACLK = 0;
	reg buffer_select_BCLK = 0;
	reg buffer_select_CCLK = 0;
	reg buffer_select_CLK = 0;

	// OK, here we're in a slower clock domain, so we can run a bit healthier. 
	always @(posedge ArefGCLK) dataA_valid <= 1;
	always @(posedge ArefGCLK) begin 
		if (!buffer_select_ACLK) begin
			A_reg_in <= inA_AREF; 
			buffer_select_ACLK <= 1;
		end else begin
			A_reg_in_B <= inA_AREF;
			buffer_select_ACLK <= 0;
		end
	end
	always @(posedge BrefGCLK) dataB_valid <= 1;
	always @(posedge BrefGCLK) begin 
		if (!buffer_select_BCLK) begin
			B_reg_in <= inB_BREF; 
			buffer_select_BCLK <= 1;
		end else begin
			B_reg_in_B <= inB_BREF;
			buffer_select_BCLK <= 0;
		end
	end
	always @(posedge CrefGCLK) dataC_valid <= 1;
	always @(posedge CrefGCLK) begin 
		if (!buffer_select_CCLK) begin
			C_reg_in <= inC_CREF; 
			buffer_select_CCLK <= 1;
		end else begin
			C_reg_in_B <= inC_CREF;
			buffer_select_CCLK <= 0;
		end
	end
	reg [47:0] dataA_clkN = {48{1'b0}};
	reg [47:0] dataB_clkN = {48{1'b0}};
	reg [47:0] dataC_clkN = {48{1'b0}};
	reg [47:0] dataA_clkP = {48{1'b0}};
	reg [47:0] dataB_clkP = {48{1'b0}};
	reg [47:0] dataC_clkP = {48{1'b0}};

	reg buffer_select_clkA = 0;
	reg buffer_select_clkB = 0;
	reg buffer_select_clkC = 0;
	reg dataA_valid_clk = 0;
	reg dataB_valid_clk = 0;
	reg dataC_valid_clk = 0;
	always @(negedge clk) begin
		if (dataA_valid) begin
			if (!buffer_select_clkA) begin
				dataA_clkN <= A_reg_in;
				buffer_select_clkA <= 1;
			end else begin
				dataA_clkN <= A_reg_in_B;
				buffer_select_clkA <= 0;
			end
		end
	end
	always @(negedge clk) begin
		if (dataB_valid) begin
			if (!buffer_select_clkB) begin
				dataB_clkN <= B_reg_in;
				buffer_select_clkB <= 1;
			end else begin
				dataB_clkN <= B_reg_in_B;
				buffer_select_clkB <= 0;
			end
		end
	end
	always @(negedge clk) begin
		if (dataC_valid) begin
			if (!buffer_select_clkC) begin
				dataC_clkN <= C_reg_in;
				buffer_select_clkC <= 1;
			end else begin
				dataC_clkN <= C_reg_in_B;
				buffer_select_clkC <= 0;
			end
		end
	end
	always @(posedge clk) begin
		dataA_clkP <= dataA_clkN;
		dataB_clkP <= dataB_clkN;
		dataC_clkP <= dataC_clkN;
	end
	always @(posedge clk) begin
		A_o <= dataA_clkP;
		B_o <= dataB_clkP;
		C_o <= dataC_clkP;
	end
	
	
	// The FIFO here is fairly dumbass. We should just pingpong between two buffers or
	// something like that, although then we have to worry about how to synchronize them.
	// It takes four clocks:
	// refclk into A, sets A_valid bit, +1 ns: sysclk latches A_valid (goes metastable, settles to 0)
	// refclk into B, sets B_valid bit, +1 ns: sysclk latches A_valid, stable 1
	// refclk into C, sets C_valid bit, +1 ns: sysclk latches A_valid_sync
	// refclk into D, sets D_valid bit, +1 ns: sysclk latches A.
	//
	///// To be honest I'm not sure if this works. This ends up as an additional variable delay.
	// We'll have to look at just doing refclk latch A, sysclk latch A on the negedge, dropping
	// the two beside each other in the FPGA. In that case we may only need 1 clock.
	// This Is Going To Suck.
/*
	wire A_full, A_empty;
	fifo A_fifo(.rst(1'b0),.wr_clk(ArefGCLK),.rd_clk(clk),.din(A_reg_in),.wr_en(1'b1),.rd_en(!A_empty),
					.dout(A_o),.full(A_full),.empty(A_empty));
	wire B_full, B_empty;
	fifo B_fifo(.rst(1'b0),.wr_clk(BrefGCLK),.rd_clk(clk),.din(B_reg_in),.wr_en(1'b1),.rd_en(!B_empty),
					.dout(B_o),.full(B_full),.empty(B_empty));
	wire C_full, C_empty;
	fifo C_fifo(.rst(1'b0),.wr_clk(CrefGCLK),.rd_clk(clk),.din(C_reg_in),.wr_en(1'b1),.rd_en(!C_empty),
					.dout(C_o),.full(C_full),.empty(C_empty));
*/
	assign ACLK = ArefGCLK;
	assign BCLK = BrefGCLK;
	assign CCLK = CrefGCLK;
endmodule
