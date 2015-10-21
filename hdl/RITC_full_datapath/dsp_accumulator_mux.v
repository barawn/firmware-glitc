`timescale 1ns / 1ps
// A 512-count scaler for all RITC inputs.
// The muxing is done by actually adding all inputs together, but setting all
// undesired inputs to 0 via reset pins.
// Requires 12 DSPs in a chain, but they're only connected via carries
// and there are no multi-DSP paths.
module dsp_accumulator_mux(
		input [47:0] A,
		input [47:0] B,
		input [47:0] C,
		input [47:0] D,
		input [47:0] E,
		input [47:0] F,
		input clk_i,
		input user_clk_i,
		input sync_i,
		input [6:0] sel_i,
		input sel_wr_i,
		output accumulator_done,
		output [63:0] acc_o
    );

	// Channel-group inputs.
	wire [47:0] IN[5:0];
	assign IN[0] = A;
	assign IN[1] = B;
	assign IN[2] = C;
	assign IN[3] = D;
	assign IN[4] = E;
	assign IN[5] = F;

    // Local copy of sync
    reg local_sync = 0;

	wire sel_wr_clk;
	flag_sync u_sync(.in_clkA(sel_wr_i),.clkA(user_clk_i),.out_clkB(sel_wr_clk),.clkB(clk_i));

	wire [47:0] channel_cascade[5:0];
	wire [47:0] accumulator_out;
	wire [3:0] carry_out;
	reg reset_accumulator = 0;

	// Generate an accumulator for any of the 96 3-bit inputs. 
	// You get 2 per 32-bit read, and so long as sel_wr_clk doesn't go,
	// the counter won't restart.
	reg [8:0] counter = {9{1'b0}};
	wire [9:0] counter_plus_one = counter + 1;
	reg counter_overflow = 0;

	reg half_sample_select = 0;
	
	// sel_i[6:4] are channel selects.
	// sel_i[3] selects 0-15 or 16-31, which is a sync selector.
	// sel_i[2] enables DSP B if set, and A if not set
	// sel_i[1] switches between the AB and C inputs of each DSP
	// sel_i[0] isn't used in this module.

	// Overall Behavior:
	// clock 0 : sel_wr_clk is high
	// clock 1 : counter is now reset
	//           not_selectedA/B are all set
	//           P outputs are all reset
	// 			 half_sample_select has been captured
	// clock 2 : if sync matched on clock 1, cep is active
	//           opmode is set on all
	// clock 3 : if sync matched on clock 2, cep is active, else not.

	always @(posedge clk_i) begin
        local_sync <= ~sync_i;

		if (sel_wr_clk) counter <= {9{1'b0}};
		else if ((local_sync ^ half_sample_select) && !counter_plus_one[9]) counter <= counter_plus_one;

		if (sel_wr_clk) half_sample_select <= sel_i[3];
		
		if (sel_wr_clk)
			counter_overflow <= 0;
		else if (local_sync ^ half_sample_select) 
			counter_overflow <= counter_plus_one[9];

		reset_accumulator <= sel_wr_clk;
	end
	
	// Nonselected DSP
	// if first:
	// OPMODE = 000xxxx , RSTA/RSTC=1
	// else
	// OPMODE = 001xxxx , RSTA/RSTC=1
	//
	// Selected DSP
	// if !sel_i[2]
	// OPMODE = 0100011 
	// if sel_i[2]
	// OPMODE = 0101100
	//
	// Opmodes are freely internally invertable, so this is free.
	//
	// so OPMODE = {0,!not_selected,not_selected,sel_i[1],sel_i[1],!sel_i[1],!sel_i[1]}
	// RSTA = not_selected
	// RSTC = not_selected
	// CECTRL = reset_accumulator
	//
	// It takes up to 12 clocks for the accumulator output to propagate upwards but
	// this shouldn't be a problem.
	generate
		genvar ritc, ch, smp;
		for (ritc=0;ritc<2;ritc=ritc+1) begin : RLP
			for (ch=0;ch<3;ch=ch+1) begin : CHLP
				// We need 2 registers per DSP, or 24 registers total.
				// Both registers should be generatable in a single LUT6+2FF set.
				wire [6:0] opmodeA;
				wire [6:0] opmodeB;
				reg cepA = 1;
				reg cepB = 1;
				reg not_selectedA = 1;
				reg not_selectedB = 1;
				wire [47:0] ABinA;
				wire [47:0] ABinB;
				wire [47:0] CinA;
				wire [47:0] CinB;
				wire [47:0] cascade;
				for (smp=0;smp<4;smp=smp+1) begin : SLP
					assign ABinA[12*smp +: 3] = IN[3*ritc+ch][3*smp +: 3];
					assign ABinA[(12*smp + 3) +: 9] = {9{1'b0}};
					assign ABinB[12*smp +: 3] = IN[3*ritc+ch][3*(smp + 8) +: 3];
					assign ABinB[(12*smp + 3) +: 9] = {9{1'b0}};
					assign CinA[12*smp +: 3] = IN[3*ritc+ch][3*(smp + 4) +: 3];
					assign CinA[(12*smp+3) +: 9] = {9{1'b0}};
					assign CinB[12*smp +: 3] = IN[3*ritc+ch][3*(smp + 12) +: 3];
					assign CinB[(12*smp+3) +: 9] = {9{1'b0}};
				end
				always @(posedge clk_i) begin
					if (sel_wr_clk) begin
						not_selectedA <= (sel_i[6] != ritc) || (sel_i[5:4] != ch) || sel_i[2];
						not_selectedB <= (sel_i[6] != ritc) || (sel_i[5:4] != ch) || !sel_i[2];
					end
					if (!not_selectedA) begin
						cepA <= (local_sync ^ half_sample_select) && !counter_overflow;
					end else begin
						cepA <= 1;
					end
					if (!not_selectedB) begin
						cepB <= (local_sync ^ half_sample_select) && !counter_overflow;
					end else begin
						cepB <= 1;
					end
				end
				if (ritc == 0 && ch == 0) begin : AFIRST
					assign opmodeA = {1'b0,!not_selectedA,1'b00,sel_i[1],sel_i[1],!sel_i[1],!sel_i[1]};
					DSP48E1 #(.AREG(1),.BREG(1),.PREG(1),.CREG(1),.OPMODEREG(1),.ALUMODEREG(0),.INMODEREG(0),.USE_SIMD("FOUR12"),.USE_MULT("NONE"),.MREG(0))
						u_dspinmuxA(.A(ABinA[18 +: 30]),.B(ABinA[0 +: 18]),.C(CinA),.OPMODE(opmodeA),
									  .RSTA(not_selectedA),.RSTB(not_selectedA),.RSTC(not_selectedA),
									  .RSTP(reset_accumulator),
									  .CEP(cepA),
									  .CECTRL(reset_accumulator),
									  .CEA2(1'b1),.CEB2(1'b1),.CEC(1'b1),
									  .INMODE({4{1'b0}}),.ALUMODE({4{1'b0}}),
									  .PCOUT(cascade),
									  .CARRYINSEL(3'h0),
									  .CARRYIN(1'b0),
									  .CLK(clk_i));
				end else begin : ANORM
					assign opmodeA = {1'b0,!not_selectedA,not_selectedA,sel_i[1],sel_i[1],!sel_i[1],!sel_i[1]};
					DSP48E1 #(.AREG(1),.BREG(1),.PREG(1),.CREG(1),.OPMODEREG(1),.ALUMODEREG(0),.USE_SIMD("FOUR12"),.USE_MULT("NONE"),.MREG(0))
						u_dspinmuxA(.A(ABinA[18 +: 30]),.B(ABinA[0 +: 18]),.C(CinA),.OPMODE(opmodeA),
									  .RSTA(not_selectedA),.RSTB(not_selectedA),.RSTC(not_selectedA),
									  .RSTP(reset_accumulator),
									  .CEP(cepA),
									  .CECTRL(reset_accumulator),
									  .CEA2(1'b1),.CEB2(1'b1),.CEC(1'b1),
									  .INMODE({4{1'b0}}),.ALUMODE({4{1'b0}}),
									  .PCIN(channel_cascade[3*ritc+ch-1]),
									  .PCOUT(cascade),
									  .CARRYINSEL(3'h0),									  
									  .CARRYIN(1'b0),
									  .CLK(clk_i));					
				end				
				assign opmodeB = {1'b0,!not_selectedB,not_selectedB,sel_i[1],sel_i[1],!sel_i[1],!sel_i[1]};
				if (ritc == 1 && ch == 2) begin : BLAST
					DSP48E1 #(.AREG(1),.BREG(1),.PREG(1),.CREG(1),.OPMODEREG(1),.ALUMODEREG(0),.USE_SIMD("FOUR12"),.USE_MULT("NONE"),.MREG(0))
							u_dspinmuxB(.A(ABinB[18 +: 30]),.B(ABinB[0 +: 18]),.C(CinB),.OPMODE(opmodeB),
											.RSTA(not_selectedB),.RSTB(not_selectedB),.RSTC(not_selectedB),
											.RSTP(reset_accumulator),
											.CEP(cepB),
											.CECTRL(reset_accumulator),
											.CEA2(1'b1),.CEB2(1'b1),.CEC(1'b1),
											.INMODE({4{1'b0}}),.ALUMODE({4{1'b0}}),
											.PCIN(cascade),
											.P(accumulator_out),
											.CARRYINSEL(3'h0),
									  .CARRYIN(1'b0),
											.CLK(clk_i));
				end else begin : BNORM
					DSP48E1 #(.AREG(1),.BREG(1),.PREG(1),.CREG(1),.OPMODEREG(1),.ALUMODEREG(0),.USE_SIMD("FOUR12"),.USE_MULT("NONE"),.MREG(0))
							u_dspinmuxB(.A(ABinB[18 +: 30]),.B(ABinB[0 +: 18]),.C(CinB),.OPMODE(opmodeB),
											.RSTA(not_selectedB),.RSTB(not_selectedB),.RSTC(not_selectedB),
											.RSTP(reset_accumulator),
											.CEP(cepB),
											.CECTRL(reset_accumulator),
											.CEA2(1'b1),.CEB2(1'b1),.CEC(1'b1),
											.INMODE({4{1'b0}}),.ALUMODE({4{1'b0}}),
											.PCIN(cascade),
											.PCOUT(channel_cascade[3*ritc+ch]),
											.CARRYINSEL(3'h0),
									  .CARRYIN(1'b0),
											.CLK(clk_i));
				end
			end
		end
	endgenerate
	
	assign acc_o[00 +: 12] = accumulator_out[0 +: 12];
	assign acc_o[12 +: 04] = {4{1'b0}};
	assign acc_o[16 +: 12] = accumulator_out[12 +: 12];
	assign acc_o[28 +: 04] = {4{1'b0}};
	assign acc_o[32 +: 12] = accumulator_out[24 +: 12];
	assign acc_o[44 +: 04] = {4{1'b0}};
	assign acc_o[48 +: 12] = accumulator_out[36 +: 12];
	assign acc_o[60 +: 04] = {4{1'b0}};
	
	assign accumulator_done = counter_overflow;
endmodule
