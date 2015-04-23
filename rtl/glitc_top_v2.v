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
module glitc_top_v2(
 		    input GA_SYSCLK_P,
		    input GA_SYSCLK_N,

		    input A_CLK_P,
		    input A_CLK_N,
		    input [11:0] A_P,
		    input [11:0] A_N,

		    input B_CLK_P,
		    input B_CLK_N,
		    input [11:0] B_P,
		    input [11:0] B_N,

		    input C_CLK_P,
		    input C_CLK_N,
		    input [11:0] C_P,
		    input [11:0] C_N,

		    input D_CLK_P,
		    input D_CLK_N,
		    input [11:0] D_P,
		    input [11:0] D_N,

		    input E_CLK_P,
		    input E_CLK_N,
		    input [11:0] E_P,
		    input [11:0] E_N,

		    input F_CLK_P,
		    input F_CLK_N,
		    input [11:0] F_P,
		    input [11:0] F_N,		    
/*		    
		    output PHI_DOWN_OUT_CLK_P,
		    output PHI_DOWN_OUT_CLK_N,
		    output [3:0] PHI_DOWN_OUT_P,
		    output [3:0] PHI_DOWN_OUT_N,
		    output PHI_UP_OUT_CLK_P,
		    output PHI_UP_OUT_CLK_N,
		    output [3:0] PHI_UP_OUT_P,
		    output [3:0] PHI_UP_OUT_N,

		    input PHI_DOWN_IN_CLK_P,
		    input PHI_DOWN_IN_CLK_N,
		    input [3:0] PHI_DOWN_IN_P,
		    input [3:0] PHI_DOWN_IN_N,
		    input PHI_UP_IN_CLK_P,
		    input PHI_UP_IN_CLK_N,
		    input [3:0] PHI_UP_IN_P,
		    input [3:0] PHI_UP_IN_N,

*/		    output [1:0] VCDL,
		    output [1:0] TRAIN,

		    output [1:0] DAC_DIN,
		    output [1:0] DAC_LATCH,
		    output [1:0] DAC_CLK,

		    inout 	GA_SDA,
		    inout 	GA_SCL,

 		    input 	GCLK,
		    input 	GRDWR_B,
		    input 	GSEL_B,
		    inout [7:0] GAD,
			 
			 output [4:0] MON
		    );

	localparam [3:0] VER_BOARDREV = 0;
	localparam [3:0] VER_MONTH = 4;
	localparam [7:0] VER_DAY = 23;
	localparam [3:0] VER_MAJOR = 0;
	localparam [3:0] VER_MINOR = 1;
	localparam [7:0] VER_REV = 6;
	localparam [31:0] VERSION = {VER_BOARDREV,VER_MONTH,VER_DAY,VER_MAJOR,VER_MINOR,VER_REV};

   // GLITCBUS clock.
   wire 			gb_clk;
	// 200 MHz clock, for IDELAYCTRL.
	wire			CLK200;
	// RITC system clock (162.5 MHz).
	wire			SYSCLK;
	// Phase scanner clock.
	wire			SYSCLK_DIV2_PS;
	// Data clock (325 MHz, phase shifted).
	wire			DATACLK;
	// Data clock, divided by 2.
	wire			DATACLK_DIV2;
	// Sysclk, times 2.
	wire 			SYSCLKX2;
	// Sync. Indicates which phase of VCDL we're on.
	wire			SYNC;
	
   // GLITCBUS local side interface.
   wire [15:0] 			gb_address;
   wire [31:0] 			gb_data_to_tisc_mux;
   wire [31:0] 			gb_data_from_tisc;
   wire 			gb_wr;
   wire 			gb_rd;   

	glitcbus_clock u_gbclk(.GCLK(GCLK),.gb_clk_o(gb_clk));

   wire [70:0] gb_debug;
	wire [70:0] ps_debug;
	wire [70:0] i2c_debug;
	wire [70:0] dac_debug;

	// Simple SYNC implementation. Will add logic
	// to handle sync inputs.
	reg glitc_sync = 0;

	// Output data and selects.
	wire sel_ctrl = (gb_address[7:4] == 4'h00);
	wire [31:0] ctrl_data;
	wire sel_ps = (gb_address[7:4] == 4'h01);
	wire [31:0] ps_data;
	wire sel_datapath = (gb_address[7:4] == 4'h02) || (gb_address[7:4] == 4'h06);
	wire [31:0] datapath_data;
	wire sel_ritc = (gb_address[7:4] == 4'h03) || (gb_address[7:4] == 4'h07);
	wire [31:0] ritc_data = {32{1'b0}};
	wire sel_dac = (gb_address[7:4] == 4'h04);
	wire [31:0] dac_data;
	wire sel_i2c_data = (gb_address[7:4] == 4'h05);
	wire [31:0] i2c_data;

   glitcbus_slave_v2 u_slave(.gclk_i(gb_clk),
			  .GRDWR_B(GRDWR_B),
			  .GSEL_B(GSEL_B),
			  .GAD(GAD),
			  .gb_adr_o(gb_address),
			  .gb_dat_o(gb_data_from_tisc),
			  .gb_dat_i(gb_data_to_tisc_mux),
			  .gwr_o(gb_wr),
			  .grd_o(gb_rd),
			  .debug_o(gb_debug));

	wire [2:0] clock_ctrl;
	wire glitc_reset;
	GLITC_control_registers #(.VERSION(VERSION)) u_control(.user_clk_i(gb_clk),
												 .user_addr_i(gb_address[1:0]),
												 .user_dat_i(gb_data_from_tisc),
												 .user_dat_o(ctrl_data),
												 .user_wr_i(gb_wr),
												 .user_rd_i(gb_rd),
												 .user_sel_i(sel_ctrl),
												 .clk_control_o(clock_ctrl),
												 .reset_o(glitc_reset));
	/////
	// GLITC External Settings.
	/////
	wire sda_in, scl_in;
	wire sda_out, scl_out;
	wire sda_oe_b, scl_oe_b;
	assign sda_in = GA_SDA;
	assign scl_in = GA_SCL;
	assign GA_SDA = (sda_oe_b) ? 1'bZ : sda_out;
	assign GA_SCL = (scl_oe_b) ? 1'bZ : scl_out;
		
	GLITC_external_settings u_settings(.user_clk_i(gb_clk),
												  .user_sel_i(sel_i2c_data),
												  .user_wr_i(gb_wr),
												  .user_rd_i(gb_rd),
												  .user_addr_i(gb_address[3:0]),
												  .user_dat_i(gb_data_from_tisc),
												  .user_dat_o(i2c_data),
												  .debug_o(i2c_debug),
												  .scl_i(scl_in),.scl_o(scl_out),.scl_oen_o(scl_oe_b),
												  .sda_i(sda_in),.sda_o(sda_out),.sda_oen_o(sda_oe_b));

	///// 
	// RITC DAC interface.
	/////	
	wire servo_addr;
	wire servo_wr;
	wire servo_update;
	wire [11:0] servo_value;
	RITC_Dual_DAC u_dac_simple(.clk_i(gb_clk),
										.user_sel_i(sel_dac),
									  .user_addr_i(gb_address[0]),
									  .user_dat_i(gb_data_from_tisc),
									  .user_dat_o(dac_data),
									  .user_wr_i(gb_wr),
									  .user_rd_i(gb_rd),
									  .debug_o(dac_debug),

									  .servo_addr_i(servo_addr),
									  .servo_wr_i(servo_wr),
									  .servo_update_i(servo_update),
									  .servo_i(servo_value),
									  
									  .DAC_DIN(DAC_DIN),
									  .DAC_DOUT(DAC_DOUT),
									  .DAC_CLOCK(DAC_CLK),
									  .DAC_LATCH(DAC_LATCH));

	/////
	// RITC Datapath.
	//
	// The outputs here are the deserialized 48-bit input data (R0_DATA/R1_DATA),
	// as well as a copy of the high speed inputs (R0_BYPASS/R1_BYPASS). There is
	// also a clock capable copy of the output clock (REFCLK) as well as a copy
	// (REFCLK_BYPASS).
	/////
	wire [47:0] R0_DATA[2:0];
	wire [47:0] R1_DATA[2:0];
	wire [11:0] R0_BYPASS[2:0];
	wire [11:0] R1_BYPASS[2:0];
	wire [5:0] REFCLK_BYPASS;
	wire [5:0] REFCLK;
	wire [5:0] REFCLK_P = {F_CLK_P,E_CLK_P,D_CLK_P,C_CLK_P,B_CLK_P,A_CLK_P};
	wire [5:0] REFCLK_N = {F_CLK_N,E_CLK_N,D_CLK_N,C_CLK_N,B_CLK_N,A_CLK_N};
	wire [11:0] datapath_debug;
	RITC_full_datapath_v2    u_full_datapath(.REFCLK_P(REFCLK_P),.REFCLK_N(REFCLK_N),
													  .CH0_P(A_P),.CH0_N(A_N),
													  .CH1_P(B_P),.CH1_N(B_N),
													  .CH2_P(C_P),.CH2_N(C_N),
													  .CH3_P(D_P),.CH3_N(D_N),
													  .CH4_P(E_P),.CH4_N(E_N),
													  .CH5_P(F_P),.CH5_N(F_N),
													  .DATACLK(DATACLK),
													  .DATACLK_DIV2(DATACLK_DIV2),
													  .SYSCLK(SYSCLK),
													  .SYSCLK_DIV2_PS(SYSCLK_DIV2_PS),
													  .CLK200(CLK200),
													  
													  .CH0_OUT(R0_DATA[0]),
													  .CH1_OUT(R0_DATA[1]),
													  .CH2_OUT(R0_DATA[2]),		
													  .CH3_OUT(R1_DATA[0]),
													  .CH4_OUT(R1_DATA[1]),
													  .CH5_OUT(R1_DATA[2]),
													  .CH0_BYPASS(R0_BYPASS[0]),
													  .CH1_BYPASS(R0_BYPASS[1]),
													  .CH2_BYPASS(R0_BYPASS[2]),
													  .CH3_BYPASS(R1_BYPASS[0]),
													  .CH4_BYPASS(R1_BYPASS[1]),
													  .CH5_BYPASS(R1_BYPASS[2]),
													  .REFCLK_BYPASS(REFCLK_BYPASS),
													  
													  .SYNC(SYNC),
													  .VCDL(VCDL),
													  .TRAIN_ON(TRAIN),
													  
													  .user_clk_i(gb_clk),
													  .user_sel_i(sel_datapath),
													  .user_addr_i(gb_address[3:0]),
													  .user_wr_i(gb_wr),
													  .user_rd_i(gb_rd),
													  .user_dat_i(gb_data_from_tisc),
													  .user_dat_o(datapath_data),
													  .debug_o(datapath_debug));

	////
	// RITC controller. Generates the VCDL inputs, handles synchronization,
	// handles 
//	RITC_dual_controller u_dual_controller(.user_clk_i

	////
	// RITC phase scanner. Takes 6 inputs, generates an equivalent time waveform of them with ~ps resolution,
	// and locates edges in the data to determine timing and servo the DAC values.
	////
	wire [7:0] phase_ctrl_in;
	wire [7:0] phase_ctrl_out;
	
	RITC_dual_phase_scanner_v3 u_phase_scanner(.user_clk_i(gb_clk),
															 .user_sel_i(sel_ps),
															 .user_wr_i(gb_wr),
															 .user_addr_i(gb_address[3:0]),
															 .user_rd_i(gb_rd),
															 .user_dat_i(gb_data_from_tisc),
															 .user_dat_o(ps_data),
															 .CH0_SCAN(R0_BYPASS[0]),
															 .CH1_SCAN(R0_BYPASS[1]),
															 .CH2_SCAN(R0_BYPASS[2]),
															 .CH3_SCAN(R1_BYPASS[0]),
															 .CH4_SCAN(R1_BYPASS[1]),
															 .CH5_SCAN(R1_BYPASS[2]),
															 .CLK_SCAN(REFCLK_BYPASS),
															 .CLK_PS(SYSCLK_DIV2_PS),
															 .phase_control_out(phase_ctrl_out),
															 .phase_control_in(phase_ctrl_in),
															 .servo_addr_o(servo_addr),
															 .servo_wr_o(servo_wr),
															 .servo_o(servo_value),
															 .servo_update_o(servo_update),
															 .debug_o(ps_debug));
															 
	// Pointless single correlation. Put this here so it does *something*... anything.														 
	wire [11:0] corr_R0;
	wire [11:0] corr_R1;
	single_corr_v6 u_corr_R0(.clk(SYSCLK),.A(R0_DATA[0]),.B(R0_DATA[1]),.C(R0_DATA[2]),.CORR(corr_R0));
	single_corr_v6 u_corr_R1(.clk(SYSCLK),.A(R1_DATA[0]),.B(R1_DATA[1]),.C(R1_DATA[2]),.CORR(corr_R1));

	GLITC_clock_generator u_clock_generator(.GA_SYSCLK_P(GA_SYSCLK_P),
														 .GA_SYSCLK_N(GA_SYSCLK_N),
														 .clk_i(gb_clk),
														 .ctrl_i(clock_ctrl),
														 .status_o(clock_status),
														 .phase_ctrl_i(phase_ctrl_out),
														 .phase_ctrl_o(phase_ctrl_in),
														 .CLK200(CLK200),
														 .SYSCLK(SYSCLK),
														 .SYSCLKX2(SYSCLKX2),
														 .SYSCLK_DIV2_PS(SYSCLK_DIV2_PS),
														 .DATACLK(DATACLK),
														 .DATACLK_DIV2(DATACLK_DIV2));
	always @(posedge SYSCLK) glitc_sync <= ~glitc_sync;
	assign SYNC = glitc_sync;

	wire [70:0] debug_ritc;
	assign debug_ritc[11:0] = datapath_debug;//{corr_R0,corr_R1};

	// We'll split up the firmware as such:
   // All RITC datapath, GLITC logic, etc. goes in the
   // dual_glitc_top module.
   // Interfaces needed:
   // Phase scanner needs PS_EN, PS_INCDEC, and PS_DONE,
   //     as well as CLOCK_OUT, CH0_OUT, CH1_OUT, and CH2_OUT, and VCDL_Q.
   //     That's it.
   // Also need interface for RITC Controller and RITC_IDELAY. This
   // can be identical interfacing, split them by address.
   //
   // I2C interface at the top, phase scanner at the top,
   // RITC DAC interface at the top. All of those run at GLITCBUS
   // speeds - we have to relax this timing a ton.

	//
	// We need 6 address spaces.
	// 0x0000-0x000F : Identification, versioning, and control (clock control).
	// 0x0010-0x001F : Phase scanner.
	// 0x0020-0x002F : Datapath control.
	// 0x0030-0x003F : RITC control.
	// 0x0040-0x004F : RITC DAC interface.
	// 0x0050-0x005F : I2C interface.
	// 0x0060-0x006F : IDELAY control (shadow)
	// 0x0070-0x007F : RITC control (shadow)
	
	wire [31:0] gb_data_to_tisc[7:0];
	assign gb_data_to_tisc[0] = ctrl_data;
	assign gb_data_to_tisc[1] = ps_data;
	assign gb_data_to_tisc[2] = datapath_data;
	assign gb_data_to_tisc[3] = ritc_data;
	assign gb_data_to_tisc[4] = dac_data;
	assign gb_data_to_tisc[5] = i2c_data;
	assign gb_data_to_tisc[6] = datapath_data;
	assign gb_data_to_tisc[7] = ritc_data;
	
   assign gb_data_to_tisc_mux = gb_data_to_tisc[gb_address[6:4]];
	
	wire [35:0] ila0_control;
	wire [35:0] ila1_control;
	wire [35:0] vio_control;
	wire [70:0] ila0_debug;
	wire [70:0] ila1_debug;
	wire [7:0] glitc_to_vio = {8{1'b0}};
	wire [7:0] vio_to_glitc;
	wire [1:0] debug_mux = vio_to_glitc[1:0];
	
	assign ila1_debug[31:0] = debug_ritc;
	// Only gb_clk-side modules have a muxable debug.
	// sysclk is too fast.
	glitc_debug_mux u_debug_mux(.clk_i(gb_clk),
										 .sel_i(debug_mux),
										 .debug0_i(gb_debug),
										 .debug1_i(ps_debug),
										 .debug2_i(i2c_debug),
										 .debug3_i(dac_debug),
										 .debug_o(ila0_debug));
	glitc_icon u_icon(.CONTROL0(ila0_control),.CONTROL1(ila1_control),.CONTROL2(vio_control));
	glitc_ila u_ila0(.CONTROL(ila0_control),.CLK(gb_clk),.TRIG0(ila0_debug));
	glitc_ila u_ila1(.CONTROL(ila1_control),.CLK(SYSCLK),.TRIG0(ila1_debug));
	glitc_vio u_vio(.CONTROL(vio_control),.CLK(gb_clk),.SYNC_IN(glitc_to_vio),.SYNC_OUT(vio_to_glitc));
	
	assign MON[0] = DAC_CLK[0];
	assign MON[1] = DAC_CLK[1];
	assign MON[2] = DAC_LATCH[0];
	assign MON[3] = DAC_LATCH[1];
	assign MON[4] = 1'b0;
	
	
endmodule
