`timescale 1ns / 1ps
module RITC_IDELAY_interface(
		input CLK,
		input user_sel_i,
		input user_addr_i,
		input [7:0] user_dat_i,
		output [7:0] user_dat_o,
		input user_wr_i,
		input user_rd_i,
		
		output [4:0] delay_o,
		output [5:0] addr_o,
		output load_o,
		input [2:0] ready_i
	);
	
	reg [4:0] delay_register = {5{1'b0}};
	reg [5:0] addr_register = {6{1'b0}};
	reg load_register = 0;
	always @(posedge CLK) begin
		if (user_wr_i && user_sel_i) begin
			if (!user_addr_i) delay_register <= user_dat_i[4:0];
			if (user_addr_i) begin
				addr_register <= user_dat_i[5:0];
				load_register <= user_dat_i[6];
			end
		end
	end

	reg [7:0] data_out;
	always @(*) begin
		case (user_addr_i)
			1'b0: data_out <= {ready_i, delay_register};
			1'b1: data_out <= {{2{1'b0}},addr_register};
		endcase
	end

	assign load_o = load_register;
	assign addr_o = addr_register;
	assign delay_o = delay_register;
	assign user_dat_o = data_out;
endmodule
