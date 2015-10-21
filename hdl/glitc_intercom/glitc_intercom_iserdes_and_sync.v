`timescale 1ns / 1ps
module glitc_intercom_iserdes_and_sync(
		input dataclk_i,
		input dataclk_div2_i,
		input sysclk_i,
		input rst_i,
		input ce_i,
		input bitslip_i,
		input data_i,
		
		output [3:0] oq_o
    );
	// This is PHI_DOWN.
	// PHI_UP is X11Y0/X0Y2
	
	parameter RLOC_ISERDES = "X0Y0";
	parameter RLOC_FF = "X17Y2";

	wire [3:0] output_dataclk_div2;

	(* HU_SET = "GLITC_INTERCOM_ISERDES" *)
	(* RPM_GRID = "GRID" *)
	(* RLOC = RLOC_ISERDES *)
	ISERDESE2 #(.DATA_RATE("DDR"),
					.DATA_WIDTH(4),
					.INTERFACE_TYPE("NETWORKING"),
					.NUM_CE(1),
					.IOBDELAY("IFD"))
					u_iserdes(  .CLK(dataclk_i),
									.CLKB(~dataclk_i),
									.CLKDIV(dataclk_div2_i),
									.RST(rst_i),
									.CE1(1'b1),
									.BITSLIP(bitslip_i),
									.DDLY(data_i),
									.Q1(output_dataclk_div2[0]),
									.Q2(output_dataclk_div2[1]),
									.Q3(output_dataclk_div2[2]),
									.Q4(output_dataclk_div2[3]));
	(* HU_SET = "GLITC_INTERCOM_ISERDES" *)
	(* RLOC = RLOC_FF *)
	FD u_q0(.D(output_dataclk_div2[0]),.C(sysclk_i),.Q(oq_o[0]));
	(* HU_SET = "GLITC_INTERCOM_ISERDES" *)
	(* RLOC = RLOC_FF *)
	FD u_q1(.D(output_dataclk_div2[1]),.C(sysclk_i),.Q(oq_o[1]));
	(* HU_SET = "GLITC_INTERCOM_ISERDES" *)
	(* RLOC = RLOC_FF *)
	FD u_q2(.D(output_dataclk_div2[2]),.C(sysclk_i),.Q(oq_o[2]));
	(* HU_SET = "GLITC_INTERCOM_ISERDES" *)
	(* RLOC = RLOC_FF *)
	FD u_q3(.D(output_dataclk_div2[3]),.C(sysclk_i),.Q(oq_o[3]));	
endmodule
