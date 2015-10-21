`timescale 1ns / 1ps
//
// Converts 16 separate 0.25 LSB inputs into 3
// (integral) "carry" inputs.
//
module lsb_adder(
		input [15:0] LSB,
		output [3:0] CARRY,
		input CLK
    );
	
	// how can we sleaze this...?
	// 5-3 compressor + 5-3 compressor + 6-3 compressor
	// Slice1:
	// 2 LUT6_2s generate the MSB/NMSB for the 5-3 compressor
	// 2 LUT6s generate the MSB/NMSB for the 6-3 compressor
	// Slice2:
	// 2 LUT5s generate the LSB for the 5-3 compressors
	// 1 LUT6 generates the LSB for the 6-3 compressor
	// 1 LUT5 combines LSBs and MSB/NMSB of 1 5-3 compressor to generate final MSB/NMSB.
	// Note: final '0.5' is rounded down. I don't think this is a big deal. 
	// Slice3:
	// 4 LUT6s generate CARRY[3:0] from 6 input bits.
	
	wire [2:0] stage1_sum[2:0];
	wire [1:0] cascade_sum;
	
	wire [1:0] registered_sum[2:0];
	
	// First 2 groups of 5 are LUT5s, so we can use a LUT6_2 to generate both output bits.
	LUT6_2 #(.INIT(64'hE8808000177E7EE8)) u_alut0(.I5(1'b1),.I4(LSB[4]),.I3(LSB[3]),.I2(LSB[2]),.I1(LSB[1]),.I0(LSB[0]),
																 .O5(stage1_sum[0][1]),.O6(stage1_sum[0][2]));
	LUT6_2 #(.INIT(64'hE8808000177E7EE8)) u_blut0(.I5(1'b1),.I4(LSB[9]),.I3(LSB[8]),.I2(LSB[7]),.I1(LSB[6]),.I0(LSB[5]),
																 .O5(stage1_sum[1][1]),.O6(stage1_sum[1][2]));
	FD u_sum1_bit0(.D(stage1_sum[1][1]),.C(CLK),.Q(registered_sum[1][0]));
	FD u_sum1_bit1(.D(stage1_sum[1][2]),.C(CLK),.Q(registered_sum[1][1]));
	
	// Last is a group of 6, which requires 2 LUT6s.
	LUT6 #(.INIT(64'h8117177E177E7EE8)) u_clut0(.I5(LSB[15]),.I4(LSB[14]),.I3(LSB[13]),.I2(LSB[12]),.I1(LSB[11]),.I0(LSB[10]),
															  .O(stage1_sum[2][1]));
	FD u_sum2_bit0(.D(stage1_sum[2][1]),.C(CLK),.Q(registered_sum[2][0]));
	
	LUT6 #(.INIT(64'hFEE8E880E8808000)) u_dlut0(.I5(LSB[15]),.I4(LSB[14]),.I3(LSB[13]),.I2(LSB[12]),.I1(LSB[11]),.I0(LSB[10]),
															  .O(stage1_sum[2][2]));
	FD u_sum2_bit1(.D(stage1_sum[2][2]),.C(CLK),.Q(registered_sum[2][1]));

	// Next we need the LSBs.
	LUT5 #(.INIT(32'h96696996)) u_alut1(.I4(LSB[4]),.I3(LSB[3]),.I2(LSB[2]),.I1(LSB[1]),.I0(LSB[0]),.O(stage1_sum[0][0]));
	LUT5 #(.INIT(32'h96696996)) u_blut1(.I4(LSB[9]),.I3(LSB[8]),.I2(LSB[7]),.I1(LSB[6]),.I0(LSB[5]),.O(stage1_sum[1][0]));
	LUT6 #(.INIT(64'h6996966996696996)) u_clut1(.I5(LSB[15]),.I4(LSB[14]),.I3(LSB[13]),.I2(LSB[12]),.I1(LSB[11]),.I0(LSB[10]),.O(stage1_sum[2][0]));
	// Finally the add of stage1_sum[0].
	// remember the "11" case doesn't exist for stage1_sum[0]
	LUT6_2 #(.INIT(64'h00FFE80000E817E8)) u_dlut1(.I5(1'b1),.I4(stage1_sum[0][2]),.I3(stage1_sum[0][1]),.I2(stage1_sum[0][0]),.I1(stage1_sum[1][0]),.I0(stage1_sum[2][0]),
																 .O5(cascade_sum[0]),.O6(cascade_sum[1]));
	FD u_sum0_bit0(.D(cascade_sum[0]),.C(CLK),.Q(registered_sum[0][0]));
	FD u_sum0_bit1(.D(cascade_sum[1]),.C(CLK),.Q(registered_sum[0][1]));

	// Stage sums[1] and [2] get latched,
	// and cascade_sum gets latched.

	// Finally we generate CARRY[3:0].
	// Only if all set (add to 8)
	assign CARRY[3] = (registered_sum[0] == 2'b11) && registered_sum[1][1] && (registered_sum[2] == 2'b11);
	// Only if add to 6,7,8.
	// First if 8.
	// then: if 3+2+(1 or 2)
	//          3+1+(2 or 3)
	//          2+2+(2 or 3)
	//          2+1+3
	assign CARRY[2] = ((registered_sum[0] == 2'b11) && registered_sum[1][1] && (registered_sum[2] == 2'b11)) ||	
							((registered_sum[0] == 2'b11) && (registered_sum[1] == 2'b10) && (registered_sum[2] != 2'b00)) ||
							((registered_sum[0] == 2'b11) && (registered_sum[1] == 2'b01) && (registered_sum[2][1])) ||
							((registered_sum[0] == 2'b10) && (registered_sum[1][1]) && (registered_sum[2][1])) ||
							((registered_sum[0] == 2'b10) && (registered_sum[1] == 2'b01) && (registered_sum[2] == 2'b11));
	// Add to anything more than 3.
	assign CARRY[1] = (registered_sum[0][1] && (registered_sum[1][1] || registered_sum[2][1])) || 		// add to 4
							(registered_sum[1][1] && registered_sum[2][1]) ||											// add to 4
							(registered_sum[0][1] && (registered_sum[1][0] && registered_sum[2][0])) || 		// add to 4
							(registered_sum[1][1] && (registered_sum[0][0] && registered_sum[2][0])) ||		// add to 4
							(registered_sum[2][1] && (registered_sum[0][0] && registered_sum[1][0]));
	// Add to anything more than 1.
	assign CARRY[0] = (registered_sum[0][1] || registered_sum[1][1] || registered_sum[2][1]) ||
							((registered_sum[0][0]) && (registered_sum[1][0] || registered_sum[2][0])) ||
							(registered_sum[1][0] && registered_sum[2][0]);
endmodule
