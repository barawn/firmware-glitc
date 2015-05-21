`timescale 1ns / 1ps
module glitc_intercom_oserdes(
		input sysclk_i,
		input sysclkx2_i,
		
		input [3:0] en_i,
		input rst_i,
		
		input do_cmd_i,
		input [4:0] cmd_i,
		input [7:0] cmd_dat_i,
		
		input [10:0] power_i,
		input [4:0] corr_i,
		output [3:0] oq_o
    );
	parameter INVERT = 0;
	
	wire [15:0] oserdes_data;
	
	assign oserdes_data = (do_cmd_i) ? {cmd_i,3'b111,cmd_dat_i} : {corr_i,power_i};
	
	// Data gets bit-flipped through oserdes/iserdes (D1->D4, D2->D3, etc.)
	// Note: Latency here should be 1 CLKDIV cycle through.
	// That is, if we send a SYNC command, we get:
	// clk  do_cmd_i cmd_i cmd_dat_i  
	// 0    1  		  0x4	  0xED			-- data in
	// 1    0 		  XX    XX				-- data clocked in
	// 2    x        XX	  XX				-- data appears at OQ during this cycle
	// 3
	generate
		if (INVERT == 0) begin : P
			OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_WIDTH(4),.SRVAL_OQ(1'b1)) u_oserdes_Q0(.CLK(sysclkx2_i),
																							  .CLKDIV(sysclk_i),
																							  .RST(rst_i),
																							  .OCE(en_i[0]),
																							  .D1(oserdes_data[3]),
																							  .D2(oserdes_data[2]),
																							  .D3(oserdes_data[1]),
																							  .D4(oserdes_data[0]),
																							  .OQ(oq_o[0]));
			OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_WIDTH(4),.SRVAL_OQ(1'b1)) u_oserdes_Q1(.CLK(sysclkx2_i),
																							  .CLKDIV(sysclk_i),
																							  .RST(rst_i),
																							  .OCE(en_i[1]),
																							  .D1(oserdes_data[7]),
																							  .D2(oserdes_data[6]),
																							  .D3(oserdes_data[5]),
																							  .D4(oserdes_data[4]),
																							  .OQ(oq_o[1]));
			OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_WIDTH(4),.SRVAL_OQ(1'b1)) u_oserdes_Q2(.CLK(sysclkx2_i),
																							  .CLKDIV(sysclk_i),
																							  .RST(rst_i),
																							  .OCE(en_i[2]),
																							  .D1(oserdes_data[11]),
																							  .D2(oserdes_data[10]),
																							  .D3(oserdes_data[9]),
																							  .D4(oserdes_data[8]),
																							  .OQ(oq_o[2]));
			OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_WIDTH(4),.SRVAL_OQ(1'b1)) u_oserdes_Q3(.CLK(sysclkx2_i),
																							  .CLKDIV(sysclk_i),
																							  .RST(rst_i),
																							  .OCE(en_i[3]),
																							  .D1(oserdes_data[15]),
																							  .D2(oserdes_data[14]),
																							  .D3(oserdes_data[13]),
																							  .D4(oserdes_data[12]),
																							  .OQ(oq_o[3]));
		end else begin : N
			OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_WIDTH(4),.SRVAL_OQ(1'b0)) u_oserdes_Q0(.CLK(sysclkx2_i),
																							  .CLKDIV(sysclk_i),
																							  .RST(rst_i),
																							  .OCE(en_i[0]),
																							  .D1(~oserdes_data[3]),
																							  .D2(~oserdes_data[2]),
																							  .D3(~oserdes_data[1]),
																							  .D4(~oserdes_data[0]),
																							  .OQ(oq_o[0]));
			OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_WIDTH(4),.SRVAL_OQ(1'b0)) u_oserdes_Q1(.CLK(sysclkx2_i),
																							  .CLKDIV(sysclk_i),
																							  .RST(rst_i),
																							  .OCE(en_i[1]),
																							  .D1(~oserdes_data[7]),
																							  .D2(~oserdes_data[6]),
																							  .D3(~oserdes_data[5]),
																							  .D4(~oserdes_data[4]),
																							  .OQ(oq_o[1]));
			OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_WIDTH(4),.SRVAL_OQ(1'b0)) u_oserdes_Q2(.CLK(sysclkx2_i),
																							  .CLKDIV(sysclk_i),
																							  .RST(rst_i),
																							  .OCE(en_i[2]),
																							  .D1(~oserdes_data[11]),
																							  .D2(~oserdes_data[10]),
																							  .D3(~oserdes_data[9]),
																							  .D4(~oserdes_data[8]),
																							  .OQ(oq_o[2]));
			OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_WIDTH(4),.SRVAL_OQ(1'b0)) u_oserdes_Q3(.CLK(sysclkx2_i),
																							  .CLKDIV(sysclk_i),
																							  .RST(rst_i),
																							  .OCE(en_i[3]),
																							  .D1(~oserdes_data[15]),
																							  .D2(~oserdes_data[14]),
																							  .D3(~oserdes_data[13]),
																							  .D4(~oserdes_data[12]),
																							  .OQ(oq_o[3]));
		end
	endgenerate																			  

endmodule
