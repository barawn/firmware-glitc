`timescale 1ns / 1ps
module glitc_intercom_iserdes_v2(
		user_clk_i,
		ctrl_i,
        chan_i,
		en_i,
		dataclk_i,
		dataclk_div2_i,
		rst_dataclk_div2_i,
		sysclk_i,
		
		in_i,
		oq_o
    );

    parameter NBITS = 4;
    input user_clk_i;
    input ctrl_i;
    input [2:0] chan_i;
    input en_i;
    input dataclk_i;
    input dataclk_div2_i;
    input rst_dataclk_div2_i;
    input sysclk_i;
    
    input [NBITS-1:0] in_i;
    output [4*NBITS-1:0] oq_o;
    

	// IDELAY_VALUE only means something if IDELAY_TYPE == FIXED.
	parameter IDELAY_TYPE = "VAR_LOAD";
	parameter IDELAY_VALUE = 0;
	
	parameter RLOC_ISERDES = "X0Y0";
	parameter RLOC_FF = "X17Y2";

	wire [NBITS-1:0] idelay_to_iserdes;
	wire [NBITS-1:0] idelay_to_ilogic;
	
	reg [1:0] en_dataclk_div2 = {2{1'b0}};
	always @(posedge dataclk_div2_i) en_dataclk_div2 <= {en_dataclk_div2[0],en_i};

	wire [4*NBITS-1:0] output_dataclk_div2;

	generate
		genvar i;
		for (i=0;i<NBITS;i=i+1) begin : LP
		    wire bitslip;
		    wire load;
		    wire [4:0] delay;
            RITC_bit_control u_control(.sysclk_i(dataclk_div2_i),.ctrl_clk_i(user_clk_i),.ctrl_i(ctrl_i),.bitslip_o(bitslip),
                                       .load_o(load),.channel_i(chan_i),.bit_i(i),.delay_o(delay));

			(* EQUIVALENT_REGISTER_REMOVAL = "FALSE" *)
			(* DONT_TOUCH = "TRUE" *)
			(* SHREG_EXTRACT = "FALSE" *)
			reg enable_this_iserdes = 0;
			always @(posedge dataclk_div2_i) begin : EN
				enable_this_iserdes <= en_dataclk_div2[1];
			end
			IDELAYE2 #(.IDELAY_TYPE(IDELAY_TYPE),.IDELAY_VALUE(IDELAY_VALUE),.HIGH_PERFORMANCE_MODE("TRUE")) u_idelay(.C(dataclk_div2_i),
									.LD(load),
									.CNTVALUEIN(delay),
									.IDATAIN(in_i[i]),
									.DATAOUT(idelay_to_iserdes[i]));
			glitc_intercom_iserdes_and_sync #(.RLOC_ISERDES(RLOC_ISERDES),.RLOC_FF(RLOC_FF)) u_iserdes(.dataclk_i(dataclk_i),
																	.dataclk_div2_i(dataclk_div2_i),
																	.sysclk_i(sysclk_i),
																	.rst_i(rst_dataclk_div2_i),
																	.ce_i(enable_this_iserdes),
																	.bitslip_i(bitslip),
																	.data_i(idelay_to_iserdes[i]),
																	.oq_o(oq_o[4*i +: 4]));
		end
	endgenerate
endmodule
