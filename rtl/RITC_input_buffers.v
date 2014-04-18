`timescale 1ns / 1ps
module RITC_input_buffers(
		input [11:0] CH0_P,
		input [11:0] CH0_N,
		input [11:0] CH1_P,
		input [11:0] CH1_N,
		input [11:0] CH2_P,
		input [11:0] CH2_N,
		output [11:0] CH0,
		output [11:0] CH1,
		output [11:0] CH2
    );

	wire [11:0] RITC_DATA[2:0];
	generate
		genvar i;
		for (i=0;i<12;i=i+1) begin : LP
			IBUFDS u_ibufds_CH0(.I(CH0_P[i]),.IB(CH0_N[i]),.O(RITC_DATA[0][i]));			
			IBUFDS u_ibufds_CH1(.I(CH1_P[i]),.IB(CH1_N[i]),.O(RITC_DATA[1][i]));
			IBUFDS u_ibufds_CH2(.I(CH2_P[i]),.IB(CH2_N[i]),.O(RITC_DATA[2][i]));
		end
	endgenerate

	assign CH0 = RITC_DATA[0];
	assign CH1 = RITC_DATA[1];
	assign CH2 = RITC_DATA[2];

endmodule
