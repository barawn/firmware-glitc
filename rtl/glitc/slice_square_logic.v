`timescale 1ns / 1ps
// Logic for doing a 'square' of a signed 5 bit number with
// range from -11 to 10. Only 6 output bits because the
// low bit is always 0. This isn't exactly a square because
// we add 0.5 before squaring, then drop the 0.25 in the
// final square.
//
// This is done explicitly to guarantee that map doesn't
// spread out logic like a moron. BECAUSE IT WILL.
module slice_square_logic(
		input [4:0] I,
		output [5:0] SQR,
		input CLK
    );
	 
/* 
                        5'd0: output_reg <=  7'b0000010; 0  0 
                        5'd1: output_reg <=  7'b0000110; 1  0
                        5'd2: output_reg <=  7'b0001100; 1  1
                        5'd3: output_reg <=  7'b0010100; 1 E0
                        5'd4: output_reg <=  7'b0011110; 1  1
                        5'd5: output_reg <=  7'b0101010; 0  1
                        5'd6: output_reg <=  7'b0111000; 0  1
                        5'd7: output_reg <=  7'b1001000; 0 11
                        5'd8: output_reg <=  7'b1011010; 0  1
                        5'd9: output_reg <=  7'b1101110; 1  1
                        5'd10: output_reg <= 7'b1111111; 1
                        5'd11: output_reg <= 7'b1111111; 1 E
                        5'd12: output_reg <= 7'b1111111; 1
                        5'd13: output_reg <= 7'b1111111; 0
                        5'd14: output_reg <= 7'b1111111; 0
                        5'd15: output_reg <= 7'b1111111; 0 1
                        5'd16: output_reg <= 7'b1111111; 0
                        5'd17: output_reg <= 7'b1111111; 1 
                        5'd18: output_reg <= 7'b1111111; 1
                        5'd19: output_reg <= 7'b1111111; 1 E
                        5'd20: output_reg <= 7'b1101110; 1  1
                        5'd21: output_reg <= 7'b1011010; 0  1
                        5'd22: output_reg <= 7'b1001000; 0  1
                        5'd23: output_reg <= 7'b0111000; 0 11
                        5'd24: output_reg <= 7'b0101010; 0  1
                        5'd25: output_reg <= 7'b0011110; 1  1
                        5'd26: output_reg <= 7'b0010100; 1  0
                        5'd27: output_reg <= 7'b0001100; 1 E1 B
                        5'd28: output_reg <= 7'b0000110; 1  0 
                        5'd29: output_reg <= 7'b0000010; 0  0
                        5'd30: output_reg <= 7'b0000000; 0  0
                        5'd31: output_reg <= 7'b0000000; 0 10 0
*/
	// Bit[0] = S[1] ^ S[0];
	// Bit[1] = S[2] ^ S[1]; (2&!1 + 1&!2)
	// Bit[2] = S[3] ^ ((21 + 20 + 10) =
	//        if bit1 is 1, that means we need 0
	//        if bit1 is 0, that means we need S[2] && S[1].
	// So the first three bits are:
	// A6LUT has inputs S[2:0]
	// B6LUT has inputs S[3:0]
	// C6LUT has inputs 
	// 
	// Bit[0] inputs are S[0], AX=S[1], CYINIT=AX, DI0 = AX (so AFF = S[1] ^ S[0])
	// Bit[1] input is S[2]
	// Bit[2] input is S[3:0].
	// Bit[3] input is S[4:0].
	// bit[

	// Bit 0 and 1 are generated via the carry chain (A6LUT/B6LUT).
	// Bits 2,3,4,5 are generated via lookup tables.
	
	// Bit 0 is S[1] ^ S[0]
	// Bit 1 is S[2] ^ S[1].
	wire [5:0] bit_lut;
	(* BEL = "A6LUT" *)
	(* HBLKNM = "SLICESQUARE" *)
	LUT1 #(.INIT(2'b10)) u_bit0(.I0(I[0]),.O(bit_lut[0]));
	(* BEL = "B6LUT" *)
	(* HBLKNM = "SLICESQUARE" *)
	LUT1 #(.INIT(2'b10)) u_bit1(.I0(I[2]),.O(bit_lut[1]));
	wire [3:0] DI = {1'b0,1'b0,1'b0,I[1]};
	wire [3:0] S = {bit_lut[3],bit_lut[2],bit_lut[1],bit_lut[0]};
	wire [3:0] O;
	wire [3:0] CO;
	wire CYINIT = I[1];
	(* HBLKNM = "SLICESQUARE" *)
	CARRY4 u_carry4(.DI(DI),.CO(CO),.CI(CI),.S(S),.O(O),.CYINIT(CYINIT));

	(* HBLKNM = "SLICESQUARE" *)
	(* BEL = "C6LUT" *)	                   
	LUT6_2 #(.INIT(64'h0D4FF2B017E817E8)) u_bit23(.I5(1'b1),.I4(I[4]),.I3(I[3]),.I2(I[2]),.I1(I[1]),.I0(I[0]),
																 .O5(bit_lut[2]),
																 .O6(bit_lut[3]));
	(* HBLKNM = "SLICESQUARE" *)
	(* BEL = "D6LUT" *)
	LUT6_2 #(.INIT(64'h00E3C7000325A4C0)) u_bit45(.I5(1'b1),.I4(I[4]),.I3(I[3]),.I2(I[2]),.I1(I[1]),.I0(I[0]),
																 .O5(bit_lut[4]),
																 .O6(bit_lut[5]));
	(* HBLKNM = "SLICESQUARE" *)
	FD u_obit0(.D(O[0]),.C(CLK),.Q(SQR[0]));
	(* HBLKNM = "SLICESQUARE" *)
	FD u_obit1(.D(O[1]),.C(CLK),.Q(SQR[1]));
	(* HBLKNM = "SLICESQUARE" *)
	FD u_obit2(.D(bit_lut[2]),.C(CLK),.Q(SQR[2]));
	(* HBLKNM = "SLICESQUARE" *)
	FD u_obit3(.D(bit_lut[3]),.C(CLK),.Q(SQR[3]));
	(* HBLKNM = "SLICESQUARE" *)
	FD u_obit4(.D(bit_lut[4]),.C(CLK),.Q(SQR[4]));
	(* HBLKNM = "SLICESQUARE" *)
	FD u_obit5(.D(bit_lut[5]),.C(CLK),.Q(SQR[5]));

endmodule
