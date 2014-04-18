module squarer_mod2_hdl(
		input [4:0] a,
		output [6:0] spo
);

  // reg [5:0] output_reg; // LM: error! output reg requires 7 bits
 reg [6:0] output_reg; 
	always @(a) begin
		case (a)
			5'd0:	output_reg <=  7'b0000010;
			5'd1: output_reg <=  7'b0000110;
			5'd2: output_reg <=  7'b0001100;
			5'd3: output_reg <=  7'b0010100;
			5'd4: output_reg <=  7'b0011110;
			5'd5: output_reg <=  7'b0101010;
			5'd6: output_reg <=  7'b0111000;
			5'd7: output_reg <=  7'b1001000;
			5'd8: output_reg <=  7'b1011010;
			5'd9: output_reg <=  7'b1101110;
			5'd10: output_reg <= 7'b1111111;
			5'd11: output_reg <= 7'b1111111;
			5'd12: output_reg <= 7'b1111111;
			5'd13: output_reg <= 7'b1111111;
			5'd14: output_reg <= 7'b1111111;
			5'd15: output_reg <= 7'b1111111;
			5'd16: output_reg <= 7'b1111111;
			5'd17: output_reg <= 7'b1111111;
			5'd18: output_reg <= 7'b1111111;
			5'd19: output_reg <= 7'b1111111;
			5'd20: output_reg <= 7'b1101110;
			5'd21: output_reg <= 7'b1011010;
			5'd22: output_reg <= 7'b1001000;
			5'd23: output_reg <= 7'b0111000;
			5'd24: output_reg <= 7'b0101010;
			5'd25: output_reg <= 7'b0011110;
			5'd26: output_reg <= 7'b0010100;
			5'd27: output_reg <= 7'b0001100;
			5'd28: output_reg <= 7'b0000110;
			5'd29: output_reg <= 7'b0000010;
			5'd30: output_reg <= 7'b0000000;
			5'd31: output_reg <= 7'b0000000;
		endcase
	end
	assign spo = output_reg;
endmodule