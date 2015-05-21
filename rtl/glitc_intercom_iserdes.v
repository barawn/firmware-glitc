`timescale 1ns / 1ps
module glitc_intercom_iserdes(
		input user_clk_i,
		input en_i,
		input load_i,
		input [1:0] delay_sel_i,
		input [4:0] delay_i,

		input [3:0] bitslip_i,
		input dataclk_i,
		input dataclk_div2_i,
		input rst_dataclk_div2_i,
		input sysclk_i,
		
		input [3:0] in_i,
		output [15:0] oq_o
    );

	// IDELAY_VALUE only means something if IDELAY_TYPE == FIXED.
	parameter IDELAY_TYPE = "VAR_LOAD";
	parameter IDELAY_VALUE = 0;
	
	parameter RLOC_ISERDES = "X0Y0";
	parameter RLOC_FF = "X17Y2";

	wire [3:0] idelay_to_iserdes;
	wire [3:0] idelay_to_ilogic;
	
	reg [1:0] en_dataclk_div2 = {2{1'b0}};
	always @(posedge dataclk_div2_i) en_dataclk_div2 <= {en_dataclk_div2[0],en_i};

	wire [15:0] output_dataclk_div2;

	generate
		genvar i;
		for (i=0;i<4;i=i+1) begin : LP
			(* EQUIVALENT_REGISTER_REMOVAL = "FALSE" *)
			(* SHREG_EXTRACT = "FALSE" *)
			reg enable_this_iserdes = 0;
			always @(posedge dataclk_div2_i) begin : EN
				enable_this_iserdes <= en_dataclk_div2;
			end
			IDELAYE2 #(.IDELAY_TYPE(IDELAY_TYPE),.IDELAY_VALUE(IDELAY_VALUE),.HIGH_PERFORMANCE_MODE("TRUE")) u_idelay(.C(user_clk_i),
									.LD(load_i && (delay_sel_i == i)),
									.CNTVALUEIN(delay_i),
									.IDATAIN(in_i[i]),
									.DATAOUT(idelay_to_iserdes[i]));
			glitc_intercom_iserdes_and_sync #(.RLOC_ISERDES(RLOC_ISERDES),.RLOC_FF(RLOC_FF)) u_iserdes(.dataclk_i(dataclk_i),
																	.dataclk_div2_i(dataclk_div2_i),
																	.sysclk_i(sysclk_i),
																	.rst_i(rst_dataclk_div2_i),
																	.ce_i(enable_this_iserdes),
																	.bitslip_i(bitslip_i[i]),
																	.data_i(idelay_to_iserdes[i]),
																	.oq_o(oq_o[4*i +: 4]));
		end
	endgenerate
endmodule
