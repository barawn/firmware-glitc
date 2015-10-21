`timescale 1ns / 1ps

// This is the GLITCBUS interface side of the RITC datapath.
// This module was added for clear sysclk/clk isolation.
module RITC_datapath_control(
		input clk_i,
		input user_sel_i,
		input user_wr_i,
		input [3:0] user_addr_i,
		input [31:0] user_dat_i,
		output [31:0] user_dat_o,

		output fifo_reset_o,
		output fifo_enable_o,
		output serdes_reset_o,
		output delayctrl_reset_o,
		input delayctrl_ready_i,
		output datapath_disable_o,
		
		output [6:0] scaler_sel_o,
		output scaler_wr_o,
		input scaler_done_i,
		output disable_training_o,
		input [5:0] refclk_q_i,		
		output [1:0] vcdl_pulse_o,
		output [1:0] vcdl_enable_o,
		
		output [2:0] refclk_select_o,
		output refclk_select_wr_o,
		input [9:0] refclk_count_i,
		
		input [31:0] scaler_i,
		
		output ctrl_o
    );

	wire [31:0] data_out[15:0];
	assign user_dat_o = data_out[user_addr_i];
	
	wire [31:0] DPCTRL0;
	wire [31:0] DPCTRL1;
	wire [31:0] DPTRAINING;
	wire [31:0] DPCOUNTER;
	wire [31:0] DPIDELAY;
	wire [31:0] DPSCALER;

	assign data_out[0] = DPCTRL0;
	assign data_out[1] = DPCTRL1;
	assign data_out[2] = DPTRAINING;
	assign data_out[3] = DPCOUNTER;
	assign data_out[4] = DPIDELAY;
	assign data_out[5] = DPSCALER;
	assign data_out[6] = DPTRAINING;
	assign data_out[7] = DPCOUNTER;
	assign data_out[8] = DPCTRL0;
	assign data_out[9] = DPCTRL1;
	assign data_out[10] = DPTRAINING;
	assign data_out[11] = DPCOUNTER;
	assign data_out[12] = DPIDELAY;
	assign data_out[13] = DPSCALER;
	assign data_out[14] = DPTRAINING;
	assign data_out[15] = DPCOUNTER;

	//< IOFIFO resets
	reg fifo_reset = 0;
	//< IOFIFO enable
	reg fifo_enable = 0;
	//< SERDES reset.
	reg serdes_reset = 0;
	//< Delayctrl reset.
	reg delayctrl_reset = 0;
	//< Input buffer disable.
	reg datapath_disable = 1;
	
	//< Training disable
	reg train_disable = 0;	
	//< Scaler select.
	reg [6:0] scaler_select = {7{1'b0}};
	//< Scaler write flag.
	reg scaler_wr_flag = 0;
	
	//< VCDL pulse.
	reg [1:0] vcdl_pulse = {2{1'b0}};
	//< VCDL enable.
	reg [1:0] vcdl_enable = {2{1'b0}};
		
	//< REFCLK counter select.
	reg [2:0] refclk_select = {3{1'b0}};
	//< REFCLK counter select.
	wire refclk_select_wr = (user_sel_i && user_wr_i && user_addr_i == 4'd3);
	
	//< Delay register.
	reg [4:0] delay_in = {5{1'b0}};
	//< Bitslip flag.
	reg bitslip = 0;
	//< Load delays.
	reg delay_load = 0;
	//< Delay bit selection.
	reg [6:0] delay_bit_select = {7{1'b0}};
	
	always @(posedge clk_i) begin
		// Resets.
		if (user_sel_i && user_wr_i && user_addr_i == 4'd0) begin
			fifo_reset <= user_dat_i[0];
			fifo_enable <= user_dat_i[1];
			serdes_reset <= user_dat_i[2];
			delayctrl_reset <= user_dat_i[3];
			datapath_disable <= user_dat_i[5];
		end else begin
			fifo_reset <= 0;
			serdes_reset <= 0;
			delayctrl_reset <= 0;
		end
		// VCDL control register. Register 1. 
		if (user_sel_i && user_wr_i && user_addr_i == 4'd1) begin
			vcdl_pulse <= {user_dat_i[30],user_dat_i[28]};
			vcdl_enable <= {user_dat_i[31],user_dat_i[29]};
		end else begin
			vcdl_pulse <= {2{1'b0}};
		end
		// Scaler control. Register 2.
		if (user_sel_i && user_wr_i && user_addr_i == 4'd2) begin
			scaler_select <= user_dat_i[6:0];
			if (user_dat_i[6:1] != scaler_select[6:1] || user_dat_i[8]) scaler_wr_flag <= 1;
			train_disable <= user_dat_i[31];
		end else begin
			scaler_wr_flag <= 0;
		end
		
		// Counter select register. This is register 3.
		if (refclk_select_wr) begin
			refclk_select <= user_dat_i[16 +: 3];
		end

		// IDELAY control register.
		if (user_sel_i && user_wr_i && user_addr_i == 4'd4) begin
			delay_in <= user_dat_i[4:0];
			delay_bit_select <= user_dat_i[22:16];
			bitslip <= user_dat_i[30];
			delay_load <= user_dat_i[31];
		end else begin
			delay_load <= 0;
			bitslip <= 0;
		end		
	end

    wire busy;
	RITC_bit_control_loader u_loader(.bit_addr_i(delay_bit_select[3:0]),.chan_addr_i(delay_bit_select[6:4]),
												.delay_i(delay_in),
												.bitslip_i(bitslip),
												.load_i(delay_load),
												.clk_i(clk_i),
												.busy_o(busy),
												.ctrl_o(ctrl_o));

	// Register definitions.
	// DPCTRL0
	assign DPCTRL0[31:6] = {26{1'b0}};
	assign DPCTRL0[5] = datapath_disable;
	assign DPCTRL0[4] = delayctrl_ready_i;
	assign DPCTRL0[3:2] = 2'b00;
	assign DPCTRL0[1] = fifo_enable;
	assign DPCTRL0[0] = 1'b0;
	// DPCTRL1
	assign DPCTRL1 = {vcdl_enable[1],1'b0,vcdl_enable[0],1'b0,{6{1'b0}},refclk_q_i,{16{1'b0}}};
	// DPTRAINING
	assign DPTRAINING = {train_disable,{15{1'b0}},{7{1'b0}},scaler_done_i, 1'b0 ,scaler_select};
	// DPCOUNTER
	assign DPCOUNTER = {{12{1'b0}},refclk_select,{6{1'b0}},refclk_count_i};
	// DPIDELAY
	assign DPIDELAY = {{9{1'b0}},delay_bit_select,busy,{10{1'b0}},delay_in};
	// DPSCALER
	assign DPSCALER = scaler_i;
	
	// Outputs.
	assign fifo_reset_o = fifo_reset;
	assign fifo_enable_o = fifo_enable;
	assign serdes_reset_o = serdes_reset;
	assign delayctrl_reset_o = delayctrl_reset;
	assign datapath_disable_o = datapath_disable;
	assign scaler_sel_o = scaler_select;
	assign scaler_wr_o = scaler_wr_flag;
	assign disable_training_o = train_disable;
	assign vcdl_pulse_o = vcdl_pulse;
	assign vcdl_enable_o = vcdl_enable;
	assign refclk_select_o = refclk_select;
	assign refclk_select_wr_o = refclk_select_wr;
	
endmodule
