`timescale 1ns / 1ps
////////////////////////////////////////////////////////////////////////////////
// This file is a part of the Antarctic Impulsive Transient Antenna (ANITA)
// project, a collaborative scientific effort between multiple institutions. For
// more information, contact Peter Gorham (gorham@phys.hawaii.edu).
//
// All rights reserved.
//
// Author: Patrick Allison, Ohio State University (allison.122@osu.edu)
// Author:
// Author:
////////////////////////////////////////////////////////////////////////////////
module RITC_dynamic_corrector_v3(
		A,
		B,
		C,
		AC,
		BC,
		CC,
		
		sync_i,
		sysclk_i,		
		cdi_i,
		ce_i
    );

	// Performs dynamic INL correction on the RITC inputs using 3xCFGLUT5s.
	//	Each channel needs 16 samples = 48 CFGLUT5s = 12 SLICEMs.
	// This is 1536 bits = 1.5*1024 bits. Use an 18 Kib block RAMs to do that
	//
	// CDI is actually fanned out to each channel from the block RAM.
	// Entire channels are programmed at once: 3072 bits in total, with each
	// channel getting a 2k space. There are 512 empty addresses at the end of
	// each space.
	//
	// This means each channel takes up 3x32 addresses in the block RAM.
	// So individual addresses can be *updated* using the block RAM.
	// Block RAMs need to be initialized as below so that they start up in defaults:
	// however the bits need to be ker-flipped because they come out LSB-blockRAM first
	// and they need to be MSB-cfglut.
	//
	// CDI chains through each channel, with super-long from-to timing
	// constraints to allow for easy routing. Copies of CE go to each channel,
	// again with super-long timing constraints. Rising edge detector (4 for each channel)
   // hopefully reduces loading.

	parameter INBITS = 3;
	parameter OUTBITS = 6;
	parameter DEMUX = 16;
	
	parameter CHANNELS = 3;

	input [INBITS*DEMUX-1:0] A;
	input [INBITS*DEMUX-1:0] B;
	input [INBITS*DEMUX-1:0] C;
	output [OUTBITS*DEMUX-1:0] AC;
	output [OUTBITS*DEMUX-1:0] BC;
	output [OUTBITS*DEMUX-1:0] CC;
	
	wire [INBITS*DEMUX-1:0] in_data[CHANNELS-1:0];
	wire [OUTBITS*DEMUX-1:0] out_data[CHANNELS-1:0];
	// the high bit is just there for convenience, it's not used
	wire [DEMUX:0] cdi_cascade[CHANNELS-1:0];

	assign in_data[0] = A;
	assign in_data[1] = B;
	assign in_data[2] = C;
	assign AC = out_data[0];
	assign BC = out_data[1];
	assign CC = out_data[2];

	input sync_i;
	input sysclk_i;
	input cdi_i;
	input ce_i;

    (* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
    (* DONT_TOUCH = "TRUE" *)
    reg [2:0] ce_reg_sync = {3{1'b0}};
    reg ce_reg = 1'b0;
    
    always @(posedge sysclk_i) begin : CE_GENERATOR
        ce_reg_sync <= {ce_reg_sync[1:0],ce_i};
        ce_reg <= (ce_reg_sync[1] && !ce_reg_sync[2]);
    end
		
	generate
		genvar i,j;
		for (i=0;i<CHANNELS;i=i+1) begin : CHANNEL_LOOP	
            if (i == 0) begin : HEAD
                assign cdi_cascade[i][0] = cdi_i;
            end else begin : BODY
                assign cdi_cascade[i][0] = cdi_cascade[i-1][DEMUX];
            end
			for (j=0;j<DEMUX;j=j+1) begin : DEMUX_LOOP
				wire [5:0] internal_bits;
				(* DONT_TOUCH = "TRUE" *)
				reg [5:0] internal_reg = {6{1'b0}};
			
				wire [1:0] internal_cascade;
				// Each channel has a single CDI input. These guys will get picked up into a timing
				// group in the UCF, and have a very long "to" constraint.
				
				// The CDI path is MSB FIRST.
				// INITs are initially their 'defaults', which is (power + 3.875)*sigma_val)
				// -3.5 (000) -> 03 (all -3.5s gives  09 = 02 = 110.25) 000 011
				// -2.5 (001) -> 11 (all -2.5s gives  33 = 08 =  56.25) 001 011
				// -1.5 (010) -> 19 (all -1.5s gives  57 = 14 =  20.25) 010 011
				// -0.5 (011) -> 27 (all -0.5s gives  81 = 20 =   2.25) 011 011
				//  0.5 (100) -> 35 (all  0.5s gives 105 = 26 =   2.25) 100 011
				//  1.5 (101) -> 43 (all  1.5s gives 172 = 32 =  20.25) 101 011
				//  2.5 (110) -> 51 (all  2.5s gives 153 = 38 =  56.25) 110 011
				//  3.5 (111) -> 59 (all  3.5s gives 177 = 44 = 110.25) 111 011
				//
				// Since the low two bits are always '3', you always get it ending in 0.25, which means it always rounds down.
				// So this mapping gives *exactly* the same as the 'no INL correction' math.
				//
				// 5th bit is 1 for 2,3,6,7 = 0xCC
				// 6th bit is 1 for 4,5,6,7 = 0xF0
				CFGLUT5 #(.INIT(32'hF0F0CCCC)) u_cfglut0(.I4(1'b1),.I3(sync_i),.I2(in_data[i][INBITS*j+2]),.I1(in_data[i][INBITS*j+1]),.I0(in_data[i][INBITS*j]),
													  .O5(internal_bits[4]),.O6(internal_bits[5]),
													  .CDI(cdi_cascade[i][j]),.CDO(internal_cascade[0]),
													  .CE(ce_reg),.CLK(sysclk_i));
				// 3rd bits is always 0 at first.
				// 4th bit is 1 every-other (1/3/5/7 = 0xAA)
				CFGLUT5 #(.INIT(32'hAAAA0000)) u_cfglut1(.I4(1'b1),.I3(sync_i),.I2(in_data[i][INBITS*j+2]),.I1(in_data[i][INBITS*j+1]),.I0(in_data[i][INBITS*j]),
													  .O5(internal_bits[2]),.O6(internal_bits[3]),
													  .CDI(internal_cascade[0]),.CDO(internal_cascade[1]),
													  .CE(ce_reg),.CLK(sysclk_i));
				// Low 2 bits start off always as '11'. 
				CFGLUT5 #(.INIT({32{1'b1}})) u_cfglut2(.I4(1'b1),.I3(sync_i),.I2(in_data[i][INBITS*j+2]),.I1(in_data[i][INBITS*j+1]),.I0(in_data[i][INBITS*j]),
													  .O5(internal_bits[0]),.O6(internal_bits[1]),
													  .CDI(internal_cascade[1]),.CDO(cdi_cascade[i][j+1]),
													  .CE(ce_reg),.CLK(sysclk_i));
				always @(posedge sysclk_i) begin : REGS
					internal_reg <= internal_bits;
				end
				
				assign out_data[i][OUTBITS*j +: OUTBITS] = internal_reg;

				// The block RAM initialization equivalent for this is (MSB of bit 0 is FIRST)
				// 32'hFFFFFFFF	// bit 0/1
				// 32'h00005555   // bit 2/3
				// 32'h33330F0F	// bit 4/5.
				// repeat x16, then 16 blank 32-bit entries.
				// Because there are 8 of these per INIT, we get 8 entries per.
				// INIT_00 = 256'h00005555FFFFFFFF33330F0F00005555FFFFFFFF33330F0F00005555FFFFFFFF
				// INIT_01 = 256'hFFFFFFFF33330F0F00005555FFFFFFFF33330F0F00005555FFFFFFFF33330F0F
				// INIT_02 = 256'h33330F0F00005555FFFFFFFF33330F0F00005555FFFFFFFF33330F0F00005555
				// INIT_03 = INIT_00
				// INIT_04 = INIT_01
				// INIT_05 = INIT_02
				// INIT_06 = {256{1'b0}}
				// INIT_07 = {256{1'b0}}
				// then repeat for 08-0F, 10-17. 18-1F are 00.
				// Then repeat for 20-27, 28-2F, 30-37, and 38-3F are 00.
			end
		end
	endgenerate
	
endmodule
