/////////////////////////////////////////////////////////////////////
////                                                             ////
////  WISHBONE revB.2 compliant I2C Master controller Top-level  ////
////                                                             ////
////                                                             ////
////  Author: Richard Herveille                                  ////
////          richard@asics.ws                                   ////
////          www.asics.ws                                       ////
////                                                             ////
////  Downloaded from: http://www.opencores.org/projects/i2c/    ////
////                                                             ////
/////////////////////////////////////////////////////////////////////
////                                                             ////
//// Copyright (C) 2001 Richard Herveille                        ////
////                    richard@asics.ws                         ////
////                                                             ////
//// This source file may be used and distributed without        ////
//// restriction provided that this copyright statement is not   ////
//// removed from the file and that any derivative work contains ////
//// the original copyright notice and the associated disclaimer.////
////                                                             ////
////     THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY     ////
//// EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED   ////
//// TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS   ////
//// FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL THE AUTHOR      ////
//// OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,         ////
//// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES    ////
//// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE   ////
//// GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR        ////
//// BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF  ////
//// LIABILITY, WHETHER IN  CONTRACT, STRICT LIABILITY, OR TORT  ////
//// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT  ////
//// OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE         ////
//// POSSIBILITY OF SUCH DAMAGE.                                 ////
////                                                             ////
/////////////////////////////////////////////////////////////////////

//  CVS Log
//
//  $Id: i2c_master_top.v,v 1.12 2009-01-19 20:29:26 rherveille Exp $
//
//  $Date: 2009-01-19 20:29:26 $
//  $Revision: 1.12 $
//  $Author: rherveille $
//  $Locker:  $
//  $State: Exp $
//
// Change History:
//					  Revision 1.11.psa	12/27/2010	23:50:00 barawn
//               Added WISHBONE latency parameter.
//               
//               Revision 1.11  2005/02/27 09:26:24  rherveille
//               Fixed register overwrite issue.
//               Removed full_case pragma, replaced it by a default statement.
//
//               Revision 1.10  2003/09/01 10:34:38  rherveille
//               Fix a blocking vs. non-blocking error in the wb_dat output mux.
//
//               Revision 1.9  2003/01/09 16:44:45  rherveille
//               Fixed a bug in the Command Register declaration.
//
//               Revision 1.8  2002/12/26 16:05:12  rherveille
//               Small code simplifications
//
//               Revision 1.7  2002/12/26 15:02:32  rherveille
//               Core is now a Multimaster I2C controller
//
//               Revision 1.6  2002/11/30 22:24:40  rherveille
//               Cleaned up code
//
//               Revision 1.5  2001/11/10 10:52:55  rherveille
//               Changed PRER reset value from 0x0000 to 0xffff, conform specs.
//

// synopsys translate_off
`include "timescale.v"
// synopsys translate_on

`include "i2c_master_defines.v"


