`timescale 1ns / 1ps
// World's dumbest interface.
module glitcbus_slave(
		inout GSEL,
		inout [7:0] GAD,
		input GCCLK,
		input GRST,
		input clk_i,
		output [13:0] address_o,
		input [7:0] data_i,
		output [7:0] data_o,
		output selA_o,
		output selB_o,
		output wr_o,
		output rd_o,
		input ack_i
    );


	localparam GFSM_BITS=3;
	localparam [GFSM_BITS-1:0] G_IDLE = 0;
	localparam [GFSM_BITS-1:0] G_ADDR_H = 1;
	localparam [GFSM_BITS-1:0] G_ADDR_L = 2;
	localparam [GFSM_BITS-1:0] G_DATA_WAIT = 3;
	localparam [GFSM_BITS-1:0] G_DATA_OUT = 4;
	localparam [GFSM_BITS-1:0] G_DATA_IN = 5;
	reg [GFSM_BITS-1:0] state = {GFSM_BITS{1'b0}};
	
	wire data_complete;
	reg [15:0] in_address = {16{1'b0}};
	wire transaction_read = (in_address[15]);
	
	always @(posedge GCCLK or posedge GRST) begin
		 if (GRST) state <= G_IDLE;
		 case (state)
			G_IDLE: if (GSEL) state <= G_ADDR_H;
			G_ADDR_H: state <= G_ADDR_L;
			G_ADDR_L: if (transaction_read) state <= G_DATA_WAIT;
			G_DATA_WAIT: if (ack_i) state <= G_DATA_OUT;
			G_DATA_OUT: state <= G_IDLE;
			G_DATA_IN: state <= G_IDLE;
		endcase
	end
	always @(posedge GCCLK) begin
		if (state == G_ADDR_H) in_address[15:8] <= GAD;
		if (state == G_ADDR_L) in_address[7:0] <= GAD;
	end
	reg [7:0] data_out = {8{1'b0}};
	always @(posedge GCCLK) begin
		if (state == G_DATA_IN) data_out <= GAD;
	end
	assign GAD = (state == G_DATA_OUT) ? data_i : {8{1'bZ}};
	assign selA_o = ~in_address[14];
	assign selB_o = in_address[14];
	wire gsel_out = (state == G_DATA_OUT);
	assign GSEL = (state == G_DATA_WAIT ||| state == G_DATA_OUT) ? gsel_out : {8{1'bZ}};
endmodule
