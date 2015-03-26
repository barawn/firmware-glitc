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
module RITC_dual_phase_scanner_v4(
		// User interface.
		input user_clk_i,
		input user_sel_i,
		input user_wr_i,
		input user_rd_i,
		input [3:0] user_addr_i,
		input [31:0] user_dat_i,
		output [31:0] user_dat_o,
		// Scan targets.
		input [11:0] CH0_SCAN,
		input [11:0] CH1_SCAN,
		input [11:0] CH2_SCAN,
		input [11:0] CH3_SCAN,
		input [11:0] CH4_SCAN,
		input [11:0] CH5_SCAN,
		input [5:0] CLK_SCAN,
		input [1:0] VCDL_SCAN,
		// Outputs. For the RITC controller, to see the clock phase.
		output [5:0] CLK_Q,
		// Phase scan interface
		input CLK_PS,
		output phase_control_clk,
		output [7:0] phase_control_out,
		input [7:0] phase_control_in,
		// Servo interface
		output servo_addr_o,
		output servo_wr_o,
		output servo_update_o,
		output [11:0] servo_o,
		// Debug, for Chipscope.
		output [70:0] debug_o
    );

	wire PSEN;
	wire PSINCDEC;
	wire PSDONE = phase_control_in[0];
	assign phase_control_out = {{6{1'b0}},PSINCDEC,PSEN};
	assign phase_control_clk = user_clk_i;
	wire do_scan;
	wire [2:0] CLOCK_Q[1:0];
	wire [11:0] CH_Q[1:0][2:0];
	wire [1:0] VCDL_Q;
	
	RITC_phase_scanner_registers_v3 
		u_registers_R0(.CLK_PS(CLK_PS),
							.user_clk_i(user_clk_i),
							.user_scan_i(do_scan),
							.CLK_IN(CLK_SCAN[2:0]),
							.CH0_IN(CH0_SCAN),
							.CH1_IN(CH1_SCAN),
							.CH2_IN(CH2_SCAN),
							.VCDL_IN(VCDL_SCAN[0]),
							.CLK_Q(CLOCK_Q[0]),
							.CH0_Q(CH_Q[0][0]),
							.CH1_Q(CH_Q[0][1]),
							.CH2_Q(CH_Q[0][2]),
							.VCDL_Q(VCDL_Q[0]));
	RITC_phase_scanner_registers_v2 
		u_registers_R1(.CLK_PS(CLK_PS),
							.user_clk_i(user_clk_i),
							.user_scan_i(do_scan),
							.CLK_IN(CLK_SCAN[5:3]),
							.CH0_IN(CH3_SCAN),
							.CH1_IN(CH4_SCAN),
							.CH2_IN(CH5_SCAN),
							.VCDL_IN(VCDL_SCAN[1]),
							.CLK_Q(CLOCK_Q[1]),
							.CH0_Q(CH_Q[1][0]),
							.CH1_Q(CH_Q[1][1]),
							.CH2_Q(CH_Q[1][2]),
							.VCDL_Q(VCDL_Q[1]));
	// Outputs, to RITC controller, to see phase. RITC0.
	assign CLK_Q[2:0] = CLOCK_Q[0];
	// Outputs, to RITC controller, to see phase. RITC1.
	assign CLK_Q[5:3] = CLOCK_Q[1];

	//% Selects.
	wire [7:0] select_R0;
	wire [7:0] select_R1;
	
   //% Expanded clock array (from '3' to '4' for a power of 2).
   wire [3:0]      clock_demuxed[1:0];
   //% Register for the selected clock.
   reg [1:0]       clock_scan = {2{1'b0}};

   //% Expanded channel bit array (from '3' to '4' channels for a power of 2).
   wire [11:0]    ch_demuxed[1:0][3:0];
   //% First-stage multiplexed selected bit registers. (stage 1: select channel)
   reg [11:0]     signal_scan_ch_R0 = {12{1'b0}};
   reg [11:0]     signal_scan_ch_R1 = {12{1'b0}};

   //% Expanded bit array (from '12' to '16' for a power of 2).
   wire [15:0]    bit_demuxed[1:0];
   //% Final multiplexed bit register.
   reg  [1:0]     signal_scan = {2{1'b0}};
   //% Reregistered VCDL scan.
   reg  [1:0]     vcdl_scan = 0;

   /////////////////////////////////////////////////////////////////////////////
   // CLOCK AND BIT MULTIPLEXING : LOGIC                                      //
   /////////////////////////////////////////////////////////////////////////////

   // Set up the expanded arrays.
   // Assigning '3' to '1' here saves logic (clock_select_reg[0] = 1 selects CH1)
   assign clock_demuxed[0] = {CLOCK_Q[0][1],CLOCK_Q[0]};
   assign clock_demuxed[1] = {CLOCK_Q[1][1],CLOCK_Q[1]};

   // Same for the channel bit array.
   assign ch_demuxed[0][0] = CH_Q[0][0];
   assign ch_demuxed[0][1] = CH_Q[0][1];
   assign ch_demuxed[0][2] = CH_Q[0][2];
   assign ch_demuxed[0][3] = CH_Q[0][1];
   assign ch_demuxed[1][0] = CH_Q[1][0];
   assign ch_demuxed[1][1] = CH_Q[1][1];
   assign ch_demuxed[1][2] = CH_Q[1][2];
   assign ch_demuxed[1][3] = CH_Q[1][1];

   // Then for the bits, map 12->15 to 4->7 to save logic.
   assign bit_demuxed[0] = {signal_scan_ch_R0[7:4],signal_scan_ch_R0};
   assign bit_demuxed[1] = {signal_scan_ch_R1[7:4],signal_scan_ch_R1};

   //% Logic for multiplexing all clocks and bits into a single output.
   always @(posedge user_clk_i) begin : CLOCK_BIT_MULTIPLEX

      // Multiplex the clocks.
      clock_scan[0] <= clock_demuxed[0][select_R0[7:6]];
      clock_scan[1] <= clock_demuxed[1][select_R1[7:6]];

      // Multiplex the channel bit arrays first.
      signal_scan_ch_R0 <= ch_demuxed[0][select_R0[5:4]];
      signal_scan_ch_R1 <= ch_demuxed[1][select_R1[5:4]];

      // And then multiplex the bits themselves.
      signal_scan[0] <= bit_demuxed[0][select_R0[3:0]];
      signal_scan[1] <= bit_demuxed[1][select_R1[3:0]];

      // Store VCDL scan too. (It's just a straight store, so store both in 1 command)
      vcdl_scan <= VCDL_Q;
   end
	// The original PicoBlaze phase scanner used just 8 8-bit registers. We have significantly
	// more than that (16 32-bit registers) but for the most part we can keep things similar:

	// Command register.
	wire sel_command = (user_addr_i == 4'h00) && user_sel_i;
	reg [15:0] command_reg = {16{1'b0}};
	wire [31:0] command_data = {{16{1'b0}},command_reg};
	// Scan select register.
	wire sel_scan = (user_addr_i == 4'h01) && user_sel_i;
	reg [15:0] scan_reg = {16{1'b0}};
	wire [31:0] scan_data = {{16{1'b0}},scan_reg};
	// Argument register.
	wire sel_arg = (user_addr_i == 4'h02) && user_sel_i;
	reg [15:0] argument_reg = {16{1'b0}};
	wire [31:0] argument_data = {{16{1'b0}},argument_reg};
	// Result register.
	wire sel_result = (user_addr_i == 4'h03) && user_sel_i;
	reg [15:0] result_reg = {16{1'b0}};
	wire [31:0] result_data = {{16{1'b0}},result_reg};
	// Servo register.
	wire sel_servo = (user_addr_i == 4'h04) && user_sel_i;
	reg [31:0] servo_reg = {32{1'b0}};
	wire sel_pbctrl = (user_addr_i == 4'h05) && user_sel_i;

	// PicoBlaze reprogramming and overall control register.
	wire [31:0] pb_control_data;
	wire sel_pbdata = (user_addr_i == 4'h06) && user_sel_i;
	wire [31:0] pb_bram_data;

	wire [31:0] output_data[7:0];
	assign output_data[0] = command_data;
	assign output_data[1] = scan_data;
	assign output_data[2] = argument_data;
	assign output_data[3] = result_data;
	assign output_data[4] = servo_reg;
	assign output_data[5] = pb_control_data;
	assign output_data[6] = pb_bram_data;
	assign output_data[7] = output_data[3];
	assign user_dat_o = output_data[user_addr_i[2:0]];

	assign select_R0 = scan_reg[7:0];
	assign select_R1 = scan_reg[15:8];

	wire [17:0] pbInstruction;
	wire [11:0] pbAddress;
	wire pbRomEnable;
	wire [7:0] pb_port;
	wire [7:0] pb_outport;


	// At 33 MHz (really 8 MHz!) the decode should be plenty fast.
	wire pb_sel_command = (pb_port[7:2] == 5'h00);
	wire pb_sel_scan = (pb_port[7:2] == 5'h01);
	wire pb_sel_arg = (pb_port[7:2] == 5'h02);
	wire pb_sel_result = (pb_port[7:2] == 5'h02);
	wire pb_sel_servo = (pb_port[7:2] == 5'h03);
	wire pb_sel_debug = (pb_port[7:2] == 5'h04);
	wire pb_sel_servoctl = (pb_port[7:2] == 5'h05);
	wire pb_sel_vdd = (pb_port[7:2] == 5'h06);
	
	wire [7:0] scan_status;
	reg psen_reg = 0;
	reg psincdec_reg = 0;
	reg reset_output = 0;
	reg scan_done_reg = 0;
	reg psdone_seen = 0;
	assign scan_status[0] = psen_reg;
	assign scan_status[1] = psincdec_reg;
	assign scan_status[2] = psdone_seen;
	assign scan_status[7:3] = {5{1'b0}};
	
	reg do_scan_reg = 0;
	reg [1:0] do_scan_reg_delayed = {2{1'b0}};
	reg [7:0] scan_store = {8{1'b0}};
	assign do_scan = do_scan_reg;
	
	reg processor_reset = 0;
	reg bram_we_enable = 0;
	reg [11:0] bram_address_reg = {12{1'b0}};
	reg [17:0] bram_data_reg = {18{1'b0}};
	reg bram_we = 0;
	wire [17:0] bram_readback;
	assign pb_bram_data = {processor_reset,bram_we_enable,bram_address_reg,bram_readback};
	assign pb_control_data = {32{1'b0}};

	reg [23:0] counter = {24{1'b0}};
	reg timer_flag = 0;
	wire interrupt_ack;
	
	reg [11:0] vdd_output = {12{1'b0}};
	reg vdd_output_addr = 0;
	reg vdd_output_load = 0;
	reg vdd_output_wr = 0;

	reg [31:0] pb_debug = {32{1'b0}};
	
	always @(posedge user_clk_i) begin
		// PicoBlaze timer.
		counter <= counter + 1;
		if (counter == {24{1'b0}}) timer_flag <= 1;
		else if (interrupt_ack) timer_flag <= 0;	
	
		// PicoBlaze reprogramming. 2 bits for control,
		// 12 bits for address (only really need 10), and 18 bits
		// for data.
		if (sel_pbdata && user_wr_i) processor_reset <= user_dat_i[31];
		if (sel_pbdata && user_wr_i) bram_we_enable <= user_dat_i[30];
		if (sel_pbdata && user_wr_i) begin
			bram_data_reg <= user_dat_i[0 +: 18];
			bram_address_reg <= user_dat_i[18 +: 12];
		end
		if (sel_pbdata && user_wr_i && bram_we_enable) bram_we <= 1;
		else bram_we <= 0;

		// Command register input/output. Output indicates when command done.
		if (sel_command && user_wr_i) command_reg <= user_dat_i[15:0];
		else begin
			if (pb_sel_command && pb_write && !pb_port[0]) command_reg[7:0] <= pb_outport;
			if (pb_sel_command && pb_write && pb_port[0]) command_reg[7:0] <= pb_outport;
		end
		
		// Scan register input.
		if (sel_scan && user_wr_i) scan_reg <= user_dat_i[15:0];
		// Arg register input.
		if (sel_arg && user_wr_i) argument_reg <= user_dat_i[15:0];

		// Watch for PSDONE going high after a phase change requested.
		if (PSDONE) psdone_seen <= 1;
		else if (pb_sel_scan && pb_write && pb_outport[2]) psdone_seen <= 0;

		// Capture scan results when PSDONE goes high.
		do_scan_reg <= (PSDONE && !psdone_seen);
		do_scan_reg_delayed <= {do_scan_reg_delayed[0],do_scan_reg};
		if (do_scan_reg_delayed[1]) begin
			scan_store[0] <= clock_scan[0];
			scan_store[1] <= signal_scan[0];
			scan_store[2] <= vcdl_scan[0];
			scan_store[3] <= 0;
			scan_store[4] <= clock_scan[1];
			scan_store[5] <= signal_scan[1];
			scan_store[6] <= vcdl_scan[1];
			scan_store[7] <= 0;
		end
		
		// Phase change controls.
		if (pb_sel_scan && pb_write) begin
			psen_reg <= pb_outport[0];
			psincdec_reg <= pb_outport[1];
			scan_done_reg <= pb_outport[3];
		end else begin
			psen_reg <= 0;
			scan_done_reg <= 0;
		end
		
		// Result output.
		if (pb_sel_result && pb_write && !pb_port[0]) result_reg[7:0] <= pb_outport;
		if (pb_sel_result && pb_write && pb_port[0]) result_reg[15:8] <= pb_outport;

		// Servo control.
		// Sequence:
		// write R0_VDD[7:0] to 0x18
		// write R0_VDD[11:8] to 0x19
		// write R1_VDD[7:0] to 0x18
		// write (R1_VDD[11:8] | 0x10) to 0x19
		// write 0x80 to 0x19
		if (pb_sel_vdd && pb_write && !pb_port[0]) vdd_output[7:0] <= pb_outport;
		if (pb_sel_vdd && pb_write && pb_port[0]) vdd_output[11:8] <= pb_outport[3:0];
		if (pb_sel_vdd && pb_write && pb_port[0]) vdd_output_addr <= pb_outport[4];
		if (pb_sel_vdd && pb_write && pb_port[0]) vdd_output_load <= pb_outport[7];
		vdd_output_wr <= (pb_sel_vdd && pb_write && pb_port[0] && !pb_outport[7]);

		// Debug register.
		if (pb_sel_debug && pb_write) begin
			if (pb_port[1:0] == 2'b00) pb_debug[7:0] <= pb_outport;
			if (pb_port[1:0] == 2'b01) pb_debug[15:8] <= pb_outport;
			if (pb_port[1:0] == 2'b10) pb_debug[23:16] <= pb_outport;
			if (pb_port[1:0] == 2'b11) pb_debug[31:24] <= pb_outport;
		end
	end
		
		
	assign PSEN = psen_reg;
	assign PSINCDEC = psincdec_reg;

	wire [7:0] pb_input_registers[31:0];
	assign pb_input_registers[0] = command_reg[7:0];
	assign pb_input_registers[1] = command_reg[15:8];
	assign pb_input_registers[2] = command_reg[7:0];
	assign pb_input_registers[3] = command_reg[15:8];
	assign pb_input_registers[4] = scan_status;
	assign pb_input_registers[5] = scan_store;
	assign pb_input_registers[6] = scan_status;
	assign pb_input_registers[7] = scan_store;
	assign pb_input_registers[8] = argument_reg[7:0];
	assign pb_input_registers[9] = argument_reg[15:8];
	assign pb_input_registers[10] = argument_reg[7:0];
	assign pb_input_registers[11] = argument_reg[15:8];
	assign pb_input_registers[12] = result_reg[7:0];
	assign pb_input_registers[13] = result_reg[15:8];
	assign pb_input_registers[14] = result_reg[7:0];
	assign pb_input_registers[15] = result_reg[15:8];
	assign pb_input_registers[16] = servo_reg[7:0];
	assign pb_input_registers[17] = servo_reg[15:8];
	assign pb_input_registers[18] = servo_reg[23:16];
	assign pb_input_registers[19] = servo_reg[31:24];
	assign pb_input_registers[20] = pb_input_registers[4];
	assign pb_input_registers[21] = pb_input_registers[5];
	assign pb_input_registers[22] = pb_input_registers[6];
	assign pb_input_registers[23] = pb_input_registers[7];
	assign pb_input_registers[24] = pb_input_registers[8];
	assign pb_input_registers[25] = pb_input_registers[9];
	assign pb_input_registers[26] = pb_input_registers[10];
	assign pb_input_registers[27] = pb_input_registers[11];
	assign pb_input_registers[28] = pb_input_registers[12];
	assign pb_input_registers[29] = pb_input_registers[13];
	assign pb_input_registers[30] = pb_input_registers[14];
	assign pb_input_registers[31] = pb_input_registers[15];

	assign servo_addr_o = vdd_output_addr;
	assign servo_wr_o = vdd_output_wr;
	assign servo_update_o = vdd_output_load;
	assign servo_o = vdd_output;

	reg [7:0] pb_inport = {8{1'b0}};
	always @(posedge user_clk_i) begin
		pb_inport <= pb_input_registers[pb_port[4:0]];
	end
	assign debug_o[0 +: 10] = pbAddress;
	assign debug_o[10 +: 8] = (pb_write) ? pb_outport : pb_inport;
	assign debug_o[18] = pb_write;
	assign debug_o[19] = pb_read;
	assign debug_o[20] = timer_flag;
	assign debug_o[21] = clock_scan[0];
	assign debug_o[22] = signal_scan[0];
	assign debug_o[23] = vcdl_scan[0];
	assign debug_o[24] = clock_scan[1];
	assign debug_o[25] = signal_scan[1];
	assign debug_o[26] = vcdl_scan[1];
	assign debug_o[27] = do_scan_reg_delayed[1]; // 1 when scans are valid
	assign debug_o[28] = processor_reset;
	assign debug_o[29] = servo_update_o;
	assign debug_o[30 +: 32] = pb_debug;
	kcpsm6 processor(.address(pbAddress),.instruction(pbInstruction),
														  .bram_enable(pbRomEnable),.in_port(pb_inport),
														  .out_port(pb_outport),.port_id(pb_port),
														  .write_strobe(pb_write),.read_strobe(pb_read),
														  .interrupt(timer_flag),.interrupt_ack(interrupt_ack),
														  .sleep(1'b0),
														  .reset(processor_reset),.clk(user_clk_i));

	ritc_phase_scan_program_V3 rom(.address(pbAddress),.instruction(pbInstruction),
											 .bram_we_i(bram_we),.bram_adr_i(bram_address_reg),
											 .bram_dat_i(bram_data_reg),.bram_dat_o(bram_readback),
											 .bram_rd_i(!bram_we),.clk(user_clk_i));


				
endmodule
