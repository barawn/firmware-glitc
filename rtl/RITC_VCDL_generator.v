`timescale 1ns / 1ps
//% Generate the RITC VCDL input.
//%
//% This module actually generates 3 copies of the VCDL signal.
//% - 1 going directly to OLOGIC and out to the pad.
//% - 1 coming from the OLOGIC, through an IODELAY (via OFB), and over to an ILOGIC for phase-shift scanning.
//% - 1 for general fabric debugging.
module RITC_VCDL_generator(
		input CLK,
		input CLK200,
		input sync_i,
		input en_i,
		input rst_i,
		output idelayctrl_rdy_o,
		input [4:0] delay_i,
		input load_delay_i,

		output VCDL,
		output vcdl_sync_o,
		output vcdl_debug_o
	);

	parameter VCDL_IODELAY_GROUP = "VCDL_IODELAY";
	parameter MAKE_IDELAYCTRL = "YES";
	parameter IDELAYE2LOC = "IDELAY_X0Y99";

	// Really probably want to make the VCDL sync a straight loopback out-and-back to an adjacent IOB.
	(* IOB = "TRUE" *)
	reg vcdl_out = 0;
	reg vcdl_debug = 0;
	always @(posedge CLK) begin
		if (en_i) begin
			vcdl_debug <= sync_i;
			vcdl_out <= sync_i;
		end else begin
			vcdl_debug <= 0;
			vcdl_out <= 0;
		end
	end
	generate
		if (MAKE_IDELAYCTRL == "YES") begin : VCDL_IDELAYCTRL
			(* IODELAY_GROUP = VCDL_IODELAY_GROUP *)
			IDELAYCTRL u_vcdl_idelayctrl(.REFCLK(CLK200),.RST(rst_i),.RDY(idelayctrl_rdy_o));
		end else begin
			assign idelayctrl_rdy_o = 1;
		end
	endgenerate

	// Screw this. Just fix its goddamn location.
//	(* LOC = "IODELAY_X0Y20" *)
//	(* IODELAY_GROUP = VCDL_IODELAY_GROUP *)
//	IODELAYE1 #(.IDELAY_TYPE("VAR_LOADABLE"),
//						.DELAY_SRC("DATAIN"),
//						.IDELAY_VALUE(0),
//						.HIGH_PERFORMANCE_MODE("TRUE"),
//						.SIGNAL_PATTERN("DATA"))
//						u_vcdl_sync_idelay(.DATAIN(vcdl_debug),
//												 .IDATAIN(1'b0),
//												 .ODATAIN(1'b0),
//												 .C(CLK),
//												 .CE(1'b0),
//												 .INC(1'b0),
//												 .RST(load_delay_i),
//												 .CNTVALUEIN(delay_i),
//												 .DATAOUT(vcdl_sync_o));
//(* LOC = "IODELAY_X0Y20" *)
//(* LOC = "IDELAY_X0Y99" *) for RITC0 - _A
//(* LOC = "IDELAY_X1Y134" *) for RITC1 - _B
(* LOC = IDELAYE2LOC *) 

(* IODELAY_GROUP = VCDL_IODELAY_GROUP *) // Specifies group name for associated IDELAYs/ODELAYs and IDELAYCTRL
IDELAYE2 #(
.CINVCTRL_SEL("FALSE"), // Enable dynamic clock inversion (FALSE, TRUE)
.DELAY_SRC("DATAIN"), // Delay input (IDATAIN, DATAIN)
.HIGH_PERFORMANCE_MODE("TRUE"), // Reduced jitter ("TRUE"), Reduced power ("FALSE")
//.IDELAY_TYPE("FIXED"), // FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
.IDELAY_VALUE(0), // Input delay tap setting (0-31)
.PIPE_SEL("FALSE"), // Select pipelined mode, FALSE, TRUE
.REFCLK_FREQUENCY(200.0), // IDELAYCTRL clock input frequency in MHz (190.0-210.0).
.SIGNAL_PATTERN("DATA") // DATA, CLOCK input signal
)
u_vcdl_sync_idelay (
//.CNTVALUEOUT(CNTVALUEOUT), // 5-bit output: Counter value output
.DATAOUT(vcdl_sync_o), // 1-bit output: Delayed data output
.C(CLK), // 1-bit input: Clock input
.CE(1'b0), // 1-bit input: Active high enable increment/decrement input
//.CINVCTRL(CINVCTRL), // 1-bit input: Dynamic clock inversion input
.CNTVALUEIN(delay_i), // 5-bit input: Counter value input
.DATAIN(vcdl_debug), // 1-bit input: Internal delay data input
.IDATAIN(1'b0), // 1-bit input: Data input from the I/O
.INC(1'b0), // 1-bit input: Increment / Decrement tap delay input
//.LD(LD), // 1-bit input: Load IDELAY_VALUE input
//.LDPIPEEN(LDPIPEEN), // 1-bit input: Enable PIPELINE register to load data input
.REGRST(load_delay_i) // 1-bit input: Active-high reset tap-delay input
);
												 
	assign VCDL = vcdl_out;
	assign vcdl_debug_o = vcdl_debug;
endmodule
