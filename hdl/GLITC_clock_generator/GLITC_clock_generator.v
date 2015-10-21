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
		input realign_i,
		output realigned_o,
		output CLK200,
		output SYSCLK,
		output SYSCLKX2,
		output SYSCLK_DIV2_PS,
		output DATACLK,
		output DATACLK_DIV2,
		output GICLK,
		output GICLK_DIV2
    );

//	parameter DATACLK_PHASE = 90;
//	parameter DATACLK_DIV2_PHASE = 45;
	// DATACLK = SYSCLK + 1 ns.
	parameter DATACLK_PHASE = 120;
	// DATACLK_DIV2 = SYSCLK + 4.65 ns
	parameter DATACLK_DIV2_PHASE = 240;

	// GICLK = SYSCLK + 2 ns.
	parameter GICLK_PHASE = 120;
	// GICLK_DIV2 = SYSCLK + 5.08 ns.
	parameter GICLK_DIV2_PHASE = 240;

	wire sysclk_in_to_bufg, sysclk_in_bufg;
	wire sysclk_mult_to_bufg, sysclk_mult;
	wire sysclk_mult_fb_to_bufg, sysclk_mult_fb;
	
	wire mmcm_reset = ctrl_i[0];
	wire mult_mmcm_pwrdwn = ctrl_i[1];
	wire sysclk_mult_sel = ctrl_i[2];
	
	wire mult_ps_en;
	wire mult_ps_increment_ndecrement;
	wire mult_ps_done;
	
	GLITC_clock_realigner u_realigner(.realign_i(realign_i),
	                                  .realigned_o(realigned_o),
	                                  .clk_i(clk_i),
	                                  .ps_en_o(mult_ps_en),
	                                  .ps_increment_ndecrement_o(mult_ps_increment_ndecrement),
	                                  .ps_done_i(mult_ps_done));	
	IBUFDS u_sysclk_ibuf(.I(GA_SYSCLK_P),.IB(GA_SYSCLK_N),.O(sysclk_in_to_bufg));
	BUFG   u_sysclk_in_bufg(.I(sysclk_in_to_bufg),.O(sysclk_in_bufg));
	// We have 2 MMCMs here. The first, if enabled, boosts GA_SYSCLK_P/N to 162.5 MHz (times 6.5).
	// The next generates the local clocks.
	// VCO here is 650.
	wire sysclk_mult_mmcm_locked;
	MMCME2_ADV #(.BANDWIDTH("OPTIMIZED"),
					  .CLKFBOUT_MULT_F(26),
					  .DIVCLK_DIVIDE(1),
					  .CLKIN1_PERIOD(40.0),
					  .CLKOUT0_DIVIDE_F(4),
					  .CLKOUT0_PHASE(0.0),
					  .CLKOUT0_USE_FINE_PS("TRUE"))
					  u_sysclk_mult_mmcm(.CLKIN1(sysclk_in_bufg),
					                     .CLKINSEL(1'b1),
                                         .CLKFBIN(sysclk_mult_fb),
                                         .CLKOUT0(sysclk_mult_to_bufg),
                                         .CLKFBOUT(sysclk_mult_fb_to_bufg),
                                         .PWRDWN(mult_mmcm_pwrdwn),
                                         .RST(mmcm_reset),
                                         .PSDONE(mult_ps_done),
                                         .PSCLK(clk_i),
                                         .PSEN(mult_ps_en),
                                         .PSINCDEC(mult_ps_increment_ndecrement),
                                         .LOCKED(sysclk_mult_mmcm_locked));
BUFG u_sysclk_mult_fb_bufg(.I(sysclk_mult_fb_to_bufg),.O(sysclk_mult_fb));
	BUFG u_sysclk_mult_bufg(.I(sysclk_mult_to_bufg),.O(sysclk_mult));

	wire clk200_to_bufg, clk200_bufg;
	wire sysclk_div2_ps_to_bufg, sysclk_div2_ps_bufg;
	wire dataclk_to_bufg, dataclk_bufg;
	wire dataclk_div2_to_bufg, dataclk_div2_bufg;
	wire sysclkx2_to_bufg, sysclkx2_bufg;
	wire giclk_to_bufg, giclk_bufg;
	wire giclk_div2_to_bufg, giclk_div2_bufg;
	
	wire sysclk_mmcm_locked;
	wire ps_clock;
	wire ps_enable;
	wire ps_increment_ndecrement;
	wire ps_done;

	// We need ALL of these damn clocks, amazingly.
	MMCME2_ADV #(.BANDWIDTH("OPTIMIZED"),
					 .DIVCLK_DIVIDE(1),
					 .CLKFBOUT_MULT_F(6),
					 .CLKIN1_PERIOD(6.153),
					 .CLKIN2_PERIOD(6.153),
					 .CLKOUT0_DIVIDE_F(4.875),						// clk200			200 MHz
					 .CLKOUT1_DIVIDE(12),							// sysclk_div2_ps	81.25 MHz
					 .CLKOUT2_DIVIDE(3),								// dataclk			325 MHz
					 .CLKOUT2_PHASE(DATACLK_PHASE),				// dataclk			(see top)
					 .CLKOUT3_DIVIDE(6),								// dataclk_div2	162.5 MHz
					 .CLKOUT3_PHASE(DATACLK_DIV2_PHASE),		// dataclk_div2	(see top)
					 .CLKOUT4_DIVIDE(3),								// sysclkx2			325 MHz
					 .CLKOUT4_PHASE(0),
					 .CLKOUT5_DIVIDE(3),								// giclk				325 MHz
					 .CLKOUT5_PHASE(GICLK_PHASE),					// giclk				(see top)
					 .CLKOUT6_DIVIDE(6),								// giclk_div2		162.5 MHz
					 .CLKOUT6_PHASE(GICLK_DIV2_PHASE),			// giclk_div2		(see top)
					 .CLKOUT1_USE_FINE_PS("TRUE")) u_sysclk_mmcm(.CLKIN1(sysclk_in_bufg),
																 .CLKIN2(sysclk_mult),
																 .CLKINSEL(sysclk_mult_sel),
																 .CLKFBIN(sysclk_bufg),
																 .CLKFBOUT(sysclk_to_bufg),
																 
																 .CLKOUT0(clk200_to_bufg),
																 .CLKOUT1(sysclk_div2_ps_to_bufg),
																 .CLKOUT2(dataclk_to_bufg),
																 .CLKOUT3(dataclk_div2_to_bufg),
																 .CLKOUT4(sysclkx2_to_bufg),
																 .CLKOUT5(giclk_to_bufg),
																 .CLKOUT6(giclk_div2_to_bufg),
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
	BUFG u_giclk_bufg(.I(giclk_to_bufg),.O(giclk_bufg));
	BUFG u_giclk_div2_bufg(.I(giclk_div2_to_bufg),.O(giclk_div2_bufg));
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
	assign GICLK = giclk_bufg;
	assign GICLK_DIV2 = giclk_div2_bufg;
endmodule
