`timescale 1ns / 1ps
//
// Computes pow(round((A+B+C+93)/4),2) in 3 slices.
//
// round((A+B+C+93)/4) takes 2 slices, but leaves a LUT2 available.
// pow(X,2) needs 1 slice and a LUT2. Works out perfect.
// There's some goofiness required because pow(X,2)'s LUT2 needs
// an XOR output, so the adder's last LUT is located in the
// squarer's slice, and one of the LUT6_2s for the squarer
// is located in the adder's slice.
//
// The apparently random offset (93) is the equivalent of forcing
// the inputs positive-definite (adding 3.875*sigma to each value).
// Since 1 sigma = 8 counts, this is adding 31 to each.
//
// Note that this means that one value never occurs (-4 sigma) which
// would map to -1 (0x3F). NEVER MAP AN INPUT TO 0x3F.
//
// The output of this has been checked and verified to be OK.

module six_bit_sum_power(
		input [5:0] A,
		input [5:0] B,
		input [5:0] C,
		output [6:0] O,
		output LSB,
		input CLK
    );

	// Carry chain (for adder).
	wire [3:0] Carry0_S;
	wire [3:0] Carry0_DI;
	wire [3:0] Carry0_CO;
	wire [3:0] Carry0_O;
	// Carry chain (for aux).
	wire [3:0] Carry1_S;
	wire [3:0] Carry1_DI;
	wire [3:0] Carry1_CO;
	wire [3:0] Carry1_O;
	// Carry chain (for squarer).
	wire [3:0] Carry2_S;
	wire [3:0] Carry2_DI;
	wire [3:0] Carry2_CO;
	wire [3:0] Carry2_O;
	
	// Ternary adder portion:
	// A ternary adder in a LUT6-device is done something like a carry-save
	// adder, however the final adder (combining carry + sum-no-carry) is
	// done all in one step. So each LUT6 generates
	// (x[n] ^ y[n] ^ z[n]) = s[n]
	// (x[n] & y[n]) || (z[n] &  (x[n] ^ y[n])) = c[n]
	// However, it also takes in c[n-1], so instead of putting out s[n],
	// it puts out (s[n] ^ c[n-1]), and the flop latches (s[n] ^ c[n-1] ^ carry[n-1]).
	//	The carry chain generates:
	// carry[n] = (s[n] & c[n-1]) || (!(s[n]] & c[n-]1) && carry[n-1])
	// 

	// The top 2 bits of the ternary adder are left as carry[4] (CarryOut) and
	// s[4] (Bit_Any2[4]), because those two can generate bits 4 and 5 with a half-adder
	// and leaving them that way saves a LUT which we use.
	// O[4] = (carry[4] ^ s[4])
	// O[5] = (carry[4] & s[4])
	//
	// This just changes how the inputs are used in the LUTs which use them, which is why
	// they're left that way. 
	
	// Carry output of the ternary adder up through bit 4.
	wire CarryOut;
	// Raw outputs of the adder (not xor'd with carry).
	wire [3:0] Bit_Raw;
	// Full adder 'carry' outputs.
	wire [4:0] Bit_Any2;
	// Carry input to ternary adder when Bit_Raw[0] = 0.
	wire CarryWhenZero;
	// Carry input to ternary adder when Bit_Raw[0] = 1.
	wire CarryWhenOne;
	// Muxed carry input to ternary adder.
	wire CarryIn;
	// '0' driven into S input of MUXCY to forcibly insert something into the carry chain.
	wire ForcedInsert;

	wire [3:0] Sum_Output_Reg;
	wire Carry_Output_Reg;
	wire Bit5_Any2_Output_Reg;

	// Squarer portion.
	
	// AND of low 2 bits.
	wire BothLowBits;
	// Unregistered outputs.
	wire [6:0] Raw_Squarer_Out;
	// Actual registered outputs.
	wire [6:0] Squarer_Output_Reg;
	// LSB output.
	wire Squarer_LSB_Reg;
	// Fake output to preserve C5FF.
	wire FakeClutOutput;
	// Fake output to possibly preserve B5FF.
	wire FakeBlutOutput;
	
	// Adder slice.
	(* HBLKNM = "TERNARY" *)
//	(* BEL = "A6LUT" *)
    (* DONT_TOUCH = "TRUE" *)
	LUT6_2 #(.INIT({{2{16'h6996}},{4{8'hE8}}})) 
		u_alut0(.I5(1'b1),.I4(1'b0),.I3(Bit_Any2[0]),.I2(A[2]),.I1(B[2]),.I0(C[2]),.O5(Bit_Any2[1]),.O6(Bit_Raw[0]));
	(* HBLKNM = "TERNARY" *)
//	(* BEL = "B6LUT" *)
    (* DONT_TOUCH = "TRUE" *)
	LUT6_2 #(.INIT({{2{16'h6996}},{4{8'hE8}}}))
		u_blut0(.I5(1'b1),.I4(1'b0),.I3(Bit_Any2[1]),.I2(A[3]),.I1(B[3]),.I0(C[3]),.O5(Bit_Any2[2]),.O6(Bit_Raw[1]));
	(* HBLKNM = "TERNARY" *)
//	(* BEL = "C6LUT" *)
    (* DONT_TOUCH = "TRUE" *)
	LUT6_2 #(.INIT({{2{16'h6996}},{4{8'hE8}}}))
		u_clut0(.I5(1'b1),.I4(1'b0),.I3(Bit_Any2[2]),.I2(A[4]),.I1(B[4]),.I0(C[4]),.O5(Bit_Any2[3]),.O6(Bit_Raw[2]));
	(* HBLKNM = "TERNARY" *)
//	(* BEL = "D6LUT" *)	
    (* DONT_TOUCH = "TRUE" *)
	LUT4 #(.INIT(16'h6996))
		u_dlut0(.I3(Bit_Any2[3]),.I2(A[5]),.I1(B[5]),.I0(C[5]),.O(Bit_Raw[3]));
	// Connect up the Carry4.
	assign Carry0_S = {Bit_Raw[3],Bit_Raw[2],Bit_Raw[1],Bit_Raw[0]};
	assign Carry0_DI = {Bit_Any2[3],Bit_Any2[2],Bit_Any2[1],Bit_Any2[0]};
	(* HBLKNM = "TERNARY" *)
	(* DONT_TOUCH = "TRUE" *)
	CARRY4 u_carry0(.S(Carry0_S),.DI(Carry0_DI),.O(Carry0_O),.CO(Carry0_CO),
						 .CI(Carry1_CO[3]));

	// Flops. No way to use the unused flops in this slice.
	(* HBLKNM = "TERNARY" *)
//	(* BEL = "AFF" *)
    (* DONT_TOUCH = "TRUE" *)
	FD u_bit0(.D(Carry0_O[0]),.C(CLK),.Q(Sum_Output_Reg[0]));
	(* HBLKNM = "TERNARY" *)
//	(* BEL = "BFF" *)
    (* DONT_TOUCH = "TRUE" *)
	FD u_bit1(.D(Carry0_O[1]),.C(CLK),.Q(Sum_Output_Reg[1]));
	(* HBLKNM = "TERNARY" *)
//	(* BEL = "CFF" *)
    (* DONT_TOUCH = "TRUE" *)
	FD u_bit2(.D(Carry0_O[2]),.C(CLK),.Q(Sum_Output_Reg[2]));	
	(* HBLKNM = "TERNARY" *)
//	(* BEL = "DFF" *)
    (* DONT_TOUCH = "TRUE" *)
	FD u_bit3(.D(Carry0_O[3]),.C(CLK),.Q(Sum_Output_Reg[3]));
	
	// Auxiliary slice. Generates CarryIn, Bit_Any2[0], the Carry Output Reg, and Bit1 and Bit2 of the power sum.
	// note that the INIT was previously poorly calculated as FEFBECB3FBFEB3EC and ECB3C832B3EC32C8, but that's 
	// because we forgot to take into account the extra amount from the input offset. With that extra amount,
	// only CarryWhenZero changes (to round up the 011 case).
	//
	// These values are correct: they only 'round up' values that end in 11 when the final sum ends in 0.
	// So 0,1,2=>0, 3,4,5,6,7 => 1, 8,9,10 => 2, 11,12,13,14,15 => 3, etc.
	// CarryWhenOne is normal carry logic for a ternary adder (at least 2 low bits set and less than 2 high bits set)
	(* HBLKNM = "AUXILIARY" *)
//	(* BEL = "A6LUT" *)
    (* DONT_TOUCH = "TRUE" *)
	LUT6_L #(.INIT(64'hC832802032C82080))
		u_alut1(.I5(A[1]),.I4(A[0]),.I3(B[1]),.I2(B[0]),.I1(C[1]),.I0(C[0]),.LO(CarryWhenOne));
	(* HBLKNM = "AUXILIARY" *)
//	(* BEL = "B6LUT" *)
    (* DONT_TOUCH = "TRUE" *)
	LUT6_L #(.INIT(64'hECB3C832B3EC32C8))
		u_blut1(.I5(A[1]),.I4(A[0]),.I3(B[1]),.I2(B[0]),.I1(C[1]),.I0(C[0]),.LO(CarryWhenZero));
	// Bit1 (real bit3): Sum_Output_Reg[2:0] == 2 or 4, so INIT = {4{8'h14}}.
	// Bit2 (real bit4): Sum_Output_Reg[3:0] == 0,2,3,B,C,E so INIT = {2{16'h580D}}
	(* HBLKNM = "AUXILIARY" *)
//	(* BEL = "C6LUT" *)
    (* DONT_TOUCH = "TRUE" *)
	LUT6_2 #(.INIT({{2{16'h580D}},{4{8'h14}}}))
		u_clut1(.I5(1'b1),.I4(1'b0),.I3(Sum_Output_Reg[3]),.I2(Sum_Output_Reg[2]),.I1(Sum_Output_Reg[1]),.I0(Sum_Output_Reg[0]),
				  .O5(Raw_Squarer_Out[1]),.O6(Raw_Squarer_Out[2]));
	(* HBLKNM = "AUXILIARY" *)
//	(* BEL = "D6LUT" *)
    (* DONT_TOUCH = "TRUE" *)
	LUT6_2 #(.INIT({{32{1'b0}},{8'hE8}}))
		u_dlut1(.I5(1'b1),.I4(1'b0),.I3(1'b0),.I2(A[1]),.I1(B[1]),.I0(C[1]),.O6(ForcedInsert),.O5(Bit_Any2[0]));

	// Mux & carry.

	(* HBLKNM = "AUXILIARY" *)
//	(* BEL = "F7AMUX" *)
    (* DONT_TOUCH = "TRUE" *)
	MUXF7 u_muxf7(.I0(CarryWhenZero),.I1(CarryWhenOne),.S(Bit_Raw[0]),.O(CarryIn));
	assign Carry1_S = {ForcedInsert,Raw_Squarer_Out[2],CarryWhenZero,CarryWhenOne};
	assign Carry1_DI = {CarryIn,1'b0,Carry0_CO[3],Bit_Raw[0]};
	(* HBLKNM = "AUXILIARY" *)
	(* DONT_TOUCH = "TRUE" *)
	CARRY4 u_carry1(.S(Carry1_S),.DI(Carry1_DI),.O(Carry1_O),.CO(Carry1_CO),
						 .CYINIT(1'b0));	

	//  Flops. All possible flops used in this slice.
	(* HBLKNM = "AUXILIARY" *)
//	(* BEL = "BFF" *)
	(* DONT_TOUCH = "TRUE" *)
	FD u_carry_fd(.D(Carry0_CO[3]),.C(CLK),.Q(Carry_Output_Reg));
	(* HBLKNM = "AUXILIARY" *)
//	(* BEL = "C5FF" *)
    (* DONT_TOUCH = "TRUE" *)
	FD u_square_bit1(.D(Raw_Squarer_Out[1]),.C(CLK),.Q(Squarer_Output_Reg[1]));
	(* HBLKNM = "AUXILIARY" *)
//	(* BEL = "CFF" *)
    (* DONT_TOUCH = "TRUE" *)
	FD u_square_bit2(.D(Raw_Squarer_Out[2]),.C(CLK),.Q(Squarer_Output_Reg[2]));
	

	// Squarer slice. Generates Bit_Any2[4], both_low_bits, and bits 0, 3, 4, 5, 6 of power sum, as well as LSB (quarter-bit).

	// Bit_Any2[4] = {4{8'hE8}}
	// BothLowBits = 11xxx = 32'hFF000000
	(* HBLKNM = "SLICESQUARE" *)
//	(* BEL = "A6LUT" *)
    (* DONT_TOUCH = "TRUE" *)
	LUT6_2 #(.INIT({32'hFF000000,{4{8'hE8}}}))
		u_alut2(.I5(1'b1),.I4(Sum_Output_Reg[1]),.I3(Sum_Output_Reg[0]),.I2(A[5]),.I1(B[5]),.I0(C[5]),.O6(BothLowBits),.O5(Bit_Any2[4]));
	// Bit3 (real bit5). Straight magic lookup value.
	(* HBLKNM = "SLICESQUARE" *)
//	(* BEL = "B6LUT" *)
    (* DONT_TOUCH = "TRUE" *)
	LUT6_2 #(.INIT(64'h7556600360033557))
		u_blut2(.I5(Carry_Output_Reg),.I4(Bit5_Any2_Output_Reg),.I3(Sum_Output_Reg[3]),.I2(Sum_Output_Reg[2]),.I1(Sum_Output_Reg[1]),.I0(Sum_Output_Reg[0]),
				  .O6(Raw_Squarer_Out[3]),.O5(FakeBlutOutput));
	// Bit4 (real bit6). Straight magic lookup value.
	(* HBLKNM = "SLICESQUARE" *)
//	(* BEL = "C6LUT" *)
    (* DONT_TOUCH = "TRUE" *)
	LUT6_2 #(.INIT(64'h666780008000F333))
		u_clut2(.I5(Carry_Output_Reg),.I4(Bit5_Any2_Output_Reg),.I3(Sum_Output_Reg[3]),.I2(Sum_Output_Reg[2]),.I1(Sum_Output_Reg[1]),.I0(Sum_Output_Reg[0]),
				  .O6(Raw_Squarer_Out[4]),.O5(FakeClutOutput));
	// Bit5 and bit6 (real bit7/bit8).
	// Bit5 = (!carry_output_reg && !bit5_any2_output_reg && !Sum_Output_Reg[2]) ||
	//			 (carry_output_reg && bit5_any2_output_reg && (Sum_Output_Reg[2] ^ (both_low_bits)))
	// 	  = 32'h66000033
	// Bit6 = (!carry_output_reg && !bit5_any2_output_reg && !Sum_Output_Reg[3]) ||
	//			 (carry_output_reg && bit5_any2_output_reg && !Sum_Output_Reg[3] && Sum_Output_Reg[2] && both_low_bits) ||
	//        (carry_output_reg && bit5_any2_output_reg && Sum_Output_Reg[3])
	//      = 32'hF800000F
	(* HBLKNM = "SLICESQUARE" *)
//	(* BEL = "D6LUT" *)
    (* DONT_TOUCH = "TRUE" *)
	LUT6_2 #(.INIT({32'hF800000F,32'h66000033}))
		u_dlut2(.I5(1'b1),.I4(Carry_Output_Reg),.I3(Bit5_Any2_Output_Reg),.I2(Sum_Output_Reg[3]),.I1(Sum_Output_Reg[2]),.I0(BothLowBits),
				  .O5(Raw_Squarer_Out[5]),
				  .O6(Raw_Squarer_Out[6]));
	// Carry chain is only used to generate Squarer_Output_Reg[0] from BothLowBits (Squarer_Output_Reg[0] = BothLowBits ^ Sum_Output_Reg[0] == (Sum_Output_Reg[1:0] == 1))
	// BX is used to grab LSB (available flop).
	// CX is unused (kinda-available, but can't think of a reason), but set to a fake O5 to leave C5FF available.
	// DX is unavailable since both flops are used (set to 0 to eliminate switching).
	assign Carry2_S = {Raw_Squarer_Out[6],Raw_Squarer_Out[4],Raw_Squarer_Out[3],BothLowBits};
	assign Carry2_DI = {1'b0,FakeClutOutput,FakeBlutOutput,Sum_Output_Reg[0]};
	(* HBLKNM = "SLICESQUARE" *)
	(* DONT_TOUCH = "TRUE" *)	
	CARRY4 u_carry2(.S(Carry2_S),.DI(Carry2_DI),.O(Carry2_O),.CO(Carry2_CO),
						 .CYINIT(Sum_Output_Reg[0]));	

	// Flops. 1 flop is available here. (C5FF). CX is still available so conceivably those flops could be used.
	(* HBLKNM = "SLICESQUARE" *)
//	(* BEL = "AFF" *)
    (* DONT_TOUCH = "TRUE" *)
	FD u_square_bit0(.D(Carry2_O[0]),.C(CLK),.Q(Squarer_Output_Reg[0]));
	(* HBLKNM = "SLICESQUARE" *)
//	(* BEL = "A5FF" *)
    (* DONT_TOUCH = "TRUE" *)
	FD u_bit5_any2_reg(.D(Bit_Any2[4]),.C(CLK),.Q(Bit5_Any2_Output_Reg));
	(* HBLKNM = "SLICESQUARE" *)
//	(* BEL = "BFF" *)
    (* DONT_TOUCH = "TRUE" *)
	FD u_square_bit3(.D(Raw_Squarer_Out[3]),.C(CLK),.Q(Squarer_Output_Reg[3]));

// NOTE: Probably will not actually do this.
// Probably want to add them all together 
/*	(* HBLKNM = "SLICESQUARE" *)
	(* BEL = "B5FF" *)
	FD u_square_lsb(.D(Sum_Output_Reg[0]),.C(CLK),.Q(Squarer_LSB_Reg));
*/
	(* HBLKNM = "SLICESQUARE" *)
//	(* BEL = "CFF" *)
    (* DONT_TOUCH = "TRUE" *)
	FD u_square_bit4(.D(Raw_Squarer_Out[4]),.C(CLK),.Q(Squarer_Output_Reg[4]));
	(* HBLKNM = "SLICESQUARE" *)
//	(* BEL = "D5FF" *)
    (* DONT_TOUCH = "TRUE" *)
	FD u_square_bit5(.D(Raw_Squarer_Out[5]),.C(CLK),.Q(Squarer_Output_Reg[5]));
	(* HBLKNM = "SLICESQUARE" *)
//	(* BEL = "DFF" *)
    (* DONT_TOUCH = "TRUE" *)
	FD u_square_bit6(.D(Raw_Squarer_Out[6]),.C(CLK),.Q(Squarer_Output_Reg[6]));
	
	assign O = Squarer_Output_Reg;
	assign LSB = Sum_Output_Reg[0];
	

endmodule
