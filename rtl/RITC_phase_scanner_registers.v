`timescale 1ns / 1ps
module RITC_phase_scanner_registers(
		input CLK_PS,
		input CLK,
		output CLOCK_to_BUFR,
		input [2:0] CLOCK_IN,
		input [11:0] CH0_IN,
		input [11:0] CH1_IN,
		input [11:0] CH2_IN,
		input VCDL_IN,
		output [2:0] CLOCK_OUT,
		output [11:0] CH0_OUT,
		output [11:0] CH1_OUT,
		output [11:0] CH2_OUT,
		output VCDL_Q
    );

	wire [11:0] CH_IN[2:0];
	wire [11:0] CH_OUT[2:0];
	assign CH_IN[0] = CH0_IN;
	assign CH_IN[1] = CH1_IN;
	assign CH_IN[2] = CH2_IN;

	(* IOB = "TRUE" *)
	reg vcdl_reg_q = 0;
	reg [1:0] vcdl_reg_q_CLK = {2{1'b0}};
	always @(posedge CLK_PS) vcdl_reg_q <= VCDL_IN;
	always @(posedge CLK) vcdl_reg_q_CLK <= {vcdl_reg_q_CLK[0],vcdl_reg_q};
	generate
		genvar i,j;
		for (i=0;i<3;i=i+1) begin : CHLOOP
			// Clocks.
			reg [1:0] clk_reg_CLK = {2{1'b0}};
			if (i == 0) begin : BIT0
				wire CLOCK_Q_OUT;
				// We have to instantiate a hard macro to get the duplicate
				// O output for the BUFR. Just because, apparently.
				IDELAYED_IFD_with_feedthru u_feedthru(.DDLY_IN(CLOCK_IN[i]),
																  .CLK_IN(CLK_PS),
																  .Q_OUT(CLOCK_Q_OUT),
																  .O_OUT(CLOCK_to_BUFR));
				always @(posedge CLK) clk_reg_CLK <= {clk_reg_CLK[0],CLOCK_Q_OUT};
			end else begin : BIT12
				(* IOB = "TRUE" *)
				reg clk_reg = 0;
				always @(posedge CLK_PS) clk_reg <= CLOCK_IN[i];
				always @(posedge CLK) clk_reg_CLK <= {clk_reg_CLK[0],clk_reg};
			end
			assign CLOCK_OUT[i] = clk_reg_CLK[1];
			// Data.
			for (j=0;j<12;j=j+1) begin : DATALOOP
				(* IOB = "TRUE" *)
				reg dat_reg = 0;
				reg [1:0] dat_reg_CLK = {2{1'b0}};
				always @(posedge CLK_PS) dat_reg <= CH_IN[i][j];
				always @(posedge CLK) dat_reg_CLK <= {dat_reg_CLK[0],dat_reg};
				assign CH_OUT[i][j] = dat_reg_CLK[1];
			end
		end
	endgenerate
	assign CH0_OUT = CH_OUT[0];
	assign CH1_OUT = CH_OUT[1];
	assign CH2_OUT = CH_OUT[2];
	assign VCDL_Q = vcdl_reg_q_CLK[1];
endmodule

module IDELAYED_IFD_with_feedthru( input DDLY_IN,
															 input CLK_IN,
															 output Q_OUT,
															 output O_OUT);
endmodule
