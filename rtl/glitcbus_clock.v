`timescale 1ns / 1ps
module glitcbus_clock(
		input GCLK,
		output gb_clk_o
    );

	// Generate the local, deskewed copy of GCLK.
	wire glitcbus_clk;
	wire glitcbus_clkfb;
	wire glitcbus_clk_to_BUFG;
	wire glitcbus_clkfb_to_BUFG;
	BUFG u_glitcbus_clk_bufg(.I(glitcbus_clk_to_BUFG),.O(glitcbus_clk));
	BUFG u_glitcbus_clkfb_bufg(.I(glitcbus_clkfb_to_BUFG),.O(glitcbus_clkfb));
	// Our input is 16 MHz.
	// The VCO can only run as low as 600 MHz, so we'll set it at 800 MHz (16x50)
	// to be safe.
	// DIVCLK_DIVIDE = 1
	// CLKFBOUT_MULT_F = 50
	// CLKOUT0_DIVIDE_F = 50
	MMCME2_BASE #(.DIVCLK_DIVIDE(1),
					  .CLKFBOUT_MULT_F(50),
					  .CLKOUT0_DIVIDE_F(50),
					  .CLKIN1_PERIOD(60.0))
					  u_gclk_mmcm(.CLKIN1(GCLK),.CLKFBIN(glitcbus_clkfb),.PWRDWN(1'b0),.RST(1'b0),
									  .CLKOUT0(glitcbus_clk_to_BUFG),.CLKFBOUT(glitcbus_clkfb_to_BUFG));
	assign gb_clk_o = glitcbus_clk;
	
endmodule
