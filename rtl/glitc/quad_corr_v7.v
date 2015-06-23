module quad_corr_v7(
		clk,
		A0,
		B0,
		C0,
		A1,
		B1,
		C1,
		A2,
		B2,
		C2,
		A3,
		B3,
		C3,
		CORR0,
		CORR1,
		CORR2,
		CORR3
    );
	 
	//% How many cycles to delay the output, if any.
	parameter DELAY = 0;
	//% Number of samples in a cycle.
	parameter DEMUX = 16;
	//% Number of bits in each sample.
	parameter NBITS = 3;
	//% Number of bits in (A+B+C)^2 in each sample. Implicit 0 is dropped.
	parameter ADDSQBITS = 6;
	//% Number of correlations in this module.
	parameter NCORRS = 4;
	
	//% Total number of bits in an individual channel.
	localparam NCBITS = DEMUX*NBITS;
	//% Total number of bits in an (A+B+C)^2 output.
	localparam NSQBITS = DEMUX*ADDSQBITS;

	//% Number of bits in a DSP input.
	localparam NDSPBITS = 12;

	input [NCBITS-1:0] A0;
	input [NCBITS-1:0] B0;
	input [NCBITS-1:0] C0;
	
	input [NCBITS-1:0] A1;
	input [NCBITS-1:0] B1;
	input [NCBITS-1:0] C1;

	input [NCBITS-1:0] A2;
	input [NCBITS-1:0] B2;
	input [NCBITS-1:0] C2;

	input [NCBITS-1:0] A3;
	input [NCBITS-1:0] B3;
	input [NCBITS-1:0] C3;
	
	output [10:0] CORR0;
	output [10:0] CORR1;
	output [10:0] CORR2;
	output [10:0] CORR3;
	
	input clk;

	//% Vectorized A inputs.
	wire [NCBITS-1:0] A[NCORRS-1:0];
	//% Vectorized B inputs.
	wire [NCBITS-1:0] B[NCORRS-1:0];
	//% Vectorized C inputs.
	wire [NCBITS-1:0] C[NCORRS-1:0];
	//% Outputs from the add/square modules.
	wire [NSQBITS-1:0] ADDSQ[3:0];
	
	// We have 7 stages of DSPs.
	
	//% DSP stage inputs. (2 inputs from each correlation)
	wire [NDSPBITS-1:0] DSP_INPUT[6:0][7:0];
	//% DSP stage cascade (no output cascade).
	wire [47:0] DSP_CASCADE[5:0];
	//% Direct DSP outputs. Only 3 of these since just the second part has them connected. Only 1 of these is used.
	wire [NDSPBITS-1:0] DSP_OUTPUT[2:0][3:0];
	//% Final-stage outputs.
	wire [NDSPBITS-1:0] DSP_SUM[3:0];

	`define VECTORIZE( x ) \
		assign x [0] = x``0; \
		assign x [1] = x``1; \
		assign x [2] = x``2; \
		assign x [3] = x``3
	
	`VECTORIZE(A);
	`VECTORIZE(B);
	`VECTORIZE(C);
	
	generate
		genvar i,j;
		for (i=0;i<NCORRS;i=i+1) begin : CORR
			add_and_square_v6 u_addsq(.A(A[i]),.B(B[i]),.C(C[i]),.OUT(ADDSQ[i]),.clk(clk));
			partition_and_preadd_v7 u_partition( .clk(clk), .IN(ADDSQ[i]),
															 .STAGE1A(DSP_INPUT[0][2*i+0]),.STAGE1B(DSP_INPUT[0][2*i+1]),
															 .STAGE2A(DSP_INPUT[1][2*i+0]),.STAGE2B(DSP_INPUT[1][2*i+1]),
															 .STAGE3A(DSP_INPUT[2][2*i+0]),.STAGE3B(DSP_INPUT[2][2*i+1]),
															 .STAGE4A(DSP_INPUT[3][2*i+0]),.STAGE4B(DSP_INPUT[3][2*i+1]),
															 .STAGE5A(DSP_INPUT[4][2*i+0]),.STAGE5B(DSP_INPUT[4][2*i+1]),
															 .STAGE6A(DSP_INPUT[5][2*i+0]),.STAGE6B(DSP_INPUT[5][2*i+1]));
		end
		// The first 6 stages of DSP are identical in groups of 2 (i.e. 1&2, 3&4, 5&6) except that stage6's
		// outputs are needed, and stage1 doesn't add its cascade. Additionally every stage past 1&2 uses
		// a single input register.
		for (j=0;j<3;j=j+1) begin : DSP
			if (j == 0) begin : HEAD
				quad_dsp_sum #(.ADD_CASCADE(0),.INPUT_REG(0),.OUTPUT_REG(0)) 
					 u_pair_0( .A(DSP_INPUT[2*j + 0][0]), .B(DSP_INPUT[2*j + 0][1]),
								  .C(DSP_INPUT[2*j + 0][2]), .D(DSP_INPUT[2*j + 0][3]),
								  .E(DSP_INPUT[2*j + 0][4]), .F(DSP_INPUT[2*j + 0][5]),
								  .G(DSP_INPUT[2*j + 0][6]), .H(DSP_INPUT[2*j + 0][7]),
								  .CASC_OUT(DSP_CASCADE[2*j + 0]),
								  .CLK(clk));
			end else begin : BODY
				quad_dsp_sum #(.ADD_CASCADE(1),.INPUT_REG(1),.OUTPUT_REG(0)) 
					 u_pair_0( .A(DSP_INPUT[2*j + 0][0]), .B(DSP_INPUT[2*j + 0][1]),
								  .C(DSP_INPUT[2*j + 0][2]), .D(DSP_INPUT[2*j + 0][3]),
								  .E(DSP_INPUT[2*j + 0][4]), .F(DSP_INPUT[2*j + 0][5]),
								  .G(DSP_INPUT[2*j + 0][6]), .H(DSP_INPUT[2*j + 0][7]),
								  .CASC_IN(DSP_CASCADE[2*(j-1) + 1]),
								  .CASC_OUT(DSP_CASCADE[2*j + 0]),
								  .CLK(clk));
			end
			quad_dsp_sum #(.ADD_CASCADE(1), .INPUT_REG( (j!=0) ? 1 : 0), .OUTPUT_REG(1))
				 u_pair_1( .A(DSP_INPUT[2*j + 1][0]), .B(DSP_INPUT[2*j + 1][1]),
							  .C(DSP_INPUT[2*j + 1][2]), .D(DSP_INPUT[2*j + 1][3]),
							  .E(DSP_INPUT[2*j + 1][4]), .F(DSP_INPUT[2*j + 1][5]),
							  .G(DSP_INPUT[2*j + 1][6]), .H(DSP_INPUT[2*j + 1][7]),
							  .APB(DSP_OUTPUT[j][0]),
							  .CPD(DSP_OUTPUT[j][1]),
							  .EPF(DSP_OUTPUT[j][2]),
							  .GPH(DSP_OUTPUT[j][3]),
							  .CASC_IN(DSP_CASCADE[2*j + 0]),
							  .CASC_OUT(DSP_CASCADE[2*j + 1]),
							  .CLK(clk));
		end			
	endgenerate
	
	assign DSP_INPUT[6][0] = DSP_OUTPUT[2][0];
	// This is the constant term (the value to be subtracted off, if desired).
	assign DSP_INPUT[6][1] = 12'h000;

	assign DSP_INPUT[6][2] = DSP_OUTPUT[2][1];
	// This is the constant term (the value to be subtracted off, if desired).
	assign DSP_INPUT[6][3] = 12'h000;

	assign DSP_INPUT[6][4] = DSP_OUTPUT[2][2];
	// This is the constant term (the value to be subtracted off, if desired).
	assign DSP_INPUT[6][5] = 12'h000;

	assign DSP_INPUT[6][6] = DSP_OUTPUT[2][3];
	// This is the constant term (the value to be subtracted off, if desired).
	assign DSP_INPUT[6][7] = 12'h000;
	
	
	quad_dsp_sum #(.ADD_CASCADE(1), .INPUT_REG(1) ,.OUTPUT_REG(1))
		u_final_dsp( .A(DSP_INPUT[6][0]), .B(DSP_INPUT[6][1]),
						 .C(DSP_INPUT[6][2]), .D(DSP_INPUT[6][3]),
						 .E(DSP_INPUT[6][4]), .F(DSP_INPUT[6][5]),
						 .G(DSP_INPUT[6][6]), .H(DSP_INPUT[6][7]),
						 .APB(DSP_SUM[0]),
						 .CPD(DSP_SUM[1]),
						 .EPF(DSP_SUM[2]),
						 .GPH(DSP_SUM[3]),
						 .CASC_IN(DSP_CASCADE[5]),
						 .CLK(clk));
	assign CORR0 = DSP_SUM[0][10:0];
	assign CORR1 = DSP_SUM[1][10:0];
	assign CORR2 = DSP_SUM[2][10:0];
	assign CORR3 = DSP_SUM[3][10:0];

endmodule
