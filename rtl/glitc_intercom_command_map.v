`timescale 1ns / 1ps
module glitc_intercom_command_map(
		input sync_i,
		input ping_i,
		input pong_i,
		input train_i,
		output reg [5:0] cmd_o
    );

	always @(sync_i or ping_i or pong_i or train_i) begin
		//								5-bit cmd    Top 2 bytes
		if (sync_i) 		cmd_o <= 5'h04; // 0x27
		else if (ping_i) 	cmd_o <= 5'h00; // 0x07
		else if (pong_i)  cmd_o <= 5'h02; // 0x17
		else if (train_i) cmd_o <= 5'h16; // 0xB7
		else 					cmd_o <= 5'h13; // 0x9F
	end
endmodule
