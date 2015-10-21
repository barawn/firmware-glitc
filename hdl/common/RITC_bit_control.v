// Bit control module. This module takes 2 SLICELs and a SLICEM.
// The packing is directed because Map, as always, is stupid.
// This also prevents it from detecting identical stuff too.
//
// Bit control loading:
// The input bitstream comes in start bit, bitslip bit, delay bits,
// then channel select, then bit select.
// Data always comes in MSB first.
// So that means we shift data into bit select SRL first,
// then shift into channel select SRL,
// then shift into delay bits (again MSB *first*)
// then shift delay MSB into bitslip
// The start bit is shifted out of the bitslip register
// in the clock when shreg_enable turns off.
//
// The SRL addresses should be *positive* (MSB comes first).
// After that we shift into a 6-bit shift register (shift left,
// so LSB receives data first - LSB ends up coming *last*)
// 
// Things are a bit goofy because bit_ok/chan_ok are essentially a cycle behind: they need
// shreg_enable to go low a cycle LATER. But that would screw up the final_shreg
// outputs for the delay.
//
// So we fix this by taking final_shreg[5] and putting it into an additional flop (in the aux slice).
// (bitslip_q)
// It needs a LUT in front of it, but that's fine, the aux slice has space.
// Its input comes from shreg_reset, shreg_enable, and final_shreg[5], and bitslip_q (itself).
// 1xxx = 0
// 010x = 0
// 011x = 1
// 00x0 = 0
// 00x1 = 1
// That is, if shreg_reset = 1, reset.
// If shreg_enable = 1, then take value of final_shreg[5].
// Otherwise maintain current value.
module RITC_bit_control(
		input sysclk_i,
		input ctrl_clk_i,
		input ctrl_i,
		output bitslip_o,
		output load_o,
		input [2:0] channel_i,
		input [3:0] bit_i,
		output [4:0] delay_o
	);
	
	parameter CHAN_VALUE = 0;
	parameter BIT_VALUE = 0;
	parameter USE_BITSLIP_FOR_LOADING = "FALSE";
	
	//% Final portion of the shift register. This has access to all bits, which is why it's not an SRL.
	wire [5:0] final_shreg;
	//% Retained bitslip indicator.
	wire bitslip_q;
	//% Latched output from the SRLs. Captured with shreg_enable.
	wire bit_ok;
	//% Latched output from the SRLs. Captured with shreg_enable.
	wire channel_ok;
	//% Input to the enable register.
	wire shreg_enable_in;
	//% Enable bit for the delay/bitslip registers. The SRLs don't use this. They always clock.
	wire shreg_enable;
	//% Reset for the delay/bitslip registers. The SRLs don't use this. They have no reset.
	wire shreg_reset;

    //% Input to the channel SRL's address. Data comes in MSB first, so this address is OK.
    wire [4:0] channel_address = { 2'b00, channel_i };
    //% Input to the bit SRL's address. Same as above.
    wire [4:0] bit_address = {1'b0, bit_i};
    
	// The control bit first passes through 2 SRL32s.
	// There's no clock enable here - this is a pure constant shift register.
	// This is because SRLC32Es don't have a reset. So loads must be followed
	// by at least 64 clock cycles of idle time.
	wire channel_cascade;
	wire bit_cascade;
	wire channel_is_selected;
	wire bit_is_selected;
	// The first shreg it passes through corresponds to the LAST that arrive in: namely the bit selection.
	(* HBLKNM = "SHREG_SLICE" *)
	SRLC32E u_srlA(.D(ctrl_i),.CE(1'b1),.CLK(ctrl_clk_i),.Q31(bit_cascade),.Q(bit_is_selected),.A(bit_address));
	// Next comes the channel selection (next-to-last).
	(* HBLKNM = "SHREG_SLICE" *)
	SRLC32E u_srlB(.D(bit_cascade),.CE(1'b1),.CLK(ctrl_clk_i),.Q31(channel_cascade),.Q(channel_is_selected),.A(channel_address));
	// Now the control bit passes through the delay registers.
	// However, they reset if ctrl_i is high while shreg_enable is not high.
	// This only happens right at the beginning.
	// They also *stop* when shreg_enable goes low, which happens when the start bit hits
	// the bitslip register.
	
    // This allows these guys to act as complete capture registers as well.
    // Note that there's no way to allow the SRL outputs to act as capture registers as well! So to reset
    // *them*, we just have to make sure that we cannot send two bitstreams quickly: we need to wait for
    // the SRLs to clear.
	(* HBLKNM = "SHREG_SLICE" *)
	FDRE u_final0(.D(channel_cascade),.CE(shreg_enable),.C(ctrl_clk_i),.R(shreg_reset),.Q(final_shreg[0]));
   (* HBLKNM = "SHREG_SLICE" *)
	FDRE u_final1(.D(final_shreg[0]),.CE(shreg_enable),.C(ctrl_clk_i),.R(shreg_reset),.Q(final_shreg[1]));
   (* HBLKNM = "SHREG_SLICE" *)
	FDRE u_final2(.D(final_shreg[1]),.CE(shreg_enable),.C(ctrl_clk_i),.R(shreg_reset),.Q(final_shreg[2]));
   (* HBLKNM = "SHREG_SLICE" *)
	FDRE u_final3(.D(final_shreg[2]),.CE(shreg_enable),.C(ctrl_clk_i),.R(shreg_reset),.Q(final_shreg[3]));
   (* HBLKNM = "SHREG_SLICE" *)
	FDRE u_final4(.D(final_shreg[3]),.CE(shreg_enable),.C(ctrl_clk_i),.R(shreg_reset),.Q(final_shreg[4]));
   (* HBLKNM = "SHREG_SLICE" *)
	FDRE u_final5(.D(final_shreg[4]),.CE(shreg_enable),.C(ctrl_clk_i),.R(shreg_reset),.Q(final_shreg[5]));
   (* HBLKNM = "SHREG_SLICE" *)
	FDRE u_bitok(.D(bit_is_selected),.CE(shreg_enable),.C(ctrl_clk_i),.R(shreg_reset),.Q(bit_ok));
   (* HBLKNM = "SHREG_SLICE" *)
	FDRE u_chanok(.D(channel_is_selected),.CE(shreg_enable),.C(ctrl_clk_i),.R(shreg_reset),.Q(channel_ok));

    // shreg_reset is a 2LUT: if ctrl_i && !shreg_enable, reset = 1.
	(* HBLKNM = "AUX_SLICE" *)
	LUT2 #(.INIT(4'h4)) u_reset_lut(.I1(ctrl_i),.I0(shreg_enable),.O(shreg_reset));
    // bitslip_in is a 4LUT:
    // 1xxx = 0
    // 010x = 0
    // 011x = 1
    // 00x0 = 0
    // 00x1 = 1
    // or
    // 0000 = 0
    // 0001 = 1
    // 0010 = 0
    // 0011 = 1
    // 0100 = 0
    // 0101 = 0
    // 0110 = 1
    // 0111 = 1
    // 1xxx = 0
    // = 0x00CA
    (* HBLKNM = "AUX_SLICE" *)
    LUT4 #(.INIT(16'h00CA)) u_bitslip_in_lut(.I3(shreg_reset),.I2(shreg_enable),.I1(final_shreg[5]),.I0(bitslip_q),.O(bitslip_in));
    (* HBLKNM = "AUX_SLICE" *)
    FD u_bitslipq_fd(.D(bitslip_in),.C(ctrl_clk_i),.Q(bitslip_q));
    
	// shreg_enable is a 3LUT:
	// 1xx = 0
	// 01x = 1
	// 000 = 0
	// 001 = 1
	// or
	// 000 = 0
	// 001 = 1
	// 010 = 1
	// 011 = 1
	// 1xx = 0
	// = 0x0E
	// shreg_enable's logic is
	// always @(posedge ctrl_clk_i) begin
	//      if (bitslip_q) shreg_enable <= 0;
	//      else if (ctrl_i) shreg_enable <= 1;
	// end
	// The shreg is enabled when the first bit is received,
	// and it turns off when that bit propagates all the way to the last shreg (final_shreg[5])
	(* HBLKNM = "AUX_SLICE" *)
	LUT3 #(.INIT(8'h0E)) u_enable_lut(.I2(bitslip_q),.I1(ctrl_i),.I0(shreg_enable),.O(shreg_enable_in));
	(* HBLKNM = "AUX_SLICE" *)
	FD u_enable_fd(.D(shreg_enable_in),.C(ctrl_clk_i),.Q(shreg_enable));
	// sysclk domain stuff.
	// This detects the end of the shreg load (via a falling edge on shreg_enable)
	// and generates a load or bitslip flag as appropriate.
	wire [1:0] shreg_complete;
	wire shreg_falling_edge;
	wire execute_flag;
	wire bitslip_flag_in;
	wire bitslip_flag;
	wire load_flag_in;
	wire load_flag;

	(* HBLKNM = "SYSCLK_SLICE" *)
	FD u_shreg0_fd(.D(shreg_enable),.C(sysclk_i),.Q(shreg_complete[0]));
	(* HBLKNM = "SYSCLK_SLICE" *)
	FD u_shreg1_fd(.D(shreg_complete[0]),.C(sysclk_i),.Q(shreg_complete[1]));
	// This is a falling edge flag: looking for shreg_complete[1] = 1, shreg_complete[0] = 0.
	(* HBLKNM = "SYSCLK_SLICE" *)
	LUT2 #(.INIT(4'h4)) u_execute_lut(.I1(shreg_complete[1]),.I0(shreg_complete[0]),.O(shreg_falling_edge));
	(* HBLKNM = "SYSCLK_SLICE" *)
	FD u_execute_fd(.D(shreg_falling_edge),.C(sysclk_i),.Q(execute_flag));
	// LUT4: channel ok & bit_ok & bitslip_q & execute_flag all have to be high. This is 8'h80.
	(* HBLKNM = "SYSCLK_SLICE" *)
	LUT4 #(.INIT(16'h8000)) u_bitslip_lut(.I3(bitslip_q),.I2(channel_ok),.I1(bit_ok),.I0(execute_flag),.O(bitslip_flag_in));
	(* HBLKNM = "SYSCLK_SLICE" *)
	LUT4 #(.INIT(16'h0080)) u_load_lut(.I3(bitslip_q),.I2(channel_ok),.I1(bit_ok),.I0(execute_flag),.O(load_flag_in));
	(* HBLKNM = "SYSCLK_SLICE" *)
	FD u_bitslip_fd(.D(bitslip_flag_in),.C(sysclk_i),.Q(bitslip_flag));
	(* HBLKNM = "SYSCLK_SLICE" *)
	FD u_load_fd(.D(load_flag_in),.C(sysclk_i),.Q(load_flag));

	assign load_o = (USE_BITSLIP_FOR_LOADING == "FALSE") ? load_flag : bitslip_flag;
	assign bitslip_o = bitslip_flag;
	assign delay_o = final_shreg[5:1];
	
endmodule
