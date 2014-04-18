`timescale 1ns / 1ps
//% 'Equivalent time' signal scanner. Generates a waveform trace for any signal that's periodic
//% over 1 VCDL period (= everything from the RITC), with a resolution of ~18 ps.
//% Used for servo-locking (and diagnostics).
//%
//% This is version 2! Now with way more features!
//% This is a dual-input phase-scanner.
module RITC_dual_phase_scanner(
		input 	     CLK,
		input 	     CLK_PS,
		input [2:0]  CLOCK_SCAN_R0,
		input [2:0]  CLOCK_SCAN_R1,
		input [11:0] CH0_SCAN_R0,
		input [11:0] CH1_SCAN_R0,
		input [11:0] CH2_SCAN_R0,
		input [11:0] CH0_SCAN_R1,
		input [11:0] CH1_SCAN_R1,
		input [11:0] CH2_SCAN_R1, 
		input 	     VCDL_SCAN_R0,
		input 	     VCDL_SCAN_R1,
		output 	     phase_control_clk,
		output [7:0] phase_control_out,
		input [7:0]  phase_control_in,
		input 	     rst_i,
		input 	     user_sel_i,
		input [2:0]  user_addr_i,
		input [7:0]  user_dat_i,
		output [7:0] user_dat_o,
		input 	     user_wr_i,
		input 	     user_rd_i,
		output 	     SCAN_RESULT_R0,
		output 	     SCAN2_RESULT_R0,
		output 	     SCAN3_RESULT_R0,
		output 	     SCAN_RESULT_R1,
		output 	     SCAN2_RESULT_R1,
		output 	     SCAN3_RESULT_R1, 
		output 	     SCAN_VALID,
		output 	     SCAN_DONE,
		output 	     SERVO_VDD_INCR_R0,
		output 	     SERVO_VDD_DECR_R0,
		output 	     SERVO_VDD_INCR_R1,
		output 	     SERVO_VDD_DECR_R1,
		output [2:0] REFCLK_Q_R0,
		output [2:0] REFCLK_Q_R1,
		output REFCLK_R0_to_BUFR,
		output REFCLK_R1_to_BUFR,
		output [2:0] debug_o
    );

	// Expand the phase shift interface.
	wire PSEN;
	wire PSINCDEC;
	wire PSDONE = phase_control_in[0];
	wire RST_OUT;
	wire RST_IN = rst_i;
	assign phase_control_out = {RST_OUT,{5{1'b0}},PSINCDEC,PSEN};
	assign phase_control_clk = CLK;

	// Expand the user interface.
	wire [7:0] command;
	wire command_wr;
	wire [7:0] select;
	wire [15:0] argument;
	wire argument_wr;
	wire [15:0] result;
	wire result_valid;
	wire [15:0] servo;
	wire servo_update;
	RITC_phase_scanner_interface_v2 u_phase_scanner_if(.CLK(CLK),
							   .user_sel_i(user_sel_i),
							   .user_addr_i(user_addr_i),
							   .user_dat_i(user_dat_i),
							   .user_dat_o(user_dat_o),
							   .user_wr_i(user_wr_i),
							   .user_rd_i(user_rd_i),
							   
							   .cmd_o(command),
							   .cmd_wr_o(command_wr),
							   .select_o(select),
							   .argument_o(argument),
							   .argument_wr_o(argument_wr),
							   .result_i(result),
							   .result_valid_i(result_valid),
							   .servo_i(servo),
							   .servo_update_i(servo_update)
							   );
	wire [2:0] CLOCK_Q[1:0];
	wire [11:0] CH_Q[1:0][2:0];
	wire [1:0] VCDL_Q;
	RITC_phase_scanner_registers u_registers_R0(.CLK_PS(CLK_PS),
						 .CLK(CLK),
						 .CLOCK_to_BUFR(REFCLK_R0_to_BUFR),
						 .CLOCK_IN(CLOCK_SCAN_R0),
						 .CH0_IN(CH0_SCAN_R0),
						 .CH1_IN(CH1_SCAN_R0),
						 .CH2_IN(CH2_SCAN_R0),
						 .VCDL_IN(VCDL_SCAN_R0),
						 .CLOCK_OUT(CLOCK_Q[0]),
						 .CH0_OUT(CH_Q[0][0]),
						 .CH1_OUT(CH_Q[0][1]),
						 .CH2_OUT(CH_Q[0][2]),
						 .VCDL_Q(VCDL_Q[0]));
   	RITC_phase_scanner_registers u_registers_R1(.CLK_PS(CLK_PS),
						 .CLK(CLK),
						 .CLOCK_to_BUFR(REFCLK_R1_to_BUFR),
						 .CLOCK_IN(CLOCK_SCAN_R1),
						 .CH0_IN(CH0_SCAN_R1),
						 .CH1_IN(CH1_SCAN_R1),
						 .CH2_IN(CH2_SCAN_R1),
						 .VCDL_IN(VCDL_SCAN_R1),
						 .CLOCK_OUT(CLOCK_Q[1]),
						 .CH0_OUT(CH_Q[1][0]),
						 .CH1_OUT(CH_Q[1][1]),
						 .CH2_OUT(CH_Q[1][2]),
						 .VCDL_Q(VCDL_Q[1]));
   
	/////////////////////////////////////////////////////////////////////////////
	// CLOCK AND BIT MULTIPLEXING : DECLARATIONS											//
	/////////////////////////////////////////////////////////////////////////////

   //% Reregistered select for clock.
   reg [1:0] 	   clock_select_reg = {2{1'b0}};
   reg [5:0] 	   bit_select_reg = {6{1'b0}};

   //% Expanded clock array (from '3' to '4' for a power of 2).
   wire [3:0] 	   clock_demuxed[1:0];
   //% Register for the selected clock.
   reg [1:0] 	   clock_scan = {2{1'b0}};
   
   //% Expanded channel bit array (from '3' to '4' channels for a power of 2).
   wire [11:0] 	  ch_demuxed[1:0][3:0];
   //% First-stage multiplexed selected bit registers. (stage 1: select channel)
   reg [11:0] 	  signal_scan_ch_R0 = {12{1'b0}};
   reg [11:0] 	  signal_scan_ch_R1 = {12{1'b0}};
 	  
   //% Expanded bit array (from '12' to '16' for a power of 2).
   wire [15:0] 	  bit_demuxed[1:0];
   //% Final multiplexed bit register.
   reg 	[1:0]	  signal_scan = {2{1'b0}};
   //% Reregistered VCDL scan.
   reg 	[1:0]	  vcdl_scan = 0;
	
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
   always @(posedge CLK) begin : CLOCK_BIT_MULTIPLEX
      // Reregister both selects.
      clock_select_reg <= select[7:6];
      bit_select_reg <= select[5:0];
      
      // Multiplex the clocks.
      clock_scan[0] <= clock_demuxed[0][clock_select_reg];
      clock_scan[1] <= clock_demuxed[1][clock_select_reg];
      
      // Multiplex the channel bit arrays first.
      signal_scan_ch_R0 <= ch_demuxed[0][bit_select_reg[5:4]];
      signal_scan_ch_R1 <= ch_demuxed[1][bit_select_reg[5:4]];
      
      // And then multiplex the bits themselves.
      signal_scan[0] <= bit_demuxed[0][bit_select_reg[3:0]];
      signal_scan[1] <= bit_demuxed[1][bit_select_reg[3:0]];
      
      // Store VCDL scan too. (It's just a straight store, so store both in 1 command)
      vcdl_scan <= VCDL_Q;
   end	
   
	/////////////////////////////////////////////////////////////////////////////
	// PICOBLAZE : DECLARATIONS																//
	/////////////////////////////////////////////////////////////////////////////
				
	wire [7:0] pb_port;
	wire [7:0] pb_outport;
	reg [7:0] pb_inport = {8{1'b0}};
	wire pb_write;
	wire pb_read;

	reg [23:0] counter = {24{1'b0}};
	reg timer_flag = 0;
	wire interrupt_ack;
	always @(posedge CLK) begin
		counter <= counter + 1;
		if (counter == {24{1'b0}}) timer_flag <= 1;
		else if (interrupt_ack) timer_flag <= 0;
	end

	reg psdone_seen = 0;
	reg psdone_delayed = 0;
	reg [7:0] pb_command_reg = {8{1'b0}};
	reg [15:0] pb_argument_reg = {16{1'b0}};
	reg [15:0] pb_result_reg = {16{1'b0}};
	reg result_update_reg = 0;
	reg [15:0] pb_servo_reg = {16{1'b0}};
	reg servo_update_reg = 0;
	wire cmd_select = (pb_port[3:0] == 4'b0000);
	wire scan_select = (pb_port[3:0] == 4'b0001);
	wire arg_select = (pb_port[3:0] == 4'b0010) || (pb_port[3:0] == 4'b0011);
	wire result_select = (pb_port[3:0] == 4'b0100) || (pb_port[3:0] == 4'b0101);
	wire servo_select = (pb_port[3:0] == 4'b0110) || (pb_port[3:0] == 4'b0111);
	wire debug_select = (pb_port[3:2] == 2'b10) && !pb_port[0];
        wire scan2_select = (pb_port[3:2] == 2'b10) && pb_port[0];
        wire servoctl_select_R0 = (pb_port[3:2] == 3'b11) && !pb_port[0];
   wire      servoctl_select_R1 = (pb_port[3:2] == 3'b11) && pb_port[0];
   

   
   
   
	reg [1:0] servo_incr = {2{1'b0}};
	reg [1:0] servo_decr = {2{1'b0}};
	reg [2:0] debug_reg = {3{1'b0}};
	
	reg [1:0] scan_store = 0;
	reg [1:0] scan2_store = 0;
	reg [1:0] scan3_store = 0;
	
	reg psen_reg = 0;
	reg psincdec_reg = 0;	
	reg reset_output = 0;
	reg scan_done_reg = 0;
	
	reg processor_reset = 0;
	wire [17:0] pbInstruction;
	wire [11:0] pbAddress;
	wire pbRomEnable;

	/////////////////////////////////////////////////////////////////////////////
	// PICOBLAZE : LOGIC                                      						//
	/////////////////////////////////////////////////////////////////////////////
	
	always @(posedge CLK) begin : PICOBLAZE_LOGIC
		servo_incr[0] <= pb_write && servoctl_select_R0 && pb_outport[0];
		servo_decr[0] <= pb_write && servoctl_select_R0 && pb_outport[1];
	   servo_incr[1] <= pb_write && servoctl_select_R1 && pb_outport[0];
	   servo_decr[1] <= pb_write && servoctl_select_R1 && pb_outport[1];	   
	   
		// Grab the inputs.
		if (command_wr) pb_command_reg <= command;
		else if (cmd_select && pb_write) pb_command_reg <= pb_outport;
		
		if (argument_wr) pb_argument_reg <= argument;

		if (PSDONE) psdone_seen <= 1;
		else if ((scan_select || scan2_select) && pb_write && pb_outport[2]) psdone_seen <= 0;
		
		psdone_delayed <= PSDONE;
		
		if ((scan_select || scan2_select) && pb_write) begin
			psen_reg <= pb_outport[0];
			psincdec_reg <= pb_outport[1];
			scan_done_reg <= pb_outport[3];
		end else begin
			psen_reg <= 0;
			scan_done_reg <= 0;
		end
		
		if (result_select && pb_write) begin
			if (!pb_port[0]) pb_result_reg[7:0] <= pb_outport;
			if (pb_port[0]) begin 
				pb_result_reg[15:8] <= pb_outport;
				result_update_reg <= 1;
			end
		end else begin
			result_update_reg <= 0;
		end
		
		if (servo_select && pb_write) begin
			if (!pb_port[0]) pb_servo_reg[7:0] <= pb_outport;
			if (pb_port[0]) begin
				pb_servo_reg[15:8] <= pb_outport[7:0];
				servo_update_reg <= 1;
			end
		end else begin
			servo_update_reg <= 0;
		end

		// Resets.
		processor_reset <= RST_IN;
		if (scan_select && pb_write && pb_outport[7]) reset_output <= 1;
		else if (RST_IN) reset_output <= 0;

		// Store the results of the scan. (These are 2 bits now).
		if (psdone_delayed) begin
			scan_store <= clock_scan;
			scan2_store <= signal_scan;
			scan3_store <= vcdl_scan;
		end

		if (debug_select && pb_write) debug_reg <= pb_outport[2:0];
	
		if (scan_select) begin
			pb_inport[0] <= psen_reg;
			pb_inport[1] <= psincdec_reg;
			pb_inport[2] <= psdone_seen;
			pb_inport[3] <= 0;
			pb_inport[4] <= scan_store[0];
			pb_inport[5] <= scan2_store[0];
			pb_inport[6] <= scan3_store[0];
			pb_inport[7] <= 0;
		end else if (scan2_select) begin
		   pb_inport[0] <= psen_reg;
		   pb_inport[1] <= psincdec_reg;
		   pb_inport[2] <= psdone_seen;
		   pb_inport[3] <= 0;
		   pb_inport[4] <= scan_store[1];
		   pb_inport[5] <= scan2_store[1];
		   pb_inport[6] <= scan3_store[1];
		   pb_inport[7] <= 0;
		end 
		else if (cmd_select) pb_inport <= pb_command_reg;
		else if (arg_select) if (!pb_port[0]) pb_inport <= pb_argument_reg[7:0];
									else             pb_inport <= pb_argument_reg[15:8];
		else if (result_select) if (!pb_port[0]) pb_inport <= pb_result_reg[7:0];
										else				  pb_inport <= pb_result_reg[15:8];
		else if (servo_select)	if (!pb_port[0]) pb_inport <= pb_servo_reg[7:0];
										else				  pb_inport <= pb_servo_reg[15:8];
	end

	kcpsm6 processor(.address(pbAddress),.instruction(pbInstruction),
						  .bram_enable(pbRomEnable),.in_port(pb_inport),
						  .out_port(pb_outport),.port_id(pb_port),
						  .write_strobe(pb_write),.read_strobe(pb_read),
						  .interrupt(timer_flag),.interrupt_ack(interrupt_ack),
						  .sleep(1'b0),
						  .reset(processor_reset),.clk(CLK));
						  
	ritc_phase_scan_program_V2 rom(.address(pbAddress),.instruction(pbInstruction),
										 .enable(pbRomEnable),.clk(CLK));
						  
	assign PSEN = psen_reg;
	assign PSINCDEC = psincdec_reg;
	assign RST_OUT = reset_output;
	assign SCAN_VALID = psdone_delayed;
	assign SCAN_DONE = scan_done_reg;
	assign SCAN_RESULT_R0 = scan_store[0];
   assign SCAN_RESULT_R1 = scan_store[1];
   
	assign SCAN2_RESULT_R0 = scan2_store;
   assign SCAN2_RESULT_R1 = scan2_store[1];
   
	assign SCAN3_RESULT_R0 = scan3_store[1];
   assign SCAN3_RESULT_R1 = scan3_store[1];
   
	assign SERVO_VDD_INCR_R0 = servo_incr;
	assign SERVO_VDD_DECR_R0 = servo_decr;
	
	assign REFCLK_Q_R0 = CLOCK_Q[0];
   assign REFCLK_Q_R1 = CLOCK_Q[1];
   
	assign debug_o = debug_reg;
	
	assign result = pb_result_reg;
	assign result_valid = result_update_reg;
	assign servo = pb_servo_reg;
	assign servo_update = servo_update_reg;
endmodule
