// Version 11 of the correlation.
//
// There are 3 types of correlations defined here: typeA, typeB, typeC.
// TypeA's 4 correlations are offset by 0/0/0, 0/0/-1, 0/-1/-1, 0/-1/-2
// TypeB's 4 correlations are offset by 0/0/0, 0/0/-1, 0/0/-2,  0/-1/-2
// TypeC's 4 correlations are offset by 0/0/0, 0/-1/0, 0/-1/-1, 0/-1/-2
//
// Each correlation has a fixed input structure.
// clk
// sync
// 48 A inputs
// 48 B inputs
// 48 C inputs
// 1 cdi input
// 1 ce input
// 11 corr0 outputs
// 12 ped0 inputs
// 11 corr1 outputs
// 12 ped1 inputs
// 11 corr2 outputs
// 12 ped2 inputs
// 11 corr3 outputs
// 12 ped3 inputs
//
// Note that with INL correction, the maximum value is now 3976, and all of those bits
// are possible.
// Therefore we output a pure 12-bit number for the correlation.
// This therefore only works with the v3 intercom, which uses:
// 12 bits for power
// 6 bits for correlation
// 2 bits for commanding
//

// Base module. This is done this way because parametrized modules lose their heirarchy.
module quad_corr_v11_base(
		clk,
		sync,
        cdi,
        ce,
        ped_clk_i,
        ped_rst_i,
        ped_i,
        ped_update_i,        
		A,B,C,
		CORR0,
		CORR1,
		CORR2,
		CORR3
    );

	//% How many cycles to delay the output, if any.
	parameter DELAY = 0;
	//% Number of samples in a cycle.
	parameter DEMUX = 16;
	//% Number of bits in each sample.
	parameter INBITS = 3;
	//% Number of corrected bits in each sample.
	parameter NBITS = 6;

	//% Number of bits in (A+B+C)^2 in each sample.
	parameter ADDSQBITS = 7;
	//% Number of carry outputs in total.
	parameter NCARRYBITS = 4;
	//% Number of correlations in this module.
	parameter NCORRS = 4;
	
	//% Number of bits to output from the correlation.
	parameter POWERBITS = 12;

    //% Type of correlation.
    parameter TYPE = "TYPEA";

	//% Total number of corrected bits in an individual channel.
	localparam NCBITS = DEMUX*NBITS;
	//% Total number of bits in an (A+B+C)^2 output.
	localparam NSQBITS = DEMUX*ADDSQBITS;

	//% Number of bits in a DSP input.
	localparam NDSPBITS = 12;

	//% A inputs.
	input [DEMUX*INBITS-1:0] A;
	//% B inputs.
	input [DEMUX*INBITS-1:0] B;
	//% C inputs.
	input [DEMUX*INBITS-1:0] C;
	
	//% Local sync storage.
	(* EQUIVALENT_REGISTER_REMOVAL = "NO" *)
	(* DONT_TOUCH = "TRUE" *)
	reg local_sync = 0;
	
	//% Corrected A inputs.
	wire [NCBITS-1:0] A_corr;
	//% Corrected B inputs.
	wire [NCBITS-1:0] B_corr;
	//% Corrected C inputs.
	wire [NCBITS-1:0] C_corr;

	//% Stored B input (to allow for -1 offset).
	reg [NBITS-1:0] B_store = {NBITS{1'b0}};
	//% First stored C input.
	reg [NBITS-1:0] C_store_1 = {NBITS{1'b0}};
	//% Second stored C input.
	reg [NBITS-1:0] C_store_2 = {NBITS{1'b0}};
	
	//% Correlation 0 inputs.
	wire [NCBITS-1:0] A0;
	wire [NCBITS-1:0] B0;
	wire [NCBITS-1:0] C0;
	
	//% Correlation 1 inputs.
	wire [NCBITS-1:0] A1;
	wire [NCBITS-1:0] B1;
	wire [NCBITS-1:0] C1;
	
	//% Correlation 2 inputs.
	wire [NCBITS-1:0] A2;
	wire [NCBITS-1:0] B2;
	wire [NCBITS-1:0] C2;
	
	//% Correlation 3 inputs. 0/-1/-2.
	wire [NCBITS-1:0] A3;
	wire [NCBITS-1:0] B3;
	wire [NCBITS-1:0] C3;
	
	//% Correlation 0 inputs.
	assign A0 = A_corr;
	assign B0 = B_corr;
	assign C0 = C_corr;
	
	generate
	   if (TYPE == "TYPEA") begin : A
            //% Correlation 1 inputs.
            assign A1 = A_corr;
            assign B1 = B_corr;
            assign C1 = {C_store_1,C_corr[NBITS +: (NCBITS-NBITS)]};
        
            //% Correlation 2 inputs. 0/-1/-1
            assign A2 = A_corr;
            assign B2 = {B_store,B_corr[NBITS +: (NCBITS-NBITS)]};
            assign C2 = {C_store_1,C_corr[NBITS +: (NCBITS-NBITS)]};
        
            //% Correlation 3 inputs. 0/-1/-2.
            assign A3 = A_corr;
            assign B3 = {B_store,B_corr[NBITS +: (NCBITS-NBITS)]};
            assign C3 = {C_store_2,C_store_1,C_corr[NBITS*2 +: (NCBITS-2*NBITS)]};
       end else if (TYPE == "TYPEB") begin : B
           //% Correlation 0 inputs.
           assign A0 = A_corr;
           assign B0 = B_corr;
           assign C0 = C_corr;
           
           //% Correlation 1 inputs. 0/0/-1.
           assign A1 = A_corr;
           assign B1 = B_corr;
           assign C1 = {C_store_1,C_corr[NBITS +: (NCBITS-NBITS)]};
       
           //% Correlation 2 inputs. 0/0/-2
           assign A2 = A_corr;
           assign B2 = B_corr;
           assign C2 = {C_store_2,C_store_1,C_corr[NBITS*2 +: (NCBITS-2*NBITS)]};
       
           //% Correlation 3 inputs. 0/-1/-2.
           assign A3 = A_corr;
           assign B3 = {B_store,B_corr[NBITS +: (NCBITS-NBITS)]};
           assign C3 = {C_store_2,C_store_1,C_corr[NBITS*2 +: (NCBITS-2*NBITS)]};
      end else if (TYPE === "TYPEC") begin : C
          //% Correlation 0 inputs.
          assign A0 = A_corr;
          assign B0 = B_corr;
          assign C0 = C_corr;
          
          //% Correlation 1 inputs. 0/-1/0.
          assign A1 = A_corr;
          assign B1 = {B_store,B_corr[NBITS +: (NCBITS-NBITS)]};
          assign C1 = C_corr;
          
          //% Correlation 2 inputs. 0/-1/-1
          assign A2 = A_corr;
          assign B2 = {B_store,B_corr[NBITS +: (NCBITS-NBITS)]};
          assign C2 = {C_store_1,C_corr[NBITS +: (NCBITS-NBITS)]};
      
          //% Correlation 3 inputs. 0/-1/-2.
          assign A3 = A_corr;
          assign B3 = {B_store,B_corr[NBITS +: (NCBITS-NBITS)]};
          assign C3 = {C_store_2,C_store_1,C_corr[NBITS*2 +: (NCBITS-2*NBITS)]};
      end
    endgenerate      
	
	//% Correlation 0 output.
	output [POWERBITS-1:0] CORR0;
	//% Correlation 1 output.
	output [POWERBITS-1:0] CORR1;
	//% Correlation 2 output.
	output [POWERBITS-1:0] CORR2;
	//% Correlation 3 output.
	output [POWERBITS-1:0] CORR3;
	
	input clk;
	input sync;
	input cdi;
    input ce;
	
	input ped_rst_i;
	input [47:0] ped_i;
	input ped_update_i;
	input ped_clk_i;

	//% Vectorized A inputs.
	wire [NCBITS-1:0] AV[NCORRS-1:0];
	//% Vectorized B inputs.
	wire [NCBITS-1:0] BV[NCORRS-1:0];
	//% Vectorized C inputs.
	wire [NCBITS-1:0] CV[NCORRS-1:0];
	//% Outputs from the add/square modules.
	wire [NSQBITS-1:0] ADDSQ[NCORRS-1:0];
	//% Carry outputs from add/square modules.
	wire [NCARRYBITS-1:0] CARRY[NCORRS-1:0];
	
	// We have 7 stages of DSPs.
	
	//% DSP stage inputs. (2 inputs from each correlation)
	wire [NDSPBITS-1:0] DSP_INPUT[6:0][7:0];
	//% DSP stage cascade (no output cascade).
	wire [47:0] DSP_CASCADE[5:0];
	//% Direct DSP outputs. Only 3 of these since just the second part has them connected. Only 1 of these is used.
	wire [NDSPBITS-1:0] DSP_OUTPUT[2:0][3:0];
	//% Final-stage outputs.
	wire [NDSPBITS-1:0] DSP_SUM[3:0];

	`define VECTORIZE( x ) \
		assign x``V [0] = x``0; \
		assign x``V [1] = x``1; \
		assign x``V [2] = x``2; \
		assign x``V [3] = x``3
	
	`VECTORIZE(A);
	`VECTORIZE(B);
	`VECTORIZE(C);
	
	//% Pedestal reset signal in sysclk domain
	wire ped_rst_sysclk;
	//% Pedestal update signal in sysclk domain
	wire ped_update_sysclk;
	
	flag_sync u_pedrst_sync(.in_clkA(ped_rst_i),.clkA(ped_clk_i),
	                        .out_clkB(ped_rst_sysclk),.clkB(clk_i));
    flag_sync u_pedupdate_sync(.in_clkA(ped_update_i),.clkA(ped_clk_i),
                               .out_clkB(ped_update_sysclk),.clkB(clk_i));	                        

    //% Generate a local copy of sync. Sync toggles every cycle, so delay by 1 and invert, and there's your copy.
	always @(posedge clk) local_sync <= ~sync;
	
	RITC_dynamic_corrector_v3 u_corrector(.sync_i(local_sync),.A(A),.B(B),.C(C),
														      .AC(A_corr),.BC(B_corr),.CC(C_corr),
															  .sysclk_i(clk),.cdi_i(cdi),.ce_i(ce));

	//% Now the actual correlators.
	generate
		genvar i,j;
		for (i=0;i<NCORRS;i=i+1) begin : CORR
			add_and_square_v8 u_addsq(.A(AV[i]),.B(BV[i]),.C(CV[i]),.OUT(ADDSQ[i]),.CARRY(CARRY[i]),.clk(clk));
			partition_and_preadd_v8 #(.INBITS(ADDSQBITS)) u_partition( .clk(clk), .IN(ADDSQ[i]),.CARRYIN(CARRY[i]),
															 .STAGE1A(DSP_INPUT[0][2*i+0]),.STAGE1B(DSP_INPUT[0][2*i+1]),
															 .STAGE2A(DSP_INPUT[1][2*i+0]),.STAGE2B(DSP_INPUT[1][2*i+1]),
															 .STAGE3A(DSP_INPUT[2][2*i+0]),.STAGE3B(DSP_INPUT[2][2*i+1]),
															 .STAGE4A(DSP_INPUT[3][2*i+0]),.STAGE4B(DSP_INPUT[3][2*i+1]),
															 .STAGE5A(DSP_INPUT[4][2*i+0]),.STAGE5B(DSP_INPUT[4][2*i+1]),
															 .STAGE6A(DSP_INPUT[5][2*i+0]),.STAGE6B(DSP_INPUT[5][2*i+1]));
		end
		// The first 6 stages of DSP are identical in groups of 2 (i.e. 1&2, 3&4, 5&6) except that stage6's
		// outputs are needed, and stage1 doesn't add its cascade. Additionally every stage past 1&2 uses
		// a single input register.
		for (j=0;j<3;j=j+1) begin : DSP
			if (j == 0) begin : HEAD
				quad_dsp_sum #(.ADD_CASCADE(0),.INPUT_REG(0),.OUTPUT_REG(0)) 
					 u_pair_0( .A(DSP_INPUT[2*j + 0][0]), .B(DSP_INPUT[2*j + 0][1]),
								  .C(DSP_INPUT[2*j + 0][2]), .D(DSP_INPUT[2*j + 0][3]),
								  .E(DSP_INPUT[2*j + 0][4]), .F(DSP_INPUT[2*j + 0][5]),
								  .G(DSP_INPUT[2*j + 0][6]), .H(DSP_INPUT[2*j + 0][7]),
								  .CASC_OUT(DSP_CASCADE[2*j + 0]),
								  .CLK(clk));
			end else begin : BODY
				quad_dsp_sum #(.ADD_CASCADE(1),.INPUT_REG(1),.OUTPUT_REG(0)) 
					 u_pair_0( .A(DSP_INPUT[2*j + 0][0]), .B(DSP_INPUT[2*j + 0][1]),
								  .C(DSP_INPUT[2*j + 0][2]), .D(DSP_INPUT[2*j + 0][3]),
								  .E(DSP_INPUT[2*j + 0][4]), .F(DSP_INPUT[2*j + 0][5]),
								  .G(DSP_INPUT[2*j + 0][6]), .H(DSP_INPUT[2*j + 0][7]),
								  .CASC_IN(DSP_CASCADE[2*(j-1) + 1]),
								  .CASC_OUT(DSP_CASCADE[2*j + 0]),
								  .CLK(clk));
			end
			quad_dsp_sum #(.ADD_CASCADE(1), .INPUT_REG( (j!=0) ? 1 : 0), .OUTPUT_REG(1))
				 u_pair_1( .A(DSP_INPUT[2*j + 1][0]), .B(DSP_INPUT[2*j + 1][1]),
							  .C(DSP_INPUT[2*j + 1][2]), .D(DSP_INPUT[2*j + 1][3]),
							  .E(DSP_INPUT[2*j + 1][4]), .F(DSP_INPUT[2*j + 1][5]),
							  .G(DSP_INPUT[2*j + 1][6]), .H(DSP_INPUT[2*j + 1][7]),
							  .APB(DSP_OUTPUT[j][0]),
							  .CPD(DSP_OUTPUT[j][1]),
							  .EPF(DSP_OUTPUT[j][2]),
							  .GPH(DSP_OUTPUT[j][3]),
							  .CASC_IN(DSP_CASCADE[2*j + 0]),
							  .CASC_OUT(DSP_CASCADE[2*j + 1]),
							  .CLK(clk));
		end			
	endgenerate
	
	assign DSP_INPUT[6][0] = DSP_OUTPUT[2][0];
	// This is the constant term (the value to be subtracted off, if desired).
	assign DSP_INPUT[6][1] = ped_i[0 +: 12];

	assign DSP_INPUT[6][2] = DSP_OUTPUT[2][1];
	// This is the constant term (the value to be subtracted off, if desired).
	assign DSP_INPUT[6][3] = ped_i[12 +: 12];

	assign DSP_INPUT[6][4] = DSP_OUTPUT[2][2];
	// This is the constant term (the value to be subtracted off, if desired).
	assign DSP_INPUT[6][5] = ped_i[24 +: 12];

	assign DSP_INPUT[6][6] = DSP_OUTPUT[2][3];
	// This is the constant term (the value to be subtracted off, if desired).
	assign DSP_INPUT[6][7] = ped_i[36 +: 12];
	
	
	quad_dsp_sum_with_pedestal #(.ADD_CASCADE(1), .INPUT_REG(1) ,.OUTPUT_REG(1))
		u_final_dsp( .A(DSP_INPUT[6][0]), .APED(DSP_INPUT[6][1]),
						 .C(DSP_INPUT[6][2]), .CPED(DSP_INPUT[6][3]),
						 .E(DSP_INPUT[6][4]), .EPED(DSP_INPUT[6][5]),
						 .G(DSP_INPUT[6][6]), .GPED(DSP_INPUT[6][7]),
						 .ped_rst_i(ped_rst_sysclk),
						 .ped_update_i(ped_update_sysclk),
						 .APB(DSP_SUM[0]),
						 .CPD(DSP_SUM[1]),
						 .EPF(DSP_SUM[2]),
						 .GPH(DSP_SUM[3]),
						 .CASC_IN(DSP_CASCADE[5]),
						 .CLK(clk));
	assign CORR0 = DSP_SUM[0][0 +: POWERBITS];
	assign CORR1 = DSP_SUM[1][0 +: POWERBITS];
	assign CORR2 = DSP_SUM[2][0 +: POWERBITS];
	assign CORR3 = DSP_SUM[3][0 +: POWERBITS];

endmodule

module quad_corr_v11_typeA(
		clk,
		sync,
        cdi,
        ce,        
        ped_clk_i,
        ped_rst_i,
        ped_i,
        ped_update_i,        
		A,B,C,
		CORR0,
		CORR1,
		CORR2,
		CORR3
    );

	//% How many cycles to delay the output, if any.
	parameter DELAY = 0;
	//% Number of samples in a cycle.
	parameter DEMUX = 16;
	//% Number of bits in each sample.
	parameter INBITS = 3;
	//% Number of corrected bits in each sample.
	parameter NBITS = 6;

	//% Number of bits in (A+B+C)^2 in each sample.
	parameter ADDSQBITS = 7;
	//% Number of carry outputs in total.
	parameter NCARRYBITS = 4;
	//% Number of correlations in this module.
	parameter NCORRS = 4;
	
	//% Number of bits to output from the correlation.
	parameter POWERBITS = 12;

    input clk;
    input sync;
    input cdi;
    input ce;

	input ped_rst_i;
	input [47:0] ped_i;
	input ped_update_i;
	input ped_clk_i;

	//% A inputs.
	input [DEMUX*INBITS-1:0] A;
	//% B inputs.
	input [DEMUX*INBITS-1:0] B;
	//% C inputs.
	input [DEMUX*INBITS-1:0] C;

	//% Correlation 0 output.
	output [POWERBITS-1:0] CORR0;
	//% Correlation 1 output.
	output [POWERBITS-1:0] CORR1;
	//% Correlation 2 output.
	output [POWERBITS-1:0] CORR2;
	//% Correlation 3 output.
	output [POWERBITS-1:0] CORR3;

    quad_corr_v11_base #(.DELAY(DELAY),.DEMUX(DEMUX),.INBITS(INBITS),.NBITS(NBITS),.ADDSQBITS(ADDSQBITS),.NCARRYBITS(NCARRYBITS),.NCORRS(NCORRS),.POWERBITS(POWERBITS),.TYPE("TYPEA"))
        u_typeA(.clk(clk),.sync(sync),.cdi(cdi),.ce(ce),.A(A),.B(B),.C(C),.CORR0(CORR0),.CORR1(CORR1),.CORR2(CORR2),.CORR3(CORR3),.ped_clk_i(ped_clk_i),.ped_rst_i(ped_rst_i),.ped_i(ped_i),.ped_update_i(ped_update_i));
        
endmodule

module quad_corr_v11_typeB(
		clk,
		sync,
        cdi,
        ce,        
        ped_clk_i,
        ped_rst_i,
        ped_i,
        ped_update_i,        
		A,B,C,
		CORR0,
		CORR1,
		CORR2,
		CORR3
    );

	//% How many cycles to delay the output, if any.
	parameter DELAY = 0;
	//% Number of samples in a cycle.
	parameter DEMUX = 16;
	//% Number of bits in each sample.
	parameter INBITS = 3;
	//% Number of corrected bits in each sample.
	parameter NBITS = 6;

	//% Number of bits in (A+B+C)^2 in each sample.
	parameter ADDSQBITS = 7;
	//% Number of carry outputs in total.
	parameter NCARRYBITS = 4;
	//% Number of correlations in this module.
	parameter NCORRS = 4;
	
	//% Number of bits to output from the correlation.
	parameter POWERBITS = 12;

    input clk;
    input sync;
    input cdi;
    input ce;

	input ped_rst_i;
	input [47:0] ped_i;
	input ped_update_i;
	input ped_clk_i;

	//% A inputs.
	input [DEMUX*INBITS-1:0] A;
	//% B inputs.
	input [DEMUX*INBITS-1:0] B;
	//% C inputs.
	input [DEMUX*INBITS-1:0] C;

	//% Correlation 0 output.
	output [POWERBITS-1:0] CORR0;
	//% Correlation 1 output.
	output [POWERBITS-1:0] CORR1;
	//% Correlation 2 output.
	output [POWERBITS-1:0] CORR2;
	//% Correlation 3 output.
	output [POWERBITS-1:0] CORR3;

    quad_corr_v11_base #(.DELAY(DELAY),.DEMUX(DEMUX),.INBITS(INBITS),.NBITS(NBITS),.ADDSQBITS(ADDSQBITS),.NCARRYBITS(NCARRYBITS),.NCORRS(NCORRS),.POWERBITS(POWERBITS),.TYPE("TYPEB"))
        u_typeB(.clk(clk),.sync(sync),.cdi(cdi),.ce(ce),.A(A),.B(B),.C(C),.CORR0(CORR0),.CORR1(CORR1),.CORR2(CORR2),.CORR3(CORR3),.ped_clk_i(ped_clk_i),.ped_rst_i(ped_rst_i),.ped_i(ped_i),.ped_update_i(ped_update_i));
    
endmodule

module quad_corr_v11_typeC(
		clk,
		sync,
        cdi,
        ce,        
        ped_clk_i,
        ped_rst_i,
        ped_i,
        ped_update_i,        
		A,B,C,
		CORR0,
		CORR1,
		CORR2,
		CORR3
    );

	//% How many cycles to delay the output, if any.
	parameter DELAY = 0;
	//% Number of samples in a cycle.
	parameter DEMUX = 16;
	//% Number of bits in each sample.
	parameter INBITS = 3;
	//% Number of corrected bits in each sample.
	parameter NBITS = 6;

	//% Number of bits in (A+B+C)^2 in each sample.
	parameter ADDSQBITS = 7;
	//% Number of carry outputs in total.
	parameter NCARRYBITS = 4;
	//% Number of correlations in this module.
	parameter NCORRS = 4;
	
	//% Number of bits to output from the correlation.
	parameter POWERBITS = 12;

    input clk;
    input sync;
    input cdi;
    input ce;

	input ped_rst_i;
	input [47:0] ped_i;
	input ped_update_i;
	input ped_clk_i;

	//% A inputs.
	input [DEMUX*INBITS-1:0] A;
	//% B inputs.
	input [DEMUX*INBITS-1:0] B;
	//% C inputs.
	input [DEMUX*INBITS-1:0] C;

	//% Correlation 0 output.
	output [POWERBITS-1:0] CORR0;
	//% Correlation 1 output.
	output [POWERBITS-1:0] CORR1;
	//% Correlation 2 output.
	output [POWERBITS-1:0] CORR2;
	//% Correlation 3 output.
	output [POWERBITS-1:0] CORR3;

    quad_corr_v11_base #(.DELAY(DELAY),.DEMUX(DEMUX),.INBITS(INBITS),.NBITS(NBITS),.ADDSQBITS(ADDSQBITS),.NCARRYBITS(NCARRYBITS),.NCORRS(NCORRS),.POWERBITS(POWERBITS),.TYPE("TYPEC"))
        u_typeC(.clk(clk),.sync(sync),.cdi(cdi),.ce(ce),.A(A),.B(B),.C(C),.CORR0(CORR0),.CORR1(CORR1),.CORR2(CORR2),.CORR3(CORR3),.ped_clk_i(ped_clk_i),.ped_rst_i(ped_rst_i),.ped_i(ped_i),.ped_update_i(ped_update_i));
    
endmodule
