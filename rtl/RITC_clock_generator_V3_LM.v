`timescale 1ns / 1ps
//% Clock generator (PLL with phase shift). 
//%
//% phase_control_in:
//%           bit 0 : PSEN
//%           bit 1 : PSINCDEC
//%           bit 7 : RST
//% phase_control_out:
//%           bit 0 : PSDONE
//%
module RITC_clock_generator_V3_LM(
		input CLK_IN_P,
		input CLK_IN_N,
		output CLK200,
		output SYSCLK,
		output SYSCLKX2,
		output SYSCLK_DIV2_PS,
		output DATACLK,
		output DATACLK_DIV2,
		input [2:0] REFCLK_A_P,
		input [2:0] REFCLK_A_N,
		output [2:0] REFCLK_A,
		input [2:0] REFCLK_B_P,
		input [2:0] REFCLK_B_N,
		output [2:0] REFCLK_B,		
		input phase_control_clk,
		input [7:0] phase_control_in,
		output [7:0] phase_control_out,
		output system_reset
    );

//	parameter DEVICE = "VIRTEX6";
//// NEW parameters!! Now INPUT is 162.5MHz instead of 200MHz!!!
//	parameter PLL_INPUT_DIVIDE = 1;
////	parameter PLL_VCO_DIVIDE = 39;
//	parameter PLL_VCO_DIVIDE = 8; // So Fvco=162.5*8=1,300MHz < 1,440MHz)
//	parameter PLL_SYSCLK_DIVIDE = 6.5;						// Fractional divide to generate 200 MHz
//	parameter PLL_DATACLK_DIVIDE = 4;					// 325   MHz
//	// Delay the clock by the equivalent of ~6-7 taps (500 ps).
//	// This allows the eye scan to definitively locate the eye.
////	parameter PLL_DATACLK_PHASE = 60;					// 58 degrees = 496 ps
//	parameter PLL_DATACLK_PHASE = 56.25;					// 58 degrees = 496 ps
//	parameter PLL_DATACLK_DIV2_DIVIDE = 8;				// 162.5 MHz
//	// Delay this clock by half the dataclk phase, to put them in phase.
////	parameter PLL_DATACLK_DIV2_PHASE = 30;				// 29 degrees = 496 ps
//	parameter PLL_DATACLK_DIV2_PHASE = 28.125;				// 29 degrees = 496 ps
//	localparam OCLK_PS_DIVIDE = 16;// 81.25 MHz


// OLD parameters!! With INPUT is 162.5MHz instead of 200MHz, BUT Fvco=975MHz
	parameter PLL_INPUT_DIVIDE = 1;
	parameter PLL_VCO_DIVIDE = 6; // So Fvco=162.5*6=975MHz < 1,440MHz)
	parameter PLL_SYSCLK_DIVIDE = 4.875;						// Fractional divide to generate 200 MHz
	parameter PLL_DATACLK_DIVIDE = 3;					// 325   MHz
	// Delay the clock by the equivalent of ~6-7 taps (500 ps).
	// This allows the eye scan to definitively locate the eye.
	parameter PLL_DATACLK_PHASE = 60;					// 58 degrees = 496 ps
	parameter PLL_DATACLK_DIV2_DIVIDE = 6;				// 162.5 MHz
	// Delay this clock by half the dataclk phase, to put them in phase.
	parameter PLL_DATACLK_DIV2_PHASE = 30;				// 29 degrees = 496 ps
	// SYSCLKx2 is used for GLITC-GLITC communication. It's not the same
	// as DATACLK, because it's in phase with SYSCLK.
	parameter SYSCLKX2_DIVIDE = 6;
	parameter SYSCLKX2_PHASE = 0;
	localparam OCLK_PS_DIVIDE = 12;// 81.25 MHz

	// This is not SYSCLK - this is the clock, after the input pins.
	// The MMCM is set to remove the input skew from SYSCLK.
	wire SYSCLK_to_MMCM;
	IBUFGDS u_ibufgds_CLK200(.I(CLK_IN_P),.IB(CLK_IN_N),.O(SYSCLK_to_MMCM));
	
	IBUFGDS u_ibufds_CLK0REF_A(.I(REFCLK_A_P[0]),.IB(REFCLK_A_N[0]),.O(REFCLK_A[0]));
	IBUFGDS u_ibufds_CLK1REF_A(.I(REFCLK_A_P[1]),.IB(REFCLK_A_N[1]),.O(REFCLK_A[1]));
	IBUFGDS u_ibufds_CLK2REF_A(.I(REFCLK_A_P[2]),.IB(REFCLK_A_N[2]),.O(REFCLK_A[2]));

	IBUFGDS u_ibufds_CLK0REF_B(.I(REFCLK_B_P[0]),.IB(REFCLK_B_N[0]),.O(REFCLK_B[0]));
	IBUFGDS u_ibufds_CLK1REF_B(.I(REFCLK_B_P[1]),.IB(REFCLK_B_N[1]),.O(REFCLK_B[1]));
	IBUFGDS u_ibufds_CLK2REF_B(.I(REFCLK_B_P[2]),.IB(REFCLK_B_N[2]),.O(REFCLK_B[2]));
	
	wire PSCLK = phase_control_clk;
	wire PSEN = phase_control_in[0];
	wire PSINCDEC = phase_control_in[1];
	wire RST_IN = phase_control_in[7];
	wire PSDONE;
	assign phase_control_out[0] = PSDONE;
	assign phase_control_out[7:1] = {6{1'b0}};
	// Add an additional synchronization flop to the input path.
	// It crosses a clock domain.
	reg [2:0] rst_in_reg = 0;
	reg pll_in_reset = 0;
	reg pll_wait_lock = 0;
	reg rst_out = 0;
	reg [3:0] rst_counter = {4{1'b0}};
	wire LOCKED;
	always @(posedge CLK200) begin
		rst_in_reg <= {rst_in_reg[1:0],RST_IN};
		if (rst_in_reg[2:1] == 2'b01) pll_in_reset <= 1;
		else if (rst_counter == {4{1'b1}}) pll_in_reset <= 0;
		if (pll_in_reset) rst_counter <= rst_counter + 1;
		else rst_counter <= {4{1'b0}};
		if (pll_in_reset) pll_wait_lock <= 1;
		else if (LOCKED) pll_wait_lock <= 0;
		
		rst_out <= (pll_in_reset || pll_wait_lock);
	end
	assign system_reset = rst_out;
			wire DATACLK_from_MMCM;
			wire DATACLK_DIV2_from_MMCM;
			wire SYSCLK_DIV2_PS_from_MMCM;
			wire SYSCLKX2_from_MMCM;
			wire CLK200_from_MMCM;
			// This is still not SYSCLK. This is the output
			// of the feedback output from the MMCM.
			// It then passes up to a BUFG, and the output of
			// *that* BUFG is SYSCLK.
			wire SYSCLK_from_MMCM;
			MMCME2_ADV 
					#(.BANDWIDTH("OPTIMIZED"),
					  .DIVCLK_DIVIDE(PLL_INPUT_DIVIDE),
					  .CLKFBOUT_MULT_F(PLL_VCO_DIVIDE),
					  .CLKIN1_PERIOD(6.154), //(2600/16 MHz)
					  .CLKOUT1_USE_FINE_PS("TRUE"),
					  .CLKOUT0_DIVIDE_F(PLL_SYSCLK_DIVIDE),
					  .CLKOUT1_DIVIDE(OCLK_PS_DIVIDE),
					  .CLKOUT2_DIVIDE(PLL_DATACLK_DIVIDE),
					  .CLKOUT2_PHASE(PLL_DATACLK_PHASE),
					  .CLKOUT3_DIVIDE(PLL_DATACLK_DIV2_DIVIDE),
					  .CLKOUT3_PHASE(PLL_DATACLK_DIV2_PHASE),
					  .CLKOUT4_DIVIDE(SYSCLKX2_DIVIDE),
					  .CLKOUT4_PHASE(SYSCLKX2_PHASE))
					u_mmcm(.CLKIN1(SYSCLK_to_MMCM),
							 .CLKFBIN(SYSCLK),
							 .CLKFBOUT(SYSCLK_from_MMCM),
							 .CLKOUT0(CLK200_from_MMCM),
							 .CLKOUT1(SYSCLK_DIV2_PS_from_MMCM),
							 .CLKOUT2(DATACLK_from_MMCM),
							 .CLKOUT3(DATACLK_DIV2_from_MMCM),
							 .CLKOUT4(SYSCLKX2_from_MMCM),
							 .LOCKED(LOCKED),
							 .RST(pll_in_reset),
							 .PSCLK(PSCLK),
							 .PSEN(PSEN),
							 .PSINCDEC(PSINCDEC),
							 .PSDONE(PSDONE));
			BUFG clkfb_bufg(.I(SYSCLK_from_MMCM),.O(SYSCLK));
			BUFG dataclk_bufg(.I(DATACLK_from_MMCM),.O(DATACLK));
			BUFG dataclk_div2_bufg(.I(DATACLK_DIV2_from_MMCM),.O(DATACLK_DIV2));
			BUFG sysclk_div2_ps_bufg(.I(SYSCLK_DIV2_PS_from_MMCM),.O(SYSCLK_DIV2_PS));
			BUFG clk200_bufg(.I(CLK200_from_MMCM),.O(CLK200));
			BUFG sysclkx2_bufg(.I(SYSCLKX2_from_MMCM),.O(SYSCLKX2));
							 
endmodule
