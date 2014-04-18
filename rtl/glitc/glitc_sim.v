`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   19:54:16 10/01/2012
// Design Name:   glitc
// Module Name:   C:/cygwin/home/barawn/firmware/ANITA/fast_3bit_sum/rtl/glitc_sim.v
// Project Name:  fast_3bit_sum
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: glitc
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module glitc_sim;

	// Inputs
	reg [11:0] A_P;
	reg [11:0] A_N;
	reg AREF_P;
	reg AREF_N;
	reg [11:0] B_P;
	reg [11:0] B_N;
	reg BREF_P;
	reg BREF_N;
	reg [11:0] C_P;
	reg [11:0] C_N;
	reg CREF_P;
	reg CREF_N;
	reg [11:0] D_P;
	reg [11:0] D_N;
	reg DREF_P;
	reg DREF_N;
	reg [11:0] E_P;
	reg [11:0] E_N;
	reg EREF_P;
	reg EREF_N;
	reg [11:0] F_P;
	reg [11:0] F_N;
	reg FREF_P;
	reg FREF_N;
	reg clk;

	// Data memory. Store 64 samples.
	reg [3:0] memA[63:0];
	reg [3:0] memB[63:0];
	reg [3:0] memC[63:0];
	reg [3:0] memD[63:0];
	reg [3:0] memE[63:0];
	reg [3:0] memF[63:0];
	initial begin
		$readmemh("SIMA.DAT", memA);
		$readmemh("SIMB.DAT", memB);
		$readmemh("SIMC.DAT", memC);
		$readmemh("SIMD.DAT", memD);
		$readmemh("SIME.DAT", memE);
		$readmemh("SIMF.DAT", memF);
	end
	
	reg [5:0] counterA = {6{1'b0}};
	reg [5:0] counterB = {6{1'b0}};
	reg [5:0] counterC = {6{1'b0}};
	reg [5:0] counterD = {6{1'b0}};
	reg [5:0] counterE = {6{1'b0}};
	reg [5:0] counterF = {6{1'b0}};

	// INVERT BIT 2. NOTE THAT THIS SHOULD BE DONE ON THE PCB BY FLOPPING P/N!!

	`define ASSIGN(x) \
		x``_P[0 +: 2] = mem``x [ counter``x ][1:0]; \
		x``_P[2] = ! mem``x [ counter``x ][2];      \
		x``_P[3 +: 2] = mem``x [ counter``x + 1][1:0]; \
		x``_P[5] = ! mem``x [ counter``x +1 ][2];         \
		x``_P[6 +: 2] = mem``x [ counter``x + 2][1:0]; \
		x``_P[8] = ! mem``x [ counter``x +2 ][2];         \
		x``_P[9 +: 2] = mem``x [ counter``x + 3][1:0]; \
		x``_P[11] = ! mem``x [ counter``x +3 ][2];     \
		counter``x = counter``x + 4;              \
		x``_N = ~( x``_P  )
			
	always begin
		#3.077 clk = ~clk;
	end
	always @(posedge clk) begin
		// AREF goes high, and we output the data.
		AREF_P = 1; 
		AREF_N = 0; 
		#0.1;
		`ASSIGN(A);
		#1.4385;
		AREF_P = 0;
		AREF_N = 1;
		`ASSIGN(A);
		@(negedge clk);
		AREF_P = 1;
		AREF_N = 0;
		#0.1;
		`ASSIGN(A);
		#1.4385;
		AREF_P = 0;
		AREF_N = 1;
		`ASSIGN(A);
	end
	always @(posedge clk) begin
		// BREF goes high, and we output the data.
		BREF_P = 1; 
		BREF_N = 0; 
		#0.1;
		`ASSIGN(B);
		#1.4385;
		BREF_P = 0;
		BREF_N = 1;
		`ASSIGN(B);
		@(negedge clk);
		BREF_P = 1;
		BREF_N = 0;
		#0.1;
		`ASSIGN(B);
		#1.4385;
		BREF_P = 0;
		BREF_N = 1;
		`ASSIGN(B);
	end
	always @(posedge clk) begin
		// CREF goes high, and we output the data.
		CREF_P = 1; 
		CREF_N = 0; 
		#0.1;
		`ASSIGN(C);
		#1.4385;
		CREF_P = 0;
		CREF_N = 1;
		`ASSIGN(C);
		@(negedge clk);
		CREF_P = 1;
		CREF_N = 0;
		#0.1;
		`ASSIGN(C);
		#1.4385;
		CREF_P = 0;
		CREF_N = 1;
		`ASSIGN(C);
	end
	always @(posedge clk) begin
		// DREF goes high, and we output the data.
		DREF_P = 1; 
		DREF_N = 0; 
		#0.1;
		D_P = memD[counterD];
		D_N = ~memD[counterD];
		counterD = counterD + 1;
		#1.4385;
		DREF_P = 0;
		DREF_N = 1;
		D_P = memD[counterD];
		D_N = ~memD[counterD];
		counterD = counterD + 1;
		@(negedge clk);
		DREF_P = 1;
		DREF_N = 0;
		#0.1;
		D_P = memD[counterD];
		D_N = ~memD[counterD];
		counterD = counterD + 1;
		#1.4385;
		DREF_P = 0;
		DREF_N = 1;
		D_P = memD[counterD];
		D_N = ~memD[counterD];
		counterD = counterD + 1;
	end
	always @(posedge clk) begin
		// DREF goes high, and we output the data.
		EREF_P = 1; 
		EREF_N = 0; 
		#0.1;
		E_P = memE[counterE];
		E_N = ~memE[counterE];
		counterE = counterE + 1;
		#1.4385;
		EREF_P = 0;
		EREF_N = 1;
		E_P = memE[counterE];
		E_N = ~memE[counterE];
		counterE = counterE + 1;
		@(negedge clk);
		EREF_P = 1;
		EREF_N = 0;
		#0.1;
		E_P = memE[counterE];
		E_N = ~memE[counterE];
		counterE = counterE + 1;
		#1.4385;
		EREF_P = 0;
		EREF_N = 1;
		E_P = memE[counterE];
		E_N = ~memE[counterE];
		counterE = counterE + 1;
	end
	always @(posedge clk) begin
		// EREF goes high, and we output the data.
		FREF_P = 1; 
		FREF_N = 0; 
		#0.1;
		F_P = memF[counterF];
		F_N = ~memF[counterF];
		counterF = counterF + 1;
		#1.4385;
		FREF_P = 0;
		FREF_N = 1;
		F_P = memF[counterF];
		F_N = ~memF[counterF];
		counterF = counterF + 1;
		@(negedge clk);
		FREF_P = 1;
		FREF_N = 0;
		#0.1;
		F_P = memF[counterF];
		F_N = ~memF[counterF];
		counterF = counterF + 1;
		#1.4385;
		FREF_P = 0;
		FREF_N = 1;
		F_P = memF[counterF];
		F_N = ~memF[counterF];
		counterF = counterF + 1;
	end
	
	// Outputs
	wire [10:0] MAX;

	// Instantiate the Unit Under Test (UUT)
	glitc uut (
		.A_P(A_P), 
		.A_N(A_N), 
		.AREF_P(AREF_P), 
		.AREF_N(AREF_N), 
		.B_P(B_P), 
		.B_N(B_N), 
		.BREF_P(BREF_P), 
		.BREF_N(BREF_N), 
		.C_P(C_P), 
		.C_N(C_N), 
		.CREF_P(CREF_P), 
		.CREF_N(CREF_N), 
		.D_P(D_P), 
		.D_N(D_N), 
		.DREF_P(DREF_P), 
		.DREF_N(DREF_N), 
		.E_P(E_P), 
		.E_N(E_N), 
		.EREF_P(EREF_P), 
		.EREF_N(EREF_N), 
		.F_P(F_P), 
		.F_N(F_N), 
		.FREF_P(FREF_P), 
		.FREF_N(FREF_N), 
		.clk(clk), 
		.MAX(MAX)
	);

	initial begin
		// Initialize Inputs
		A_P = 0;
		A_N = 0;
		AREF_P = 0;
		AREF_N = 0;
		B_P = 0;
		B_N = 0;
		BREF_P = 0;
		BREF_N = 0;
		C_P = 0;
		C_N = 0;
		CREF_P = 0;
		CREF_N = 0;
		D_P = 0;
		D_N = 0;
		DREF_P = 0;
		DREF_N = 0;
		E_P = 0;
		E_N = 0;
		EREF_P = 0;
		EREF_N = 0;
		F_P = 0;
		F_N = 0;
		FREF_P = 0;
		FREF_N = 0;
		clk = 0;

		// Wait 100 ns for global reset to finish
		#100;
        
		// Add stimulus here

	end
      
endmodule

