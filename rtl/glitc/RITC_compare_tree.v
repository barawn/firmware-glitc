`timescale 1ns / 1ps
// doofy compare tree for RITC
module RITC_compare_tree(
			clk_i,
			corr_i,
			max_o
    );

	parameter NUM_CORR = 16;
	parameter NUM_BITS = 12;
	input clk_i;
	input [NUM_CORR*NUM_BITS-1:0] corr_i;
	output [NUM_BITS-1:0] max_o;
	
	// Outputs the ceiling of log2(number). If value=2,
	// for instance, then
	// i = 0 : 1<2, so loop executes (clogb2 = 1)
	// i = 1 : 2!<2, so loop does not execute, and clogb2 returns 1.
	function integer clogb2;
		input [31:0] value;
		integer 	i;
		begin
			clogb2 = 0;
			for(i = 0; 2**i < value; i = i + 1)
				clogb2 = i + 1;
		end
	endfunction

	localparam NUM_STAGES = clogb2(NUM_CORR);
	localparam NUM_CORR_B2 = 2**NUM_STAGES;
	
	// We only use half of these.
	wire [NUM_BITS-1:0] corrs[NUM_STAGES:0][NUM_CORR_B2-1:0];
	generate
		genvar i,j,k,l;
		for (i=0;i<NUM_CORR_B2;i=i+1) begin : VEC
			if (i < NUM_CORR) assign corrs[0][i] = corr_i[NUM_BITS*i +: NUM_BITS];
			else assign corrs[0][i] = {NUM_BITS{1'b0}};
		end
		for (j=0;j<NUM_STAGES;j=j+1) begin : COMPARE
			// Number of output stages is half our input number.
			reg [NUM_BITS-1:0] stage_max[2**(NUM_STAGES-j-1)-1:0];
			for (k=0;k<2**(NUM_STAGES-j-1);k=k+1) begin : LOOP
				initial stage_max[k] <= {NUM_BITS{1'b0}};
				always @(posedge clk_i) begin : STAGE_COMPARE
					if (corrs[j][2*k] > corrs[j][2*k+1]) stage_max[k] <= corrs[j][2*k];
					else stage_max[k] <= corrs[j][2*k+1];
				end
				assign corrs[j+1][k] = stage_max[k];
			end
		end
	endgenerate
	assign max_o = corrs[NUM_STAGES][0];

endmodule
