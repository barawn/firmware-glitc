module add_and_square_v6(
		clk,
		A,
		B,
		C,
		OUT
    );

	parameter DEMUX = 16;
	parameter NBITS = 3;
	localparam NCBITS = DEMUX*NBITS;
	// We have 6 output bits: the bottom bit is always 0.
	parameter OUTBITS = 6;
	
	input [NCBITS-1:0] A;
	input [NCBITS-1:0] B;
	input [NCBITS-1:0] C;
	output [OUTBITS*DEMUX-1:0] OUT;
	input clk;

	//% Vectorized A input (now 16x3)
	wire [NBITS-1:0] inA[DEMUX-1:0];
	//% Vectorized B input (now 16x3)
	wire [NBITS-1:0] inB[DEMUX-1:0];
	//% Vectorized C input (now 16x3)
	wire [NBITS-1:0] inC[DEMUX-1:0];
	//% A+B+C (x16)
	wire [4:0] sum_of_inputs[DEMUX-1:0];
	//% (A+B+C)^2 (x16)
	wire [5:0] res_square[DEMUX-1:0];
	
	generate
		genvar in_i;
		for (in_i=0;in_i<DEMUX;in_i=in_i+1) begin : INIT
			assign inA[in_i] = A[in_i*NBITS +: NBITS];
			assign inB[in_i] = B[in_i*NBITS +: NBITS];
			assign inC[in_i] = C[in_i*NBITS +: NBITS];
			assign OUT[in_i*OUTBITS +: OUTBITS] = res_square[in_i];
		end
	endgenerate
		

	generate
		genvar ii;
		for (ii=0;ii<DEMUX;ii=ii+1) begin : EXTEND_LOOP
			ternary_add_logic u_ternary_add(.A(inA[ii]),
													  .B(inB[ii]),
													  .C(inC[ii]),
													  .D(sum_of_inputs[ii]),
													  .CLK(clk));
			slice_square_logic u_slicesquare(.I(sum_of_inputs[ii]),
														.SQR(res_square[ii]),
														.CLK(clk));
		end
	endgenerate
	

endmodule
