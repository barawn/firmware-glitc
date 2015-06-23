`timescale 1ns / 1ps
module glitc_intercom_input_buffers(
		input [3:0] IN_P,
		input [3:0] IN_N,
		output [3:0] in_o,
		output [3:0] OUT_P,
		output [3:0] OUT_N,
		input [3:0] out_i,
		input disable_i
    );

	generate
		genvar i;
		for (i=0;i<4;i=i+1) begin : LOOP
			IBUFDS u_ibuf(.I(IN_P[i]),.IB(IN_N[i]),.O(in_o[i]));
			OBUFDS u_obuf(.I(out_i[i]),.O(OUT_P[i]),.OB(OUT_N[i]));
		end
	endgenerate

endmodule
