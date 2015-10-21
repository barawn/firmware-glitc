`timescale 1ns / 1ps
module RITC_input_channel_storage(
		clk_i,
		in_i,
		out_o
    );

	parameter NBITS = 48;
	parameter STAGES = 1;
	
	input clk_i;
	input [NBITS-1:0] in_i;
	output [NBITS*(STAGES+1)-1:0] out_o;
	
	assign out_o[NBITS-1:0] = in_i;
	generate
		if (STAGES > 0) begin : SHREG
			reg [NBITS*STAGES-1:0] storage_reg = {NBITS*STAGES{1'b0}};
			always @(posedge clk_i) begin : STORE
				storage_reg <= out_o[0 +: NBITS*STAGES];
			end
			assign out_o[NBITS +: NBITS*STAGES] = storage_reg;
		end
	endgenerate
				
endmodule
