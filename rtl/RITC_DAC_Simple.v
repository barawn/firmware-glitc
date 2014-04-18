`timescale 1ns / 1ps
module RITC_DAC_Simple(
		input CLK,
		input user_sel_i,
		input [1:0] user_addr_i,
		input [7:0] user_dat_i,
		output [7:0] user_dat_o,
		input user_wr_i,
		input user_rd_i,
		output DAC_DIN,
		input DAC_DOUT,
		output DAC_CLOCK,
		output DAC_LATCH,
		input VDD_INCR,
		input VDD_DECR,
		output [11:0] VDD
    );

	parameter CLOCK_DELAY = 5;
	localparam RITC_DAC_BITS = 12;
	localparam RITC_DACS = 33;
	localparam RITC_NUM_BITS = RITC_DACS * RITC_DAC_BITS;

	wire [15:0] VALUE;
	wire [7:0] ADDR;
	wire UPDATE;
	wire LOAD;
	wire UPDATING;
	
	RITC_DAC_Simple_interface u_ritc_dac_if(.CLK(CLK),
														 .user_sel_i(user_sel_i),
														 .user_addr_i(user_addr_i),
														 .user_dat_i(user_dat_i),
														 .user_dat_o(user_dat_o),
														 .user_wr_i(user_wr_i),
														 .user_rd_i(user_rd_i),
														 
														 .value_o(VALUE),
														 .addr_o(ADDR),
														 .update_o(UPDATE),
														 .load_o(LOAD),
														 .updating_i(UPDATING));
	function [11:0] scramble;
		input [11:0] val;
		begin
			scramble = {val[0],val[1],val[2],val[3],val[4],val[5],val[6],val[7],val[8],val[9],val[10],val[11]};
		end
	endfunction
	/*
	wire [11:0] val_in = {VALUE[0],VALUE[1],VALUE[2],VALUE[3],VALUE[4],VALUE[5],
								 VALUE[6],VALUE[7],VALUE[8],VALUE[9],VALUE[10],VALUE[11]};
	*/
	wire [11:0] val_in = scramble(VALUE);
	
	reg [RITC_NUM_BITS - 1:0] ritc_register = {RITC_NUM_BITS{1'b0}};
	reg [RITC_NUM_BITS - 1:0] ritc_shift_register = {RITC_NUM_BITS{1'b0}};
	integer rj;

	
	reg [7:0] addr_registered = {8{1'b0}};
	reg update_registered = 0;
	reg [11:0] val_in_registered = {12{1'b0}};
	reg [11:0] value_registered = {12{1'b0}};
	reg [11:0] value_registered_2 = {12{1'b0}};
	always @(posedge CLK) begin
		value_registered <= VALUE;
		value_registered_2 <= value_registered;
	end
	wire [RITC_DAC_BITS-1:0] vdd_val = ritc_register[RITC_DAC_BITS*31 +: RITC_DAC_BITS];
	assign VDD = vdd_val;
	reg [11:0] vdd_val_reg = {12{1'b0}};
	reg vdd_val_reg_load = 0;
	always @(posedge CLK) begin
		vdd_val_reg_load <= (update_registered && addr_registered == 31);
		if (vdd_val_reg_load) vdd_val_reg <= value_registered_2;
		else if (VDD_INCR) vdd_val_reg <= vdd_val_reg + 1;
		else if (VDD_DECR) vdd_val_reg <= vdd_val_reg - 1;
	end		
	reg update_from_servo = 0;
	reg load_from_servo = 0;
	always @(posedge CLK) begin
		update_from_servo <= (VDD_INCR || VDD_DECR);
		load_from_servo <= update_from_servo;
	end



	always @(posedge CLK) begin
		addr_registered <= ADDR;
		update_registered <= UPDATE;
		val_in_registered <= val_in;
		for (rj=0;rj<33;rj=rj+1) begin
			if (rj == 31) begin
				if (update_registered && addr_registered == rj) begin
					ritc_register[RITC_DAC_BITS*rj +: RITC_DAC_BITS] <= val_in_registered;
				end else if (update_from_servo) begin
					ritc_register[RITC_DAC_BITS*rj +: RITC_DAC_BITS] <= scramble(vdd_val_reg);
				end
			end else begin
				if (update_registered && addr_registered == rj) 
					ritc_register[RITC_DAC_BITS*rj +: RITC_DAC_BITS] <= val_in_registered;
			end
		end
	end
	localparam FSM_BITS = 2;
	localparam [FSM_BITS-1:0] IDLE = 0;
	localparam [FSM_BITS-1:0] CLOCK_LOW = 1;
	localparam [FSM_BITS-1:0] CLOCK_HIGH = 2;
	localparam [FSM_BITS-1:0] DONE = 3;
	reg [FSM_BITS-1:0] state = IDLE;
	
	reg [7:0] clock_counter = {8{1'b0}};
	reg [8:0] bit_counter = {9{1'b0}};
	
	wire CE = (state == IDLE) || (clock_counter == CLOCK_DELAY);
	reg do_shift = 0;
	always @(posedge CLK) begin
		if (CE) begin
			case (state)
				IDLE: if (LOAD || load_from_servo) state <= CLOCK_LOW;
				CLOCK_LOW: if (bit_counter == RITC_NUM_BITS) state <= DONE; else state <= CLOCK_HIGH;
				CLOCK_HIGH: state <= CLOCK_LOW;
				DONE: state <= IDLE;
			endcase
			if (state == CLOCK_HIGH) bit_counter <= bit_counter + 1;
			else if (state == IDLE) bit_counter <= {9{1'b0}};
		end
		do_shift <= (state == CLOCK_HIGH && CE);
		if (clock_counter == CLOCK_DELAY || state == IDLE) clock_counter <= {8{1'b0}};
		else clock_counter <= clock_counter + 1;
	
		if ((LOAD || load_from_servo) && (state == IDLE)) ritc_shift_register <= ritc_register;
		else if (do_shift) ritc_shift_register <= {1'b0,ritc_shift_register[RITC_NUM_BITS-1:1]};
	end
	(* IOB = "TRUE" *)
	reg DAC_DIN_reg = 0;
	(* IOB = "TRUE" *)
	reg DAC_CLOCK_reg = 0;
	(* IOB = "TRUE" *)
	reg DAC_LATCH_reg = 0;
	always @(posedge CLK) begin
		DAC_DIN_reg <= ritc_shift_register[0];
		DAC_CLOCK_reg <= (state == CLOCK_HIGH);
		DAC_LATCH_reg <= (state == DONE);
	end
	assign DAC_DIN = DAC_DIN_reg;
	assign DAC_CLOCK = DAC_CLOCK_reg;
	assign DAC_LATCH = DAC_LATCH_reg;
	assign UPDATING = (state != IDLE);
endmodule
