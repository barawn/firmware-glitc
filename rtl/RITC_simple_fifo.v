`timescale 1ns / 1ps
// This is a compact simple FIFO-style buffer designed for handling phase uncertainty
// between the system clock and the divided I/O clock, with minimum latency.
// We don't really care about missing a few clocks in the beginning: we just
// want to try to make sure that we're always reading at least 1 clock away
// from the incoming write data.
module RITC_simple_fifo(
			DATA_IN,
			ICLK,
			DATA_OUT,
			OCLK,
			RST_OCLK,
			RST_ICLK
    );

	parameter WIDTH = 4;
	input [WIDTH-1:0] DATA_IN;
	input ICLK;
	output [WIDTH-1:0] DATA_OUT;
	input OCLK;
	input RST_OCLK;
	input RST_ICLK;
	
	reg [1:0] simple_fifo_ptr = {2{1'b0}};
	reg [1:0] simple_fifo_ptr_CLK = {2{1'b0}};
	reg [WIDTH-1:0] simple_fifo[3:0];
	reg [WIDTH-1:0] simple_fifo_output_CLK = {WIDTH{1'b0}};
	reg [2:0] read_flag_CLK = 0;
	reg begin_read = 0;
	
	integer i;
	initial begin
		for (i=0;i<4;i=i+1) begin
			simple_fifo[i] <= {4{1'b0}};
		end
	end
	always @(posedge ICLK) begin
		case(simple_fifo_ptr)
			2'b00: simple_fifo_ptr <= 2'b01;
			2'b01: simple_fifo_ptr <= 2'b11;
			2'b11: simple_fifo_ptr <= 2'b10;
			2'b10: simple_fifo_ptr <= 2'b00;
		endcase
	end
	always @(posedge ICLK)
		simple_fifo[simple_fifo_ptr] <= DATA_IN;

	always @(posedge OCLK) begin
		if (RST_OCLK) simple_fifo_ptr_CLK <= {2{1'b00}};
		else begin
			if (begin_read) begin
				case(simple_fifo_ptr_CLK)
					2'b00: simple_fifo_ptr_CLK <= 2'b01;
					2'b01: simple_fifo_ptr_CLK <= 2'b11;
					2'b11: simple_fifo_ptr_CLK <= 2'b10;
					2'b10: simple_fifo_ptr_CLK <= 2'b00;
				endcase
			end
		end
	end
	always @(posedge OCLK) begin
		read_flag_CLK <= {read_flag_CLK[1:0],simple_fifo_ptr[1]};
	end
	always @(posedge OCLK) begin
		if (RST_OCLK) begin_read <= 0;
		else if (read_flag_CLK[2:1] == 2'b01) begin_read <= 1;
	end
	always @(posedge OCLK) begin
		if (begin_read)
			simple_fifo_output_CLK <= simple_fifo[simple_fifo_ptr_CLK];
	end
	assign DATA_OUT = simple_fifo_output_CLK;
endmodule
