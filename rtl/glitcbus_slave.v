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
module glitcbus_slave(input gclk_i,
		      input 	    GRDWR_B,
		      input 	    GSEL_B,
		      inout [7:0]   GAD,
		      
		      output [15:0] gb_adr_o,
		      output [31:0] gb_dat_o,
		      input [31:0]  gb_dat_i,
		      output 	    gwr_o,
		      output 	    grd_o,
				output [31:0] debug_o);

   (* IOB = "TRUE" *)
   reg 				    gsel_b_q = 1;
   (* IOB = "TRUE" *)
   reg [7:0] 			    gad_q = {8{1'b0}};
   (* IOB = "TRUE" *)
   reg [7:0] 			    gad_oe_b = {8{1'b1}};
	reg gad_oe_debug = 0;
   (* IOB = "TRUE" *)
   reg [7:0] 			    gad_out = {8{1'b0}};   
   (* IOB = "TRUE" *)
   reg 				    grdwr_b_q;
   
   reg [31:0] 			    gb_dat_reg = {24{1'b0}};
   reg [15:0] 			    gb_adr_reg = {16{1'b0}};

   reg [7:0] 			    gb_data_outbound = {8{1'b0}};

   wire [7:0] 			    gad_from_iobuf;   

   // GLITCBUS puts byte0, byte1, byte2, byte3 on bus.
			    
   // At IDLE, if GSEL_Q, then ADR_HIGH is on bus
   // At GB_ADR_HIGH, ADR_LOW is on bus
   // At GB_ADR_LOW, this is our wait state: we need the data
   //                being fed to the output flops, and the
   //                tristate as well.

   // Custom state machine map. 
   // Bit 3 acts as the feed for oe_b.
   // Bit 2 acts as the mux select for gb_data_outbound over
   // gb_data.
   // IDLE        000000000 = 6'h00
   // GB_ADR_HIGH 000010000 = 6'h10
   // GB_ADR_LOWR 000011001 = 6'h19
   // GB_ADR_LOWW 000010001 = 6'h11
   // GB_READ0    000001100 = 6'h0C
   // GB_READ1    000001101 = 6'h0D
   // GB_READ2    000001110 = 6'h0E
   // GB_READ3    000000010 = 6'h02
   // GB_WAIT     000000001 = 6'h01
   // GB_WRITE0   000100000 = 6'h20
   // GB_WRITE1   000100001 = 6'h21
   // GB_WRITE2   000100010 = 6'h22
   // GB_WRITE3   000100011 = 6'h23
   localparam FSM_BITS = 6;
   localparam [FSM_BITS-1:0] IDLE        = 6'h00;
   localparam [FSM_BITS-1:0] GB_ADR_HIGH = 6'h10; // GSEL + high address
   localparam [FSM_BITS-1:0] GB_ADR_LOWR = 6'h19; // Here DAT[7:0] are presented to FF
   localparam [FSM_BITS-1:0] GB_ADR_LOWW = 6'h11;  
   localparam [FSM_BITS-1:0] GB_WAIT     = 6'h01;     // wait state for write
   localparam [FSM_BITS-1:0] GB_READ0    = 6'h0C; // Here DAT[7:0] are on bus
   localparam [FSM_BITS-1:0] GB_READ1    = 6'h0D; // Here DAT[15:8] are on bus
   localparam [FSM_BITS-1:0] GB_READ2    = 6'h0E; // Here DAT[23:16] are on bus
   localparam [FSM_BITS-1:0] GB_READ3    = 6'h02; // Here DAT[31:24] are on bus. 
   localparam [FSM_BITS-1:0] GB_WRITE0   = 6'h20;
   localparam [FSM_BITS-1:0] GB_WRITE1   = 6'h21;
   localparam [FSM_BITS-1:0] GB_WRITE2   = 6'h22;
   localparam [FSM_BITS-1:0] GB_WRITE3   = 6'h23;
   localparam [FSM_BITS-1:0] GB_READWAIT = 6'h03; // GSEL_Q is still high here, so wait till it clears.
   (* FSM_ENCODING = "user" *)
   reg [FSM_BITS-1:0] 		    state = IDLE;
   
   reg [7:0] 			    gb_dat_out_mux;
   wire 			    gb_dat_out_sel = (state[2]);
   wire 			    gb_oe_b_sel = (state[3]);
   wire 			    gb_adr_sel = (state[4]);
   wire 			    gb_adr_lo = (state[0]);
 			    
   always @(*) begin
      if (gb_dat_out_sel)
			gb_dat_out_mux <= gb_data_outbound;
      else
			gb_dat_out_mux <= gb_dat_i[31:24];
   end
   always @(posedge gclk_i) begin
      gad_q <= gad_from_iobuf;      
      gsel_b_q <= GSEL_B;
      grdwr_b_q <= GRDWR_B;
      
      gad_out <= gb_dat_out_mux;
      gad_oe_b <= {8{!gb_oe_b_sel}};
		gad_oe_debug <= gb_oe_b_sel;
		
		
      if (gb_adr_sel && !gb_adr_lo) gb_adr_reg[15:8] <= gad_q;
      else if (gb_adr_sel && gb_adr_lo) gb_adr_reg[7:0] <= gad_q;

      if (state == GB_WRITE0) gb_dat_reg[31:24] <= gad_q;
      if (state == GB_WRITE1) gb_dat_reg[23:16] <= gad_q;
      if (state == GB_WRITE2) gb_dat_reg[15:8] <= gad_q;
      if (state == GB_WRITE3) gb_dat_reg[7:0] <= gad_q;      

      if (state == GB_ADR_LOWR) gb_data_outbound <= gb_dat_i[23:16];
      else if (state == GB_READ0) gb_data_outbound <= gb_dat_i[15:8];
      else if (state == GB_READ1) gb_data_outbound <= gb_dat_i[7:0];      

      case (state)
	IDLE: if (!gsel_b_q) state <= GB_ADR_HIGH;
	GB_ADR_HIGH: 
	  if (grdwr_b_q) state <= GB_ADR_LOWR;
	  else state <= GB_ADR_LOWW;	
	GB_ADR_LOWR: state <= GB_READ0;
	GB_READ0: state <= GB_READ1;
	GB_READ1: state <= GB_READ2;
	GB_READ2: state <= GB_READ3;
	GB_READ3: state <= GB_READWAIT;
	GB_READWAIT: state <= IDLE;	
	GB_ADR_LOWW: state <= GB_WAIT;
	GB_WAIT: state <= GB_WRITE0;
	GB_WRITE0: state <= GB_WRITE1;
	GB_WRITE1: state <= GB_WRITE2;
	GB_WRITE2: state <= GB_WRITE3;
	GB_WRITE3: state <= IDLE;
      endcase
   end
   assign gb_adr_o[7:0] = (gb_adr_sel && gb_adr_lo) ? (gad_q) : gb_adr_reg[7:0];
   assign gb_adr_o[15:8] = gb_adr_reg[15:8];

   assign gb_dat_o = gb_dat_reg;

   reg grd_reg = 0;
   reg gwr_reg = 0;
   always @(posedge gclk_i) begin
      grd_reg <= (state == GB_READ3);
      gwr_reg <= (state == GB_WRITE3);
   end
   assign grd_o = grd_reg;
   assign gwr_o = gwr_reg;

   generate
      genvar i;
      for (i=0;i<8;i=i+1) begin : GADOBUF
	 IOBUF u_iobuf(.I(gad_out[i]),.T(gad_oe_b[i]),.O(gad_from_iobuf[i]),.IO(GAD[i]));
      end
   endgenerate   
   
	assign debug_o[7:0] = gad_q;
	assign debug_o[8] = gsel_b_q;
	assign debug_o[9] = grdwr_b_q;
	assign debug_o[15:10] = state;
	assign debug_o[23:16] = gb_data_outbound;
	assign debug_o[24] = grd_reg;
	assign debug_o[25] = gwr_reg;
	assign debug_o[26] = gad_oe_debug;
endmodule
   
      
      
  
   
