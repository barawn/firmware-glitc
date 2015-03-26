`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// This file is a part of the Antarctic Impulsive Transient Antenna (ANITA)
// project, a collaborative scientific effort between multiple institutions. For
// more information, contact Peter Gorham (gorham@phys.hawaii.edu).
//
// All rights reserved.
//
// Author: Patrick Allison, Ohio State University (allison.122@osu.edu)
// Author:
// Author:
////////////////////////////////////////////////////////////////////////////////
module GLITC_clock_generator(
		input GA_SYSCLK_P,
		input GA_SYSCLK_N,
		input clk_i,
		input [2:0] ctrl_i,
		output [1:0] status_o,
		input [7:0] phase_ctrl_i,
		output [7:0] phase_ctrl_o,
		
		output CLK200,
		output SYSCLK,
		output SYSCLKX2,
		output SYSCLK_DIV2_PS,
		output DATACLK,
		output DATACLK_DIV2		
    );

	wire sysclk_in_to_bufg, sysclk_in_bufg;
	wire sysclk_mult_to_bufg, sysclk_mult;
	wire sysclk_mult_fb_to_bufg, sysclk_mult_fb;
	
	wire mmcm_reset = ctrl_i[0];
	wire mult_mmcm_pwrdwn = ctrl_i[1];
	wire sysclk_mult_sel = ctrl_i[2];
	
	IBUFDS u_sysclk_ibuf(.I(GA_SYSCLK_P),.IB(GA_SYSCLK_N),.O(sysclk_in_to_bufg));
	BUFG   u_sysclk_in_bufg(.I(sysclk_in_to_bufg),.O(sysclk_in_bufg));
	// We have 2 MMCMs here. The first, if enabled, boosts GA_SYSCLK_P/N to 162.5 MHz (times 6.5).
	// The next generates the local clocks.
	// VCO here is 650.
	wire sysclk_mult_mmcm_locked;
	MMCME2_BASE #(.BANDWIDTH("OPTIMIZED"),
					  .CLKFBOUT_MULT_F(26),
					  .DIVCLK_DIVIDE(1),
					  .CLKIN1_PERIOD(40.0),
					  .CLKOUT0_DIVIDE_F(4),
					  .CLKOUT0_PHASE(0.0)) u_sysclk_mult_mmcm(.CLKIN1(sysclk_in_bufg),
																			.CLKFBIN(sysclk_mult_fb),
																			.CLKOUT0(sysclk_mult_to_bufg),
																			.CLKFBOUT(sysclk_mult_fb_to_bufg),
																			.PWRDWN(mult_mmcm_pwrdwn),
																			.RST(mmcm_reset),
																			.LOCKED(sysclk_mult_mmcm_locked));
	BUFG u_sysclk_mult_fb_bufg(.I(sysclk_mult_fb_to_bufg),.O(sysclk_mult_fb));
	BUFG u_sysclk_mult_bufg(.I(sysclk_mult_to_bufg),.O(sysclk_mult));

	wire clk200_to_bufg, clk200_bufg;
	wire sysclk_div2_ps_to_bufg, sysclk_div2_ps_bufg;
	wire dataclk_to_bufg, dataclk_bufg;
	wire dataclk_div2_to_bufg, dataclk_div2_bufg;
	wire sysclkx2_to_bufg, sysclkx2_bufg;

	wire sysclk_mmcm_locked;
	wire ps_clock;
	wire ps_enable;
	wire ps_increment_ndecrement;
	wire ps_done;

	MMCME2_ADV #(.BANDWIDTH("OPTIMIZED"),
					 .DIVCLK_DIVIDE(1),
					 .CLKFBOUT_MULT_F(6),
					 .CLKIN1_PERIOD(6.153),
					 .CLKIN2_PERIOD(6.153),
					 .CLKOUT0_DIVIDE_F(4.875),		// clk200			200 MHz
					 .CLKOUT1_DIVIDE(12),			// sysclk_div2_ps	81.25 MHz
					 .CLKOUT2_DIVIDE(3),				// dataclk			325 MHz
					 .CLKOUT2_PHASE(60),				// dataclk			t += ~500 ps
					 .CLKOUT3_DIVIDE(6),				// dataclk_div2	162.5 MHz
					 .CLKOUT3_PHASE(30),				// dataclk_div2	t += ~500 ps
					 .CLKOUT4_DIVIDE(3),				// sysclkx2			325 MHz
					 .CLKOUT4_PHASE(0)) u_sysclk_mmcm(.CLKIN1(sysclk_in_bufg),
																 .CLKIN2(sysclk_mult),
																 .CLKINSEL(sysclk_mult_sel),
																 .CLKFBIN(sysclk_bufg),
																 .CLKFBOUT(sysclk_to_bufg),
																 
																 .CLKOUT0(clk200_to_bufg),
																 .CLKOUT1(sysclk_div2_ps_to_bufg),
																 .CLKOUT2(dataclk_to_bufg),
																 .CLKOUT3(dataclk_div2_to_bufg),
																 .CLKOUT4(sysclkx2_to_bufg),
																 
																 .RST(mmcm_reset),
																 .LOCKED(sysclk_mmcm_locked),
																 
																 .PSCLK(ps_clock),
																 .PSEN(ps_enable),
																 .PSINCDEC(ps_increment_ndecrement),
																 .PSDONE(ps_done));
	BUFG u_clk200_bufg(.I(clk200_to_bufg),.O(clk200_bufg));
	BUFG u_sysclk_div2_ps_bufg(.I(sysclk_div2_ps_to_bufg),.O(sysclk_div2_ps_bufg));
	BUFG u_dataclk_bufg(.I(dataclk_to_bufg),.O(dataclk_bufg));
	BUFG u_dataclk_div2_bufg(.I(dataclk_div2_to_bufg),.O(dataclk_div2_bufg));
	BUFG u_sysclkx2_bufg(.I(sysclkx2_to_bufg),.O(sysclkx2_bufg));
	BUFG u_sysclk_bufg(.I(sysclk_to_bufg),.O(sysclk_bufg));
	
	assign status_o[0] = sysclk_mmcm_locked;
	assign status_o[1] = sysclk_mult_mmcm_locked;
	assign ps_clock = clk_i;
	assign ps_enable = phase_ctrl_i[0];
	assign ps_increment_ndecrement = phase_ctrl_i[1];
	assign phase_ctrl_o[0] = ps_done;
	assign phase_ctrl_o[7:1] = {6{1'b0}};

	assign CLK200 = clk200_bufg;
	assign SYSCLK = sysclk_bufg;
	assign SYSCLK_DIV2_PS = sysclk_div2_ps_bufg;
	assign DATACLK = dataclk_bufg;
	assign DATACLK_DIV2 = dataclk_div2_bufg;
	assign SYSCLKX2 = sysclkx2_bufg;

endmodule
