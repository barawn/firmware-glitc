module add_and_square_v8(
		clk,
		A,
		B,
		C,
		OUT,
		CARRY
    );

	parameter DEMUX = 16;
	parameter NBITS = 6;
	localparam NCBITS = DEMUX*NBITS;
	// We have 7 output bits.
	parameter OUTBITS = 7;
	// We have 4 carry outputs.
	parameter CARRYBITS = 4;
	
	input [NCBITS-1:0] A;
	input [NCBITS-1:0] B;
	input [NCBITS-1:0] C;
	output [OUTBITS*DEMUX-1:0] OUT;
	output [CARRYBITS-1:0] CARRY;
	input clk;

	//% Vectorized A input (now 16x6)
	wire [NBITS-1:0] inA[DEMUX-1:0];
	//% Vectorized B input (now 16x6)
	wire [NBITS-1:0] inB[DEMUX-1:0];
	//% Vectorized C input (now 16x6)
	wire [NBITS-1:0] inC[DEMUX-1:0];
	//% Vectorized power output (16x7)
	wire [OUTBITS-1:0] res_square[DEMUX-1:0];
	//% LSB outputs.
	wire [DEMUX-1:0] LSB;

	generate
		genvar i;
		for (i=0;i<DEMUX;i=i+1) begin : INIT
			assign inA[i] = A[i*NBITS +: NBITS];
			assign inB[i] = B[i*NBITS +: NBITS];
			assign inC[i] = C[i*NBITS +: NBITS];
			assign OUT[i*OUTBITS +: OUTBITS] = res_square[i];

			six_bit_sum_power u_addpower(.A(inA[i]),
												  .B(inB[i]),
												  .C(inC[i]),
												  .O(res_square[i]),
												  .LSB(LSB[i]),
												  .CLK(clk));
		end
	endgenerate
	
	lsb_adder u_addlsb(.LSB(LSB),.CARRY(CARRY),.CLK(clk));

endmodule
