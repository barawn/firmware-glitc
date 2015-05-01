`timescale 1ns / 1ps
module quad_dsp_sum(input [11:0] A,
					 input [11:0] B,
					 input [11:0] C,
					 input [11:0] D,
					 input [11:0] E,
					 input [11:0] F,
					 input [11:0] G,
					 input [11:0] H,
					 
					 output [12:0] APB,
					 output [12:0] CPD,
					 output [12:0] EPF,
					 output [12:0] GPH,
					 
					 input [47:0] CASC_IN,
					 output [47:0] CASC_OUT,
					 
					 input CLK
					 );
					 
	parameter ADD_CASCADE = 0;				 
	parameter INPUT_REG = 0;
	parameter OUTPUT_REG = 0;
	
	wire [29:0] DSP_A_IN;
	wire [17:0] DSP_B_IN;
	wire [47:0] DSP_C_IN;
	wire [47:0] DSP_P_OUT;
	wire [3:0] DSP_CARRYOUT;
	assign DSP_A_IN = {G,E,C[11:6]};
	assign DSP_B_IN = {C[5:0],A};
	assign DSP_C_IN = {H,F,D,B};
	assign APB = {DSP_CARRYOUT[0],DSP_P_OUT[0 +: 12]};
	assign CPD = {DSP_CARRYOUT[1],DSP_P_OUT[12 +: 12]};
	assign EPF = {DSP_CARRYOUT[2],DSP_P_OUT[24 +: 12]};
	assign GPH = {DSP_CARRYOUT[3],DSP_P_OUT[36 +: 12]};
	generate
		if (ADD_CASCADE == 0) begin : NO_CASCADE
			DSP48E1 #(.USE_SIMD("FOUR12"),
						 .AREG(INPUT_REG),
						 .BREG(INPUT_REG),
						 .CREG(INPUT_REG),
						 .ACASCREG(INPUT_REG),
						 .BCASCREG(INPUT_REG),
						 .PREG(OUTPUT_REG),
						 .ALUMODEREG(0),
						 .DREG(0),
						 .ADREG(0),
						 .OPMODEREG(0),
						 .CARRYINREG(0),
						 .CARRYINSELREG(0),
						 .INMODEREG(0),
						 .MREG(0),
						 .USE_MULT("NONE"),
						 .USE_PATTERN_DETECT("NO_PATDET"),
						 .A_INPUT("DIRECT"),
						 .B_INPUT("DIRECT"),
						 .USE_DPORT("FALSE")) u_quadadder( .A(DSP_A_IN),
																	  .B(DSP_B_IN),
																	  .C(DSP_C_IN),
																	  .P(DSP_P_OUT),
																	  .CARRYIN(1'b0),
																	  .CARRYINSEL(3'h0),
																	  .PCOUT(CASC_OUT),																	  
																	  .CARRYOUT(DSP_CARRYOUT),
																	  .ALUMODE(4'h0),
																		// X output is A:B
																		// Y output is 0
																		// Z output is C
																	  .OPMODE(7'b0110011),
																	  .INMODE(4'h0),
																	  .CEP(OUTPUT_REG),
																	  .CEA2(INPUT_REG),
																	  .CEB2(INPUT_REG),
																	  .CEC(INPUT_REG),
																	  .CLK(CLK));
		end else begin : CASCADE
			DSP48E1 #(.USE_SIMD("FOUR12"),
						 .AREG(INPUT_REG),
						 .BREG(INPUT_REG),
						 .CREG(INPUT_REG),
						 .ACASCREG(INPUT_REG),
						 .BCASCREG(INPUT_REG),
						 .PREG(OUTPUT_REG),
						 .ALUMODEREG(0),
						 .DREG(0),
						 .ADREG(0),
						 .OPMODEREG(0),
						 .CARRYINREG(0),
						 .CARRYINSELREG(0),
						 .INMODEREG(0),
						 .MREG(0),
						 .USE_MULT("NONE"),
						 .USE_PATTERN_DETECT("NO_PATDET"),
						 .A_INPUT("DIRECT"),
						 .B_INPUT("DIRECT"),
						 .USE_DPORT("FALSE")) u_quadadder( .A(DSP_A_IN),
																	  .B(DSP_B_IN),
																	  .C(DSP_C_IN),
																	  .PCIN(CASC_IN),
																	  .P(DSP_P_OUT),
																	  .PCOUT(CASC_OUT),
																	  .CARRYOUT(DSP_CARRYOUT),
																	  .ALUMODE(4'h0),
																		// X output is A:B
																		// Y output is C
																		// Z output is PCIN
																	  .OPMODE(7'b0011111),
																	  .INMODE(4'h0),
																	  .CEA2(INPUT_REG),
																	  .CEB2(INPUT_REG),
																	  .CEP(OUTPUT_REG),
																	  .CEC(INPUT_REG),
																	  .CLK(CLK));
		end
	endgenerate
endmodule