module i2c_master_top(
	wb_clk_i, wb_rst_i, arst_i, wb_adr_i, wb_dat_i, wb_dat_o,
	wb_we_i, wb_stb_i, wb_cyc_i, wb_ack_o, wb_rty_o, wb_err_o, wb_sel_i, wb_inta_o,
	scl_pad_i, scl_pad_o, scl_padoen_o, sda_pad_i, sda_pad_o, sda_padoen_o, debug_o );

	// parameters
	parameter ARST_LVL = 1'b0; // asynchronous reset level
	parameter WB_LATENCY = 1; // WISHBONE latency			
	
	//
	// inputs & outputs
	//

	// wishbone signals
	input        wb_clk_i;     // master clock input
	input        wb_rst_i;     // synchronous active high reset
	input        arst_i;       // asynchronous reset
	input  [2:0] wb_adr_i;     // lower address bits
	input  [7:0] wb_dat_i;     // databus input
	output [7:0] wb_dat_o;     // databus output
	input        wb_we_i;      // write enable input
	input        wb_stb_i;     // stobe/core select signal
	input        wb_cyc_i;     // valid bus cycle input
	output       wb_ack_o;     // bus cycle acknowledge output
	output       wb_inta_o;    // interrupt request signal output
   output 		 wb_rty_o;
	output		 wb_err_o;
	output [4:0] debug_o;
	input [0:0]	 wb_sel_i;
	wire [WB_LATENCY:0] wb_cycstb_pipe;
	assign wb_cycstb_pipe[WB_LATENCY] = wb_cyc_i && wb_stb_i;
	assign wb_ack_o = wb_cycstb_pipe[0] && wb_cyc_i && wb_stb_i;
	generate
		if (WB_LATENCY > 0) begin : WB_PIPE
			reg [WB_LATENCY-1:0] wb_cycstb_delayed = {WB_LATENCY{1'b0}};
			assign wb_cycstb_pipe[WB_LATENCY-1:0] = wb_cycstb_delayed[WB_LATENCY-1:0];
			integer i;
			always @(posedge wb_clk_i) begin : WB_PIPE_LOGIC
				for (i=0;i<WB_LATENCY;i=i+1) begin : WB_PIPE_LOOP
					if (!wb_cyc_i)
						wb_cycstb_delayed[i] <= 0;
					else begin
						if (i == 0) wb_cycstb_delayed[i] <= wb_cyc_i && wb_stb_i;
						else wb_cycstb_delayed[i] <= wb_cycstb_delayed[i-1];
					end
				end
			end
		end
	endgenerate

	reg [7:0] wb_dat_o = {8{1'b0}};
//	reg wb_ack_o;
	reg wb_inta_o = 0;

	// I2C signals
	// i2c clock line
	input  scl_pad_i;       // SCL-line input
	output scl_pad_o;       // SCL-line output (always 1'b0)
	output scl_padoen_o;    // SCL-line output enable (active low)

	// i2c data line
	input  sda_pad_i;       // SDA-line input
	output sda_pad_o;       // SDA-line output (always 1'b0)
	output sda_padoen_o;    // SDA-line output enable (active low)


	//
	// variable declarations
	//

	// registers
	reg  [15:0] prer = {16{1'b1}}; // clock prescale register
	reg  [ 7:0] ctr = {8{1'b0}};  // control register
	reg  [ 7:0] txr = {8{1'b0}};  // transmit register
	wire [ 7:0] rxr;  // receive register
	reg  [ 7:0] cr = {8{1'b0}};   // command register
	wire [ 7:0] sr;   // status register

	// done signal: command completed, clear command register
	wire done;

	// core enable signal
	wire core_en;
	wire ien;

	// status register signals
	wire irxack;
	reg  rxack = 0;       // received aknowledge from slave
	reg  tip = 0;         // transfer in progress
	reg  irq_flag = 0;    // interrupt pending flag
	wire i2c_busy;    // bus busy (start signal detected)
	wire i2c_al;      // i2c bus arbitration lost
	reg  al = 0;          // status register arbitration lost bit

	//
	// module body
	//

	// generate internal reset
	wire rst_i = arst_i ^ ARST_LVL;

	// generate wishbone signals
	// this'll still work with the latency parameter above.
	wire wb_wacc = wb_we_i & wb_ack_o;

	// generate acknowledge output signal
	// psa generated above
	//always @(posedge wb_clk_i)
	//wb_ack_o <= #1 wb_cyc_i & wb_stb_i & ~wb_ack_o; // because timing is always honored

	// Mux output data.
	reg [7:0] wb_dat_muxed;
	always @(*) begin
		case (wb_adr_i)
			3'b000: wb_dat_muxed <= #1 prer[ 7:0];
			3'b001: wb_dat_muxed <= #1 prer[15:8];
			3'b010: wb_dat_muxed <= #1 ctr;
			3'b011: wb_dat_muxed <= #1 rxr; // write is transmit register (txr)
			3'b100: wb_dat_muxed <= #1 sr;  // write is command register (cr)
			3'b101: wb_dat_muxed <= #1 txr;
			3'b110: wb_dat_muxed <= #1 cr;
			3'b111: wb_dat_muxed <= #1 0;   // reserved
		endcase
	end
	
	generate
		if (WB_LATENCY == 0) begin : DEMUX_0CYCLE
			always @(*) begin : ASSIGN
				wb_dat_o <= wb_dat_muxed;
			end
		end else begin : DEMUX_NCYCLE
			always @(posedge wb_clk_i) begin : DEMUX
				if (wb_cycstb_pipe[WB_LATENCY])
					wb_dat_o <= wb_dat_muxed;
			end
		end
	endgenerate

	// generate registers
	always @(posedge wb_clk_i or negedge rst_i)
	  if (!rst_i)
	    begin
	        prer <= #1 16'hffff;
	        ctr  <= #1  8'h0;
	        txr  <= #1  8'h0;
	    end
	  else if (wb_rst_i)
	    begin
	        prer <= #1 16'hffff;
	        ctr  <= #1  8'h0;
	        txr  <= #1  8'h0;
	    end
	  else
	    if (wb_wacc)
	      case (wb_adr_i) // synopsys parallel_case
	         3'b000 : prer [ 7:0] <= wb_dat_i;
	         3'b001 : prer [15:8] <= wb_dat_i;
	         3'b010 : ctr         <= wb_dat_i;
	         3'b011 : txr         <= wb_dat_i;
	         default: ;
	      endcase

	// generate command register (special case)
	always @(posedge wb_clk_i or negedge rst_i)
	  if (!rst_i)
	    cr <= #1 8'h0;
	  else if (wb_rst_i)
	    cr <= #1 8'h0;
	  else if (wb_wacc)
	    begin
	        if (core_en & (wb_adr_i == 3'b100) )
	          cr <= #1 wb_dat_i;
	    end
	  else
	    begin
	        if (done | i2c_al)
	          cr[7:4] <= #1 4'h0;           // clear command bits when done
	                                        // or when aribitration lost
	        cr[2:1] <= #1 2'b0;             // reserved bits
	        cr[0]   <= #1 1'b0;             // clear IRQ_ACK bit
	    end


	// decode command register
	wire sta  = cr[7];
	wire sto  = cr[6];
	wire rd   = cr[5];
	wire wr   = cr[4];
	wire ack  = cr[3];
	wire iack = cr[0];

	// decode control register
	assign core_en = ctr[7];
	assign ien = ctr[6];

	// hookup byte controller block
	i2c_master_byte_ctrl byte_controller (
		.clk      ( wb_clk_i     ),
		.rst      ( wb_rst_i     ),
		.nReset   ( rst_i        ),
		.ena      ( core_en      ),
		.clk_cnt  ( prer         ),
		.start    ( sta          ),
		.stop     ( sto          ),
		.read     ( rd           ),
		.write    ( wr           ),
		.ack_in   ( ack          ),
		.din      ( txr          ),
		.cmd_ack  ( done         ),
		.ack_out  ( irxack       ),
		.dout     ( rxr          ),
		.i2c_busy ( i2c_busy     ),
		.i2c_al   ( i2c_al       ),
		.scl_i    ( scl_pad_i    ),
		.scl_o    ( scl_pad_o    ),
		.scl_oen  ( scl_padoen_o ),
		.sda_i    ( sda_pad_i    ),
		.sda_o    ( sda_pad_o    ),
		.sda_oen  ( sda_padoen_o ),
		.debug	 ( debug_o )
	);

	// status register block + interrupt request signal
	always @(posedge wb_clk_i or negedge rst_i)
	  if (!rst_i)
	    begin
	        al       <= #1 1'b0;
	        rxack    <= #1 1'b0;
	        tip      <= #1 1'b0;
	        irq_flag <= #1 1'b0;
	    end
	  else if (wb_rst_i)
	    begin
	        al       <= #1 1'b0;
	        rxack    <= #1 1'b0;
	        tip      <= #1 1'b0;
	        irq_flag <= #1 1'b0;
	    end
	  else
	    begin
	        al       <= #1 i2c_al | (al & ~sta);
	        rxack    <= #1 irxack;
	        tip      <= #1 (rd | wr);
	        irq_flag <= #1 (done | i2c_al | irq_flag) & ~iack; // interrupt request flag is always generated
	    end

	// generate interrupt request signals
	always @(posedge wb_clk_i or negedge rst_i)
	  if (!rst_i)
	    wb_inta_o <= #1 1'b0;
	  else if (wb_rst_i)
	    wb_inta_o <= #1 1'b0;
	  else
	    wb_inta_o <= #1 irq_flag && ien; // interrupt signal is only generated when IEN (interrupt enable bit is set)

	// assign status register bits
	assign sr[7]   = rxack;
	assign sr[6]   = i2c_busy;
	assign sr[5]   = al;
	assign sr[4:2] = 3'h0; // reserved
	assign sr[1]   = tip;
	assign sr[0]   = irq_flag;

   assign wb_rty_o = 0;
	assign wb_err_o = 0;
endmodule
