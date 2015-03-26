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
// RAM-based RITC Dual DAC module.
//
// Inputs are stored in a block RAM, to save register and routing congestion
// (the BRAMs contain all of the decode logic, and have only 1 clock input).
//
// Both user code and the servo can write into BRAM - however, both writing
// at the same time is bad. Therefore before updating any RITC registers, first
// pause the servo, check to see that update is complete, and then write to BRAM,
// update values, and then unpause the servo.
module RITC_Dual_DAC(
		input clk_i,
		input user_sel_i,
		input user_wr_i,
		input user_rd_i,
		input user_addr_i,

		input servo_addr_i,			//< Which RITC is being selected
		input servo_wr_i,				//< Write servo value into BRAM.
		input servo_update_i,		//< Update servo contents into RITC.
		input [11:0] servo_i,		//< Servo value to be updated.
		
		input [31:0] user_dat_i,
		output [31:0] user_dat_o,
		input [1:0] DAC_DOUT,
		output [1:0] DAC_DIN,
		output [1:0] DAC_CLOCK,
		output [1:0] DAC_LATCH,
		
		output [70:0] debug_o		
    );

	// 33 total DACs, therefore we need 6 bits. 7th selects which RITC.
	wire [6:0] dac_addr = user_dat_i[12 +: 7];
	wire [11:0] dac_dat = user_dat_i[0 +: 12];

	wire [11:0] user_bram_dat_out;
	wire [31:0] user_data_dac;
	wire [31:0] user_data_ctrl;
	
	reg [6:0] addr_in = {7{1'b0}};
	reg [11:0] dat_in = {12{1'b0}};

	reg bram_wr_R0 = 0;
	reg bram_wr_R1 = 0;
	reg bram_rd_R0 = 0;
	reg bram_rd_R1 = 0;
	reg bram_rd_R0_seen = 0;
	reg bram_rd_R1_seen = 0;
	
	wire loader_rd;
	wire [11:0] bram_dat_out_R0;
	wire [11:0] bram_dat_out_R1;
	wire [11:0] loader_dat_out_R0;
	wire [11:0] loader_dat_out_R1;
	wire [5:0] loader_addr;
	reg do_load = 0;
	wire loader_busy;

	reg servo_load = 0;
	
	// Reads are complicated. Deal with them later, if we want to.
	always @(posedge clk_i) begin
		if (user_sel_i && !user_addr_i) begin
			bram_wr_R0 <= !dac_addr[6] && user_wr_i;
			bram_wr_R1 <= dac_addr[6] && user_wr_i;
		
			if (user_wr_i) addr_in <= dac_addr;
			if (user_wr_i) dat_in <= dac_dat;
		end

		if (user_sel_i && user_addr_i && user_wr_i) do_load <= user_dat_i[0];
		else if (!loader_busy) do_load <= 0;

		if (servo_update_i) servo_load <= 1;
		else if (!loader_busy) servo_load <= 0;		
	end
	function [11:0] scramble;
			 input [11:0] val;
			 begin
				scramble = {val[0],val[1],val[2],val[3],val[4],val[5],val[6],val[7],val[8],val[9],val[10],val[11]};
			 end
	endfunction
	
	wire servo_wr_R0 = servo_wr_i && !servo_addr_i;
	wire bram_en_R0 = bram_wr_R0 || servo_wr_R0;
	wire [1:0] bram_bwe_R0 = {2{bram_wr_R0 || servo_wr_R0}};

	wire servo_wr_R1 = servo_wr_i && servo_addr_i;
	wire bram_en_R1 = bram_wr_R1 || servo_wr_R1;
	wire [1:0] bram_bwe_R1 = {2{bram_wr_R1 || servo_wr_R1}};

	// Mux BRAM address. WRITE_WIDTH_A=12 means ADDRA=10 bits.
	wire [9:0] bram_address_R0 = (servo_wr_R0) ? 10'd31 : {{4{1'b0}},addr_in[5:0]};
	wire [9:0] bram_address_R1 = (servo_wr_R1) ? 10'd31 : {{4{1'b0}},addr_in[5:0]};
	// Mux BRAM data.
	wire [11:0] bram_data_R0 = (servo_wr_R0) ? servo_i : dat_in;
	wire [11:0] bram_data_R1 = (servo_wr_R1) ? servo_i : dat_in;

	// WRITE_WIDTH_A(12) means ADDRA is 10 bits wide.
	BRAM_TDP_MACRO #(.BRAM_SIZE("18Kb"),.DOA_REG(1),.WRITE_WIDTH_A(12),.READ_WIDTH_A(12),
													.DOB_REG(1),.WRITE_WIDTH_B(12),.READ_WIDTH_B(12))
			u_dac_bram_R0(.CLKA(clk_i),
							  .ENA(bram_en_R0),.WEA(bram_bwe_R0),.REGCEA(1'b0),
							  .ADDRA(bram_address_R0),.DIA(bram_data_R0),.DOA(bram_dat_out_R0),
							  .CLKB(clk_i),
							  .ENB(loader_rd),.WEB(2'b00),.REGCEB(1'b1),
							  .ADDRB({{4{1'b0}},loader_addr}),.DOB(loader_dat_out_R0),
							  .RSTA(1'b0),.RSTB(1'b0));
	BRAM_TDP_MACRO #(.BRAM_SIZE("18Kb"),.DOA_REG(1),.WRITE_WIDTH_A(12),.READ_WIDTH_A(12),
													.DOB_REG(1),.WRITE_WIDTH_B(12),.READ_WIDTH_B(12))
			u_dac_bram_R1(.CLKA(clk_i),
							  .ENA(bram_en_R1),.WEA(bram_bwe_R1),.REGCEA(bram_regce_R1),
							  .ADDRA(bram_address_R1),.DIA(bram_data_R1),.DOA(bram_dat_out_R1),
							  .CLKB(clk_i),
							  .ENB(loader_rd),.WEB(2'b00),.REGCEB(1'b1),
							  .ADDRB({{4{1'b0}},loader_addr}),.DOB(loader_dat_out_R1),
							  .RSTA(1'b0),.RSTB(1'b0));
	RITC_Dual_DAC_Loader u_loader(.clk_i(clk_i),.load_i(do_load || servo_load),.busy_o(loader_busy),.addr_o(loader_addr),
											.rd_o(loader_rd),.r0_dac_i(scramble(loader_dat_out_R0)),.r1_dac_i(scramble(loader_dat_out_R1)),
											.DAC_DIN(DAC_DIN),.DAC_CLOCK(DAC_CLOCK),.DAC_LATCH(DAC_LATCH));
	
	assign user_bram_dat_out = (addr_in[6]) ? bram_dat_out_R1 : bram_dat_out_R0;
	assign user_data_dac[0 +: 12] = user_bram_dat_out;
	assign user_data_dac[12 +: 6] = addr_in;
	assign user_data_dac[18 +: 14] = {14{1'b0}};
	assign user_data_ctrl[0] = do_load;
	assign user_data_ctrl[1] = loader_busy;
	assign user_data_ctrl[31:2] = {30{1'b0}};
	
	assign user_dat_o = (user_addr_i) ? user_data_ctrl : user_data_dac;
	
	assign debug_o[0 +: 12] = loader_dat_out_R0;
	assign debug_o[12 +: 12] = loader_dat_out_R1;
	assign debug_o[24 +: 6] = loader_addr;
	assign debug_o[30 +: 12] = (servo_wr_i) ? servo_i : dat_in;
	assign debug_o[42] = servo_wr_i;
	assign debug_o[43] = servo_addr_i;

	assign debug_o[44] = do_load;
	assign debug_o[45] = servo_load;
	assign debug_o[47:46] = DAC_DIN;
	assign debug_o[49:48] = DAC_CLOCK;
	assign debug_o[51:50] = DAC_LATCH;
	assign debug_o[52] = loader_busy;
	assign debug_o[53] = loader_rd;
	assign debug_o[55:54] = DAC_DOUT;
	assign debug_o[56 +: 7] = addr_in;
	assign debug_o[63] = bram_wr_R0;
	assign debug_o[64] = bram_wr_R1;
endmodule

module RITC_Dual_DAC_Loader( input clk_i,
									  input load_i,
									  output busy_o,

									  output [5:0] addr_o,
									  output rd_o,
									  input [11:0] r0_dac_i,
									  input [11:0] r1_dac_i,
									  output [1:0] DAC_DIN,
									  output [1:0] DAC_CLOCK,
									  output [1:0] DAC_LATCH
									  );
	localparam RITC_DACS = 33;
	localparam RITC_DAC_BITS = 12;
	reg [5:0] addr_reg = {6{1'b0}};
	reg [3:0] bit_counter = {4{1'b0}};

	reg [10:0] shift_register_R0 = {11{1'b0}};
	reg [10:0] shift_register_R1 = {11{1'b0}};
	
	(* IOB = "TRUE" *)
	reg dac_din_R0 = 0;
	(* IOB = "TRUE" *)
	reg dac_din_R1 = 0;
	(* IOB = "TRUE" *)
	reg dac_latch_R0 = 0;
	(* IOB = "TRUE" *)
	reg dac_latch_R1 = 0;
	(* IOB = "TRUE" *)
	reg dac_clock_R0 = 0;
	(* IOB = "TRUE" *)
	reg dac_clock_R1 = 0;

	reg do_read = 0;
	
	wire do_shift;
	wire do_load;
	wire do_done;
	
	localparam FSM_BITS = 3;
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] START_WAIT_1 = 1;
	localparam [FSM_BITS-1:0] START_WAIT_2 = 2;
	localparam [FSM_BITS-1:0] START_WAIT_3 = 3;
	localparam [FSM_BITS-1:0] LOAD = 4;
	localparam [FSM_BITS-1:0] CLOCK_LOW = 5;
	localparam [FSM_BITS-1:0] CLOCK_HIGH = 6;
	localparam [FSM_BITS-1:0] DONE = 7;
	reg [FSM_BITS-1:0] state = IDLE;

	always @(posedge clk_i) begin
		if (do_shift) begin
			dac_din_R0 <= shift_register_R0[1];
			shift_register_R0 <= {1'b0,shift_register_R0[10:1]};
		end else if (do_load) begin
			dac_din_R0 <= r0_dac_i[0];
			shift_register_R0 <= r0_dac_i[11:1];
		end
	
		if (do_shift) begin
			dac_din_R1 <= shift_register_R1[1];
			shift_register_R1 <= {1'b0,shift_register_R1[10:1]};
		end else if (do_load) begin
			dac_din_R1 <= r1_dac_i[0];
			shift_register_R1 <= r1_dac_i[11:1];
		end	

		// Need to skip over address for servo control if servo control is enabled.
		if (state == IDLE) addr_reg <= {6{1'b0}};
		else if (do_load) addr_reg <= addr_reg + 1;
		if (state == CLOCK_HIGH) bit_counter <= bit_counter + 1;
		else if (state == LOAD) bit_counter <= {4{1'b0}};

		case (state)
			IDLE: if (load_i) state <= START_WAIT_1;
			START_WAIT_1: state <= START_WAIT_2;
			START_WAIT_2: state <= START_WAIT_3;
			START_WAIT_3: state <= LOAD;
			LOAD: if (addr_reg == RITC_DACS) state <= DONE;
					else state <= CLOCK_LOW;
			CLOCK_LOW: if (bit_counter == RITC_DAC_BITS) state <= LOAD;
						  else state <= CLOCK_HIGH;
			CLOCK_HIGH: state <= CLOCK_LOW;
			DONE: state <= IDLE;
		endcase
		
		dac_latch_R0 <= (state == DONE);
		dac_latch_R1 <= (state == DONE);
	
		dac_clock_R0 <= (state == CLOCK_LOW && (bit_counter != RITC_DAC_BITS));
		dac_clock_R1 <= (state == CLOCK_LOW && (bit_counter != RITC_DAC_BITS));

		do_read <= (state == START_WAIT_1) || (do_load);
	end

	assign do_shift = (state == CLOCK_HIGH);
	assign do_load = (state == LOAD);
	
	assign DAC_LATCH[0] = dac_latch_R0;
	assign DAC_LATCH[1] = dac_latch_R1;
	assign DAC_DIN[0] = dac_din_R0;
	assign DAC_DIN[1] = dac_din_R1;
	assign DAC_CLOCK[0] = dac_clock_R0;
	assign DAC_CLOCK[1] = dac_clock_R1;
	
	assign addr_o = addr_reg;
	assign rd_o = do_read;
	assign busy_o = !((state == IDLE) || (state == DONE));
endmodule
