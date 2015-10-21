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
module glitc_debug_mux(
		input clk_i,
		input [1:0] sel_i,
		input [70:0] debug0_i,
		input [70:0] debug1_i,
		input [70:0] debug2_i,
		input [70:0] debug3_i,
		output [70:0] debug_o
    );

	reg [70:0] debug_mux = {71{1'b0}};
	always @(posedge clk_i) begin
		case (sel_i)
			2'b00: debug_mux <= debug0_i;
			2'b01: debug_mux <= debug1_i;
			2'b10: debug_mux <= debug2_i;
			2'b11: debug_mux <= debug3_i;
		endcase
	end
	assign debug_o = debug_mux;
endmodule
