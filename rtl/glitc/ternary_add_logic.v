`timescale 1ns / 1ps
module ternary_add_logic(
		input [2:0] A,
		input [2:0] B,
		input [2:0] C,
		output [4:0] D,
		input CLK
    );

	wire [2:0] bit0 = {A[0],B[0],C[0]};
	wire [2:0] bit1 = {A[1],B[1],C[1]};
	wire [2:0] bit2 = {A[2],B[2],C[2]};
	wire bit0_any2, bit0_sum;
	wire bit1_any2, bit1_sum;
	wire bit2_any2, bit2_sum;
	wire bit3_sum;
	wire bit4_sum;
	wire [3:0] CO;
		
	// O5 is BIT0_ANY2, O6 is BIT0_SUM
	(* HBLKNM = "TERNARY" *)
	(* BEL = "A6LUT" *)
	LUT6_2 #(.INIT(64'h96969696e8e8e8e8)) u_bit0(.I0(bit0[0]),.I1(bit0[1]),.I2(bit0[2]),.I5(1'b1),
																.O6(bit0_sum),.O5(bit0_any2));
	(* HBLKNM = "TERNARY" *)
	(* BEL = "B6LUT" *)
	LUT6_2 #(.INIT(64'h69966996e8e8e8e8)) u_bit1(.I0(bit1[0]),.I1(bit1[1]),.I2(bit1[2]),.I3(bit0_any2),.I5(1'b1),
																.O6(bit1_sum),.O5(bit1_any2));
	(* HBLKNM = "TERNARY" *)
	(* BEL = "C6LUT" *)
	LUT6_2 #(.INIT(64'h69966996e8e8e8e8)) u_bit2(.I0(bit2[0]),.I1(bit2[1]),.I2(bit2[2]),.I3(bit1_any2),.I5(1'b1),
																.O6(bit2_sum),.O5(bit2_any2));
	(* HBLKNM = "TERNARY" *)
	(* BEL = "D6LUT" *)
	LUT6_2 #(.INIT(64'h7E7E7E7E80FE80FE))
	u_bit3(.I0(bit2[0]),.I1(bit2[1]),.I2(bit2[2]),.I3(CO[2]),.I5(1'b1),
																.O6(bit3_sum),.O5(bit4_sum));

	wire [3:0] DI = {bit4_sum, bit1_any2, bit0_any2, 1'b0};
	wire CI = 0;
	wire [3:0] S = {bit3_sum, bit2_sum, bit1_sum, bit0_sum};
	wire [3:0] O;
	wire CYINIT = 1;
	(* HBLKNM = "TERNARY" *)
	CARRY4 u_carry4(.DI(DI),.CO(CO),.CI(CI),.S(S),.O(O),.CYINIT(CYINIT));
	
	(* HBLKNM = "TERNARY" *)
	(* BEL = "AFF" *)
	FD u_dbit0(.D(O[0]),.C(CLK),.Q(D[0]));
	(* HBLKNM = "TERNARY" *)
	(* BEL = "BFF" *)
	FD u_dbit1(.D(O[1]),.C(CLK),.Q(D[1]));
	(* HBLKNM = "TERNARY" *)
	(* BEL = "CFF" *)
	FD u_dbit2(.D(O[2]),.C(CLK),.Q(D[2]));
	(* BEL = "DFF" *)
	(* HBLKNM = "TERNARY" *)
	FD u_dbit3(.D(O[3]),.C(CLK),.Q(D[3]));
	(* BEL = "D5FF" *)
	(* HBLKNM = "TERNARY" *)
	FD u_dbit4(.D(bit4_sum),.C(CLK),.Q(D[4]));

endmodule
