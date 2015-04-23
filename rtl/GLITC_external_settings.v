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

/** \brief External settings module for GLITC.
 *
 * This module handles setting and updating GLITC settings for external
 * devices - that is, Vped and the attenuators.
 *
 * The actual updating is handled via a PicoBlaze and an OpenCores I2C module.
 */
module GLITC_external_settings(
		input user_clk_i,
		input user_sel_i,
		input user_wr_i,
		input user_rd_i,
		input [3:0]  user_addr_i,
		input [31:0]  user_dat_i,
		output [31:0] user_dat_o,
		
		output [70:0] debug_o,
		
		input scl_i,
		output scl_o,
		output scl_oen_o,
		input sda_i,
		output sda_o,
		output sda_oen_o
    );

	// We have 16 32-bit registers. Fundamentally we have 14 things we need to set.
	// Therefore we have...
	//
	// Register 0x00 : Vped A
	// Register 0x01 : Vped B
	// Register 0x02 : Vped C
	// Register 0x03 : spare 0
	// Register 0x04 : Vped D
	// Register 0x05 : Vped E
	// Register 0x06 : Vped F
	// Register 0x07 : spare 1
	// Register 0x08 : Atten. A
	// Register 0x09 : Atten. B
	// Register 0x0A : Atten. C
	// Register 0x0B : Atten. D
	// Register 0x0C : Atten. E
	// Register 0x0D : Atten. F
	// Register 0x0E : PicoBlaze Status/Control
	// Register 0x0F : PicoBlaze Programming Control
	//% DAC settings hold registers.
	reg [11:0] dac_settings[7:0];
	integer dac_i;
	initial for (dac_i=0;dac_i<8;dac_i=dac_i+1) dac_settings[dac_i] <= {12{1'b0}};
	//% Indicates this should be written to EEPROM.
	reg [7:0]  dac_eeprom_write = {8{1'b0}};

	//% Attenuator settings.
	reg [5:0] atten_settings[5:0];
	integer att_i;
	initial for (att_i=0;att_i<6;att_i=att_i+1) atten_settings[att_i] <= {6{1'b0}};

	//% Register indicating that an update is pending for this DAC setting.
	reg [7:0] dac_update_pending = {8{1'b0}};
	//% Register indicating that an update is pending for this attenuator setting.
	reg [5:0] atten_update_pending = {6{1'b0}};
	//% Register indicating that an update is pending for *anything*.
	reg update_any_pending = 0;

	// The DAC settings can optionally be written with the high bit set (bit 31),
	// indicating that this value should be written into the EEPROM of the DAC.
	
	// Register 0x0E: PicoBlaze Status/Control
	// Bit 0-7: (read)  Error Message. This is a FIFO output.
	// Bit 8  : (read)  Errors Pending
	//        : (write) 1 to clear current error.
	// Bit 16 : (read)  Initialized OK.
	//        : (write) 1 to force reinitialization (reset).
	// Bit 30 : (r/w)	  Pause all updates if set.
	// Bit 31 : (read)  Updates are pending.

	//% PicoBlaze latest error message.
	reg [7:0]	pb_error_message = {8{1'b0}};
	//% PicoBlaze error pending.
	reg 			pb_error_pending = 0;
	//% PicoBlaze initialization complete.
	reg			pb_initialized = 0;
	//% Pause all I2C updates.
	reg			pb_pause_updates = 0;
	//% Updates are pending.
	reg			pb_updates_pending = 0;
		
	//% PicoBlaze status/control register.
	wire [31:0] pb_status_control;
	assign pb_status_control[7:0] = pb_error_message;
	assign pb_status_control[8] = pb_error_pending;
	assign pb_status_control[15:9] = {7{1'b0}};
	assign pb_status_control[16] = pb_initialized;
	assign pb_status_control[29:17] = {13{1'b0}};
	assign pb_status_control[30] = pb_pause_updates;
	assign pb_status_control[31] = pb_updates_pending;
	
	//% BRAM register.
	wire [31:0] pb_bram_data;

	//% User-space outbound data.
	wire [31:0] user_data_out[15:0];
	assign user_dat_o = user_data_out[user_addr_i];

	///// REGISTER MAP
	assign user_data_out[00] = {dac_eeprom_write[0],{3{1'b0}},dac_settings[0]};
	assign user_data_out[01] = {dac_eeprom_write[1],{3{1'b0}},dac_settings[1]};
	assign user_data_out[02] = {dac_eeprom_write[2],{3{1'b0}},dac_settings[2]};
	assign user_data_out[03] = {dac_eeprom_write[3],{3{1'b0}},dac_settings[3]};
	assign user_data_out[04] = {dac_eeprom_write[4],{3{1'b0}},dac_settings[4]};
	assign user_data_out[05] = {dac_eeprom_write[5],{3{1'b0}},dac_settings[5]};
	assign user_data_out[06] = {dac_eeprom_write[6],{3{1'b0}},dac_settings[6]};
	assign user_data_out[07] = {dac_eeprom_write[7],{3{1'b0}},dac_settings[7]};
	assign user_data_out[08] = {{11{1'b0}},atten_settings[0]};
	assign user_data_out[09] = {{11{1'b0}},atten_settings[1]};
	assign user_data_out[10] = {{11{1'b0}},atten_settings[2]};
	assign user_data_out[11] = {{11{1'b0}},atten_settings[3]};
	assign user_data_out[12] = {{11{1'b0}},atten_settings[4]};
	assign user_data_out[13] = {{11{1'b0}},atten_settings[5]};
	assign user_data_out[14] = pb_status_control;
	assign user_data_out[15] = pb_bram_data;
	
	// PicoBlaze bus.

	//% PicoBlaze instruction bus.
	wire [17:0] pbInstruction;
	//% PicoBlaze address bus.
	wire [11:0] pbAddress;
	//% PicoBlaze ROM (well, ROM from PicoBlaze at least) read enable.
	wire pbRomEnable;
	//% PicoBlaze port specifier.
	wire [7:0] pb_port;
	//% PicoBlaze output port data.
	wire [7:0] pb_outport;
	//% PicoBlaze input port data.
	wire [7:0] pb_inport;
	//% PicoBlaze write flag.
	wire pb_write;
	//% PicoBlaze read flag.
	wire pb_read;
	
	//% I2C WISHBONE cyc.
	wire i2c_cyc = (pb_write || pb_read) && pb_port[7];
	//% I2C WISHBONE stb.
	wire i2c_stb = i2c_cyc;
	//% I2C WISHBONE write enable.
	wire i2c_we = pb_write;
	//% I2C WISHBONE address.
	wire [2:0] i2c_adr = pb_port[2:0];
	//% I2C WISHBONE data input.
	wire [7:0] i2c_dat_i = pb_outport;
	//% I2C WISHBONE data output.
	wire [7:0] i2c_dat_o;
	
	//% Holds PicoBlaze in reset.
	reg processor_reset = 0;
	//% Enables writes to BRAM.
	reg bram_we_enable = 0;
	//% Address register for BRAM.
	reg [9:0] bram_address_reg = {10{1'b0}};
	//% Data register for BRAM.
	reg [17:0] bram_data_reg = {18{1'b0}};
	//% Write flag to BRAM.
	reg bram_we = 0;
	//% Readback data from BRAM.
	wire [17:0] bram_readback;
	//% Outbound data to userside.
	assign pb_bram_data = {processor_reset,bram_we_enable,{2{1'b0}},bram_address_reg,bram_readback};
	
	// PicoBlaze registers.
	// 0x00: [0] = update pending [1] = error pending [2] = init done [3] = pause updates
	// 0x01: DAC update pending
	// 0x02: Atten update pending
	// 0x03: error register output
	// 0x10-0x1F: DAC settings (low/high)
	// 0x20-0x25: Atten settings
	// 0x80-0xFF: WISHBONE space.
	
	// Mass muxing.
	//% DACs are selected.
	wire pb_sel_dac = (pb_port[5:4] == 2'b01) && (!pb_port[7]);
	//% Attenuators are selected.
	wire pb_sel_att = (pb_port[5:4] == 2'b10) && (!pb_port[7]);
	//% Control registers are selected.
	wire pb_sel_ctl = (pb_port[5:4] == 2'b00) && (!pb_port[7]);

	//// DAC multiplexing.
	wire [15:0] pb_dac_mux = user_data_out[pb_port[3:1]];
	wire [7:0] pb_dac_mux_byte = (pb_port[0]) ? pb_dac_mux[15:8] : pb_dac_mux[7:0];
	//// Attenuator multiplexing.
	wire [5:0] pb_atten_settings[7:0];
	//// Reverse the first 3 attenuator inputs into the PicoBlaze.
	bit_reverser #(.WIDTH(6)) u_reverse_atten_0(atten_settings[0], pb_atten_settings[0]);
	bit_reverser #(.WIDTH(6)) u_reverse_atten_1(atten_settings[1], pb_atten_settings[1]);
	bit_reverser #(.WIDTH(6)) u_reverse_atten_2(atten_settings[2], pb_atten_settings[2]);
	assign pb_atten_settings[3] = atten_settings[3];
	assign pb_atten_settings[4] = atten_settings[4];
	assign pb_atten_settings[5] = atten_settings[5];
	assign pb_atten_settings[6] = pb_atten_settings[2];
	assign pb_atten_settings[7] = pb_atten_settings[3];
	wire [7:0] pb_atten_mux_byte = {{2{1'b0}},pb_atten_settings[pb_port[2:0]]};
	//// Control multiplexing.
	wire [7:0] pb_ctl_bytes[3:0];
	assign pb_ctl_bytes[0] = {{4{1'b0}},pb_pause_updates,pb_initialized,pb_error_pending,pb_updates_pending};
	assign pb_ctl_bytes[1] = dac_update_pending;
	assign pb_ctl_bytes[2] = atten_update_pending;
	assign pb_ctl_bytes[3] = dac_update_pending;
	wire [7:0] pb_ctl_mux_byte = pb_ctl_bytes[pb_port[1:0]];
	//// Mux control, dac, attenuator.
	wire [7:0] pb_local_mux[3:0];
	assign pb_local_mux[0] = pb_ctl_mux_byte;
	assign pb_local_mux[1] = pb_dac_mux_byte;
	assign pb_local_mux[2] = pb_atten_mux_byte;
	assign pb_local_mux[3] = pb_dac_mux_byte;
	wire [7:0] pb_local_mux_byte = pb_local_mux[pb_port[5:4]];
	//// Mux WISHBONE and local.
	assign pb_inport = (pb_port[7]) ? i2c_dat_o : pb_local_mux_byte;
	
	always @(posedge user_clk_i) begin
		if (user_sel_i && user_wr_i) begin
			if (!user_addr_i[3]) begin
				dac_settings[user_addr_i[2:0]] <= user_dat_i[11:0];
				dac_eeprom_write[user_addr_i[2:0]] <= user_dat_i[15];
			end
			if (user_addr_i == 4'h8) atten_settings[0] <= user_dat_i[5:0];
			if (user_addr_i == 4'h9) atten_settings[1] <= user_dat_i[5:0];
			if (user_addr_i == 4'hA) atten_settings[2] <= user_dat_i[5:0];
			if (user_addr_i == 4'hB) atten_settings[3] <= user_dat_i[5:0];
			if (user_addr_i == 4'hC) atten_settings[4] <= user_dat_i[5:0];
			if (user_addr_i == 4'hD) atten_settings[5] <= user_dat_i[5:0];
		end
		if (user_sel_i && user_wr_i && !user_addr_i[3]) dac_update_pending[user_addr_i[2:0]] <= 1;
		else if (pb_write && pb_sel_ctl && pb_port[1:0] == 2'b01) dac_update_pending <= dac_update_pending ^ pb_outport;
		if (user_sel_i && user_wr_i) begin
			if (user_addr_i == 4'h8) atten_update_pending[0] <= 1;
			if (user_addr_i == 4'h9) atten_update_pending[1] <= 1;
			if (user_addr_i == 4'hA) atten_update_pending[2] <= 1;
			if (user_addr_i == 4'hB) atten_update_pending[3] <= 1;
			if (user_addr_i == 4'hC) atten_update_pending[4] <= 1;
			if (user_addr_i == 4'hD) atten_update_pending[5] <= 1;
		end else begin
			if (pb_write && pb_sel_ctl && pb_port[1:0] == 2'b10) atten_update_pending <= atten_update_pending ^ pb_outport[5:0];
		end
		// PicoBlaze control register:
		// READ: bit0: updates are pending
		//       bit1: if 0 and internal initialization set, reinitialize
		//       bit2: if 0 and internal error buffer has errors, ready for next error
		// WRITE:
		//       bit1: if 1, set pb_initialized
		//       bit2: if 1, set pb_error_pending
		//       bit7: if 1, clear pb_initialized and pb_error_pending (at reset only)
		if (user_sel_i && user_wr_i && user_addr_i == 4'hE) begin
			if (user_dat_i[8]) pb_error_pending <= 0;
			if (user_dat_i[16]) pb_initialized <= 0;
			pb_pause_updates <= user_dat_i[30];
			if (user_dat_i[8]) pb_error_message <= {8{1'b0}};
		end else if (pb_write && pb_sel_ctl && pb_port[1:0] == 2'b00) begin
			if (pb_outport[1]) pb_error_pending <= 1;
			else if (pb_outport[7]) pb_error_pending <= 0;
			if (pb_outport[2]) pb_initialized <= 1;
			else if (pb_outport[7]) pb_initialized <= 0; 
		end else if (pb_write && pb_sel_ctl && pb_port[1:0] == 2'b11) begin
			pb_error_message <= pb_outport;
		end 
		if (user_sel_i && user_wr_i && user_addr_i == 4'hF) begin
			processor_reset <= user_dat_i[31];
			bram_we_enable <= user_dat_i[30];
			bram_data_reg <= user_dat_i[0 +: 18];
			bram_address_reg <= user_dat_i[18 +: 10];
		end
		if (user_sel_i && user_wr_i && user_addr_i == 4'hF) bram_we <= 1;
		else bram_we <= 0;
		
		pb_updates_pending <= (|dac_update_pending) | (|atten_update_pending); 
	end

	i2c_master_top #(.WB_LATENCY(0),.ARST_LVL(1'b1)) i2c(.wb_clk_i(user_clk_i),.wb_rst_i(1'b0),
							 .wb_adr_i(i2c_adr),.wb_cyc_i(i2c_cyc),.wb_stb_i(i2c_stb),
							 .wb_dat_i(i2c_dat_i),.wb_dat_o(i2c_dat_o),.wb_we_i(i2c_we),
							 .scl_pad_i(scl_i),.scl_pad_o(scl_o),.scl_padoen_o(scl_oen_o),
							 .sda_pad_i(sda_i),.sda_pad_o(sda_o),.sda_padoen_o(sda_oen_o));
							 
	kcpsm6 processor(.address(pbAddress),.instruction(pbInstruction),
														  .bram_enable(pbRomEnable),.in_port(pb_inport),
														  .out_port(pb_outport),.port_id(pb_port),
														  .write_strobe(pb_write),.read_strobe(pb_read),
														  .interrupt(1'b0), .sleep(1'b0),
														  .reset(processor_reset),.clk(user_clk_i));

	ritc_phase_scan_program_V3 rom(.address(pbAddress),.instruction(pbInstruction),
											 .enable(pbRomEnable),
											 .bram_we_i(bram_we && bram_we_enable),.bram_adr_i(bram_address_reg),
											 .bram_dat_i(bram_data_reg),.bram_dat_o(bram_readback),
											 .bram_rd_i(1'b1),.clk(user_clk_i));

	assign debug_o[0 +: 10] = pbAddress;
	assign debug_o[10 +: 8] = (pb_write) ? pb_outport : pb_inport;
	assign debug_o[18] = pb_write;
	assign debug_o[19] = pb_read;
	assign debug_o[20] = processor_reset;
	assign debug_o[21] = bram_we_enable;
	assign debug_o[22] = scl_i;
	assign debug_o[23] = sda_i;
	assign debug_o[24] = pb_updates_pending;
	assign debug_o[25] = pb_error_pending;
	assign debug_o[26] = pb_initialized;
	assign debug_o[27 +: 18] = pbInstruction;
	
endmodule
