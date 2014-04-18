`timescale 1ns / 1ps
module ISERDES_internal_loop(
		input CLK_BUFIO,
		input CLK_BUFR,
		input D,
		input RST,
		input BITSLIP,
		output [3:0] Q,
		output BYPASS
    );

	parameter IODELAY_GRP_NAME = "IODELAY_0";
	parameter LOOP_DELAY = 11;
	wire loopback;

	(* RPM_GRID = "GRID" *)
	(* RLOC = "X0Y0" *)
	ISERDESE2 #(.DATA_RATE("DDR"),
					.DATA_WIDTH(4),
					.INTERFACE_TYPE("NETWORKING"),
					.IOBDELAY("BOTH"))
							u_iserdes(.DDLY(D),
										  .O(loopback),
										  .CLK(CLK_BUFIO),
										  .CLKB(~CLK_BUFIO),
										  .CE1(1'b1),
										  .CE2(1'b1),
										  .RST(RST),
										  .CLKDIV(CLK_BUFR),
										  .BITSLIP(BITSLIP),
										  .Q1(Q[0]),
										  .Q2(Q[1]),
										  .Q3(Q[2]),
										  .Q4(Q[3]));
(*RLOC = "X3Y1" *)
(* IODELAY_GROUP = IODELAY_GRP_NAME *) // Specifies group name for associated IDELAYs/ODELAYs and IDELAYCTRL
IDELAYE2 #(
.CINVCTRL_SEL("FALSE"), // Enable dynamic clock inversion (FALSE, TRUE)
.DELAY_SRC("DATAIN"), // Delay input (IDATAIN, DATAIN)
.HIGH_PERFORMANCE_MODE("TRUE"), // Reduced jitter ("TRUE"), Reduced power ("FALSE")
.IDELAY_TYPE("FIXED"), // FIXED, VARIABLE, VAR_LOAD, VAR_LOAD_PIPE
.IDELAY_VALUE(LOOP_DELAY), // Input delay tap setting (0-31)
.PIPE_SEL("FALSE"), // Select pipelined mode, FALSE, TRUE
.REFCLK_FREQUENCY(200.0), // IDELAYCTRL clock input frequency in MHz (190.0-210.0).
.SIGNAL_PATTERN("DATA") // DATA, CLOCK input signal
)
u_vcdl_sync_idelay (
.DATAOUT(BYPASS), // 1-bit output: Delayed data output
.DATAIN(loopback), // 1-bit input: Internal delay data input
.IDATAIN(1'b0), // 1-bit input: Data input from the I/O
.INC(1'b0) // 1-bit input: Increment / Decrement tap delay input
);



endmodule
