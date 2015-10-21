`timescale 1ns / 1ps
module glitc_intercom_input_buffers(
        IN_P,
        IN_N,
        in_o,
        OUT_P,
        OUT_N,
        out_i,
        disable_i
    );

    parameter NBITS = 4;
    
    input [NBITS-1:0] IN_P;
    input [NBITS-1:0] IN_N;
    output [NBITS-1:0] in_o;
    
    output [NBITS-1:0] OUT_P;
    output [NBITS-1:0] OUT_N;
    input [NBITS-1:0] out_i;
    
    input disable_i;

	generate
		genvar i;
		for (i=0;i<NBITS;i=i+1) begin : LOOP
			IBUFDS u_ibuf(.I(IN_P[i]),.IB(IN_N[i]),.O(in_o[i]));
			OBUFDS u_obuf(.I(out_i[i]),.O(OUT_P[i]),.OB(OUT_N[i]));
		end
	endgenerate

endmodule
