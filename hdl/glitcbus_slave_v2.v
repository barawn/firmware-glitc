`timescale 1ns / 1ps

module glitcbus_slave_v2(
			input gclk_i,
			output [15:0] gb_adr_o,
			output [31:0] gb_dat_o,
			input [31:0] gb_dat_i,
			output grd_o,
			output gwr_o,
			output [70:0] debug_o,
			inout [7:0] GAD,
			input GSEL_B,
			input GRDWR_B
    );

	(* IOB = "TRUE" *)
	reg [7:0] gad_q = {8{1'b0}};
	(* IOB = "TRUE" *)
	reg [7:0] gad_out_q = {8{1'b0}};
	(* IOB = "TRUE" *)
	reg [7:0] gad_oeb_q = {8{1'b1}};
	(* IOB = "TRUE" *)
	reg gsel_b_q = 0;
	(* IOB = "TRUE" *)
	reg grdwr_b_q = 0;
	
	reg gad_oeb_debug = 1;
	
	// The bottom 2 bits encode which byte is presented to the output IOB FFs.
	localparam FSM_BITS=4;
	localparam [FSM_BITS-1:0] GB_IDLE 			= 0;				//< GLITCBUS is idle. 
	localparam [FSM_BITS-1:0] GB_WRITE_ADDRL	= 1;				//< Write path, address low on bus.
	localparam [FSM_BITS-1:0] GB_WRITE_BYTE3	= 2;				//< Write path, byte 3 on bus.
	localparam [FSM_BITS-1:0] GB_WRITE_BYTE2	= 3;				//< Write path, byte 2 on bus.
	localparam [FSM_BITS-1:0] GB_WRITE_BYTE1	= 4;				//< Write path, byte 1 on bus.
	localparam [FSM_BITS-1:0] GB_WRITE_BYTE0	= 5;				//< Write path, byte 0 on bus.
	localparam [FSM_BITS-1:0] GB_READ_ADDRL	= 8;				//< Read path, address low on bus.
	localparam [FSM_BITS-1:0] GB_READ_BYTE2	= 9;				//< Read path, putting byte 2 on bus.
	localparam [FSM_BITS-1:0] GB_READ_BYTE1	= 10;				//< Read path, putting byte 1 on bus.
	localparam [FSM_BITS-1:0] GB_READ_BYTE0	= 11;				//< Read path, putting byte 0 on bus.
	localparam [FSM_BITS-1:0] GB_READ_WAIT1	= 12;				//< Read path, waiting for complete 1.
	localparam [FSM_BITS-1:0] GB_READ_WAIT2	= 13;				//< Read path, waiting for complete 2.
	(* FSM_ENCODING = "user" *)
	reg [FSM_BITS-1:0] gb_state = GB_IDLE;
	
	reg [15:0] glitcbus_address_storage = {16{1'b0}};
	reg [23:0] glitcbus_data_storage = {24{1'b0}};
	reg [23:0] glitcbus_data_out_storage = {24{1'b0}};
	reg glitcbus_write = 0;
	reg glitcbus_read = 0;
	wire [31:0] glitcbus_data_in;
	wire [15:0] glitcbus_address;
	wire [7:0] glitcbus_data_out_bytes[3:0];
	wire [7:0] glitcbus_data_out;
	wire glitcbus_output_enable_b;
	
	assign glitcbus_data_in = {glitcbus_data_storage, gad_q};
	assign glitcbus_address = (gb_state == GB_READ_ADDRL) ? {glitcbus_address_storage[15:8],gad_q} :
																				 glitcbus_address_storage;
	assign glitcbus_data_out_bytes[0] = gb_dat_i[31:24];
	assign glitcbus_data_out_bytes[1] = glitcbus_data_out_storage[23:16];
	assign glitcbus_data_out_bytes[2] = glitcbus_data_out_storage[15:8];
	assign glitcbus_data_out_bytes[3] = glitcbus_data_out_storage[7:0];
	assign glitcbus_data_out = glitcbus_data_out_bytes[gb_state[1:0]];

	assign glitcbus_output_enable_b   =  !(gb_state == GB_READ_ADDRL ||
														gb_state == GB_READ_BYTE2 ||
														gb_state == GB_READ_BYTE1 ||
														gb_state == GB_READ_BYTE0);
	
	always @(posedge gclk_i) begin
		gad_out_q <= glitcbus_data_out;
		gad_q <= GAD;
		gsel_b_q <= GSEL_B;
		grdwr_b_q <= GRDWR_B;
		gad_oeb_q <= {8{glitcbus_output_enable_b}};
		gad_oeb_debug <= glitcbus_output_enable_b;
		case (gb_state)
			GB_IDLE: if (!gsel_b_q && !grdwr_b_q) gb_state <= GB_WRITE_ADDRL;
				 else if (!gsel_b_q && grdwr_b_q) gb_state <= GB_READ_ADDRL;
			GB_WRITE_ADDRL: gb_state <= GB_WRITE_BYTE3;
			GB_WRITE_BYTE3: gb_state <= GB_WRITE_BYTE2;
			GB_WRITE_BYTE2: gb_state <= GB_WRITE_BYTE1;
			GB_WRITE_BYTE1: gb_state <= GB_WRITE_BYTE0;
			GB_WRITE_BYTE0: gb_state <= GB_IDLE;
			GB_READ_ADDRL: gb_state <= GB_READ_BYTE2;
			GB_READ_BYTE2: gb_state <= GB_READ_BYTE1;
			GB_READ_BYTE1: gb_state <= GB_READ_BYTE0;
			GB_READ_BYTE0: gb_state <= GB_READ_WAIT1;
			GB_READ_WAIT1: gb_state <= GB_READ_WAIT2;
			GB_READ_WAIT2: gb_state <= GB_IDLE;
			default: gb_state <= GB_IDLE;
		endcase
		
		if (gb_state == GB_IDLE) 		  glitcbus_address_storage[15:8] <= gad_q;
		if (gb_state == GB_WRITE_ADDRL) glitcbus_address_storage[7:0] <= gad_q;
		if (gb_state == GB_WRITE_BYTE3) glitcbus_data_storage[23:16] <= gad_q;
		if (gb_state == GB_WRITE_BYTE2) glitcbus_data_storage[15:8] <= gad_q;
		if (gb_state == GB_WRITE_BYTE1) glitcbus_data_storage[7:0]	<= gad_q;
		if (gb_state == GB_READ_ADDRL)  glitcbus_data_out_storage <= gb_dat_i[23:0];

		glitcbus_write <= (gb_state == GB_WRITE_BYTE1);
		glitcbus_read <= (gb_state == GB_IDLE && !gsel_b_q && grdwr_b_q);
	end

	generate
		genvar i;
		for (i=0;i<8;i=i+1) begin : IOB_LOOP
				assign GAD[i] = (gad_oeb_q[i]) ? 1'bZ : gad_out_q[i];
		end
	endgenerate

	assign gb_dat_o = glitcbus_data_in;
	assign gb_adr_o = glitcbus_address;
	assign grd_o = glitcbus_read;
	assign gwr_o = glitcbus_write;

	assign debug_o[0 +: 8] = gad_q;
	assign debug_o[8] = gad_oeb_debug;
	assign debug_o[9] = grdwr_b_q;
	assign debug_o[10] = gsel_b_q;
	assign debug_o[11 +: 4] = gb_state;
	assign debug_o[15] = grd_o;
	assign debug_o[16] = gwr_o;
	assign debug_o[17 +: 16] = glitcbus_address;
	assign debug_o[33 +: 32] = (glitcbus_read) ? gb_dat_i : glitcbus_data_in ;
endmodule
