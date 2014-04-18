`timescale 1ns / 1ps
module RITC_DAC_Simple_interface(
		input CLK,
		input user_sel_i,
		input [1:0] user_addr_i,
		input [7:0] user_dat_i,
		output [7:0] user_dat_o,
		input user_wr_i,
		input user_rd_i,
		
		output [15:0] value_o,
		output [7:0] addr_o,
		output update_o,
		output load_o,
		input updating_i		
    );

	// Sleaze the DAC loading.
	reg [15:0] dac_value_register = {16{1'b0}};
	reg [7:0] dac_addr_register = {8{1'b0}};
	reg update_ritc = 0;
	reg load_ritc = 0;
	
	reg [7:0] data_out;
	
	always @(posedge CLK) begin
		if (user_sel_i && user_addr_i == 2'd0 && user_wr_i) dac_value_register[7:0] <= user_dat_i;
		if (user_sel_i && user_addr_i == 2'd1 && user_wr_i) dac_value_register[15:8] <= user_dat_i;
		if (user_sel_i && user_addr_i == 2'd2 && user_wr_i) dac_addr_register <= user_dat_i;
		if (user_sel_i && user_addr_i == 2'd3 && user_wr_i) begin
			update_ritc <= user_dat_i[0];
			load_ritc <= user_dat_i[1];
		end else begin
			update_ritc <= 0;
			load_ritc <= 0;
		end
	end
	always @(*) begin
		case (user_addr_i)
			2'd0: data_out <= dac_value_register[7:0];
			2'd1: data_out <= dac_value_register[15:8];
			2'd2: data_out <= dac_addr_register;
			2'd3: data_out <= {{5{1'b0}},updating_i,{2{1'b0}}};
		endcase
	end
	
	assign value_o = dac_value_register;
	assign addr_o = dac_addr_register;
	assign update_o = update_ritc;
	assign load_o = load_ritc;
	assign user_dat_o = data_out;

endmodule
