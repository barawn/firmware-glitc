`timescale 1ns / 1ps
module glitc_intercom_oserdes_v2(
		sysclk_i,
		sysclkx2_i,
		
		en_i,
		rst_i,
		
		command_i,
		corr_i,
		power_i,
		
		oq_o
    );
	parameter INVERT = 0;
    parameter NBITS = 5;
    
    input sysclk_i;
    input sysclkx2_i;
    input en_i;
    input rst_i;
    input [1:0] command_i;
    input [5:0] corr_i;
    input [11:0] power_i;
    
    output [4*NBITS-1:0] oq_o;
    	
	wire [4*NBITS-1:0] oserdes_data;
	
	assign oserdes_data[0 +: 12] = power_i;
	assign oserdes_data[12 +: 6] = corr_i;
	assign oserdes_data[18 +: 2] = command_i;
		
	generate
		genvar i;
		if (INVERT == 0) begin : P
		    for (i=0;i<NBITS;i=i+1) begin : LP
                (* DONT_TOUCH = "TRUE" *)
                (* EQUIVALENT_REGISTER_REMOVAL = "FALSE" *)
                reg oserdes_clock_enable = 0;
                (* DONT_TOUCH = "TRUE" *)
                (* EQUIVALENT_REGISTER_REMOVAL = "FALSE" *)
                reg oserdes_clock_enable_x2 = 0;
                always @(posedge sysclk_i) oserdes_clock_enable <= en_i;                    
                always @(posedge sysclkx2_i) oserdes_clock_enable_x2 <= oserdes_clock_enable;
                OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_WIDTH(4),.SRVAL_OQ(1'b1)) u_oserdes(.CLK(sysclkx2_i),
                                                                                                  .CLKDIV(sysclk_i),
                                                                                                  .RST(rst_i),
                                                                                                  .OCE(oserdes_clock_enable_x2),
                                                                                                  .D1(oserdes_data[4*i+3]),
                                                                                                  .D2(oserdes_data[4*i+2]),
                                                                                                  .D3(oserdes_data[4*i+1]),
                                                                                                  .D4(oserdes_data[4*i]),
                                                                                                  .OQ(oq_o[i]));
            end
        end else begin : N
		    for (i=0;i<NBITS;i=i+1) begin : LP
                (* DONT_TOUCH = "TRUE" *)
                (* EQUIVALENT_REGISTER_REMOVAL = "FALSE" *)
                reg oserdes_clock_enable = 0;
                (* DONT_TOUCH = "TRUE" *)
                (* EQUIVALENT_REGISTER_REMOVAL = "FALSE" *)
                reg oserdes_clock_enable_x2 = 0;
                always @(posedge sysclk_i) oserdes_clock_enable <= en_i;                    
                always @(posedge sysclkx2_i) oserdes_clock_enable_x2 <= oserdes_clock_enable;
                OSERDESE2 #(.DATA_RATE_OQ("DDR"),.DATA_WIDTH(4),.SRVAL_OQ(1'b1)) u_oserdes(.CLK(sysclkx2_i),
                                                                                                  .CLKDIV(sysclk_i),
                                                                                                  .RST(rst_i),
                                                                                                  .OCE(oserdes_clock_enable_x2),
                                                                                                  .D1(~oserdes_data[4*i+3]),
                                                                                                  .D2(~oserdes_data[4*i+2]),
                                                                                                  .D3(~oserdes_data[4*i+1]),
                                                                                                  .D4(~oserdes_data[4*i]),
                                                                                                  .OQ(oq_o[i]));
            end                                                                                                  
        end
    endgenerate

endmodule
