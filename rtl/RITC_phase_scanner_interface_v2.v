`timescale 1ns / 1ps
module RITC_phase_scanner_interface_v2(
		input CLK,
		input user_sel_i,
		input [2:0] user_addr_i,
		input [7:0] user_dat_i,
		output [7:0] user_dat_o,
		input user_wr_i,
		input user_rd_i,

		output [7:0] select_o,
		output [7:0] cmd_o,
		output cmd_wr_o,
		output [15:0] argument_o,
		output argument_wr_o,
		input [15:0] result_i,
		input result_valid_i,
		input [15:0] servo_i,
		input servo_update_i,
		output [2:0] debug_o
    );

	reg [7:0] select = {8{1'b0}};
	reg [7:0] cmd = {8{1'b0}};
	reg cmd_wr = 0;
	reg [15:0] argument = {16{1'b0}};
	reg argument_wr = 0;
	reg [15:0] result = {16{1'b0}};
	reg [15:0] servo = {16{1'b0}};
	
	always @(posedge CLK) begin
		if (result_valid_i) begin
			result <= result_i;
		end
		if (servo_update_i) begin
			servo <= servo_i;
		end
	end
	
	always @(posedge CLK) begin
		if (user_sel_i && user_wr_i) begin
			if (user_addr_i == 3'd0) begin 
				cmd <= user_dat_i;
				cmd_wr <= 1;
			end
			if (user_addr_i == 3'd1) begin
				select <= user_dat_i;
			end
			if (user_addr_i == 3'd2) begin
				argument[7:0] <= user_dat_i;
			end
			if (user_addr_i == 3'd3) begin
				argument[15:8] <= user_dat_i;
				argument_wr <= 1;
			end
		end else begin
			cmd_wr <= 0;
			argument_wr <= 0;
		end
	end	
	reg [7:0] data_out;
	always @(*) begin
		case (user_addr_i)
			3'd0: data_out <= cmd;
			3'd1: data_out <= select;
			3'd2: data_out <= argument[7:0];
			3'd3: data_out <= argument[15:8];
			3'd4: data_out <= result[7:0];
			3'd5: data_out <= result[15:8];
			3'd6: data_out <= servo[7:0];
			3'd7: data_out <= servo[15:8];
		endcase
	end
	
	assign cmd_o = cmd;
	assign cmd_wr_o = cmd_wr;
	assign argument_o = argument;
	assign argument_wr_o = argument_wr;
	assign select_o = select;
	assign user_dat_o = data_out;
	
endmodule
