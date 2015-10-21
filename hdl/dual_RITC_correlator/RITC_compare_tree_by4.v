`timescale 1ns / 1ps
// Compare-tree. This one compares 4 correlations in each stage,
// yielding a max of 64 in 3 clock cycles.
module RITC_compare_tree_by4(
			clk_i,
			corr_i,
			train_i,
			max_o,
			maxcorr_o
    );

	parameter NUM_CORR = 16;
	parameter NUM_BITS = 12;
    parameter [18:0] TRAINING_PATTERN = 18'h2B7ED;
	input clk_i;
	input [NUM_CORR*NUM_BITS-1:0] corr_i;
	input train_i;
	output [NUM_BITS-1:0] max_o;
	// iterate:
	// i=0; 1 < 64 -> yes, clogb4 = 1
	// i=1; 4 < 64 -> yes, clogb4 = 2
	// i=2; 16 < 64 -> yes, clogb4 = 3
	// i=3; 64 < 64 -> no, clogb4 = 3
	function integer clogb4;
		input [31:0] value;
		integer 	i;
		begin
			clogb4 = 0;
			for(i = 0; 4**i < value; i = i + 1)
				clogb4 = i + 1;
		end
	endfunction
    function integer clogb2;
        input [31:0] value;
        integer i;
        begin
            clogb2 = 0;
            for (i=0;2**i<value;i=i+1) clogb2 = i + 1;
        end
   endfunction
   parameter NUM_CORR_BITS = clogb2(NUM_CORR);
   output [NUM_CORR_BITS-1:0] maxcorr_o;
   
    // for stages=3
    // i=0 number_of_entries += 1
    // i=1 number_of_entries += 4
    // i=2 number_of_entries += 16
    // i=3 number_of_entries += 64	
    function integer number_of_entries;
        input integer stages;
        integer i;
        begin
            number_of_entries = 0;
            for (i=0;i<=stages;i=i+1) number_of_entries = number_of_entries + 4**i;
        end
    endfunction
    
	localparam NUM_STAGES = clogb4(NUM_CORR);
	localparam NUM_CORR_B4 = 4**NUM_STAGES;
	// Sum of all powers-of-4. So for NUM_STAGES=3, this is 85 (64+16+4+1)
    // for NUM_STAGES=2, this is 21 (16+4+1)
    localparam NUM_ENTRIES = number_of_entries(NUM_STAGES);

    // Each stage i has j=4**i comparators.
    // They get their inputs from result_vector[
    wire [NUM_ENTRIES*NUM_BITS-1:0] result_vector;
    // Anything past NUM_CORR*NUM_BITS gets autoassigned to 0, and should get trimmed
    // away. It would be nice to fix this, but shouldn't be that high of a priority.
    assign result_vector[number_of_entries(NUM_STAGES-1)*NUM_BITS +: NUM_CORR*NUM_BITS] = corr_i;
    // 16 corrs has 2 stages.
    // Start with 16 inputs = 16*NBITS inputs
    // next stage has 4*NBITS inputs
    // last stage has NBITS inputs
    // 
    // 64 corrs has 3 stages    inputs                              inputs                                              outputs
    // stage 0: 1 comparator    NBITS +: 4*NBITS                    number_of_entries(i)*NBITS +: 4*NBITS               number_of_entries(i-1)*NBITS +: NBITS
    // stage 1: 4 comparators   5*NBITS + 4*j*NBITS +: 4*NBITS      number_of_entries(i)*NBITS + 4*j*NBITS +: 4*NBITS   number_of_entries(i-1)*NBITS + j*NBITS +: NBITS
    // stage 2: 16 comparators  21*NBITS + 4*j*NBITS +: 4*NBITS     number_of_entries(i)*NBITS + 4*j*NBITS +: 4*NBITS   number_of_entries(i-1)*NBITS + j*NBITS +: NBITS

    // The complicated thing is figuring out the index.
    // Each stage generates 2 new bits in the index:
    // if the first stage compares (0,1,2,3) and (4,5,6,7) and (8,9,10,11) and (12,13,14,15),
    // the first stage generated 2 bits already,
    // and then the next stage picks up 2 new bits, and decides which of the bottom 2 bits to pick up.
    // A comparison of 64 would have to do this with 2 new bits, and 4 old bits.
    // So the first stage (of 16 comparators) needs 2 bits each
    // The second stage (of 4 comparators) needs 4 bits each
    // The 3rd stage (1 comparator) needs 6 bits.

    // stage 0: 2*3*1 = 6
    // stage 1: 2*2*4 = 16
    // stage 2: 2*1*16 = 32
    // = 54 total
    // number_of_index_bits(0,3) = 0
    // number_of_index_bits(1,3) = 2*3*1 = 6
    // number_of_index_bits(2,3) = 2*3*1 + 2*2*4 = 22
    // number_of_index_bits(3,3) = 2*3*1 + 2*2*4 + 2*1*16 = 54
    function integer number_of_index_bits;
        input integer cur_stage;
        input integer max_stage;
        integer i;
        begin
            number_of_index_bits = 0;
            for (i=0;i<cur_stage;i=i+1) begin
                number_of_index_bits = number_of_index_bits + 2*(max_stage-i)*(4**i);
            end
        end
    endfunction
    
    localparam INDEX_BITS = number_of_index_bits(NUM_STAGES, NUM_STAGES);
    wire [INDEX_BITS-1:0] corr_indices;

    (* DONT_TOUCH = "TRUE" *)
    (* EQUIVALENT_REGISTER_REMOVAL = "FALSE" *)
    reg [1:0] local_train = {2{1'b0}};

    always @(posedge clk_i) begin
        local_train <= {local_train[0],train_i};
    end
    
	generate
        genvar stage,comparator;
        for (stage=0;stage < NUM_STAGES; stage = stage + 1) begin : STAGE
            for (comparator=0;comparator < 4**stage;comparator=comparator+1) begin : COMPARATOR
                reg [(NUM_STAGES-stage)*2 - 1 : 0] corr_index = {(NUM_STAGES-stage)*2{1'b0}};
                reg [NUM_BITS-1:0] registered_output = {NUM_BITS{1'b0}};
                wire [4*NUM_BITS-1:0] inputs = result_vector[ number_of_entries(stage)*NUM_BITS+4*comparator*NUM_BITS +: 4*NUM_BITS ];
                wire [NUM_BITS-1:0] max_out;
                wire [1:0] index_out;                              
                fabric_compare_4 #(.NBITS(NUM_BITS)) u_comparator(.GROUP(inputs), .CLK(clk_i),. MAX(max_out),.MAX_INDEX(index_out));
                if (stage == 0) begin : LAST
                    always @(posedge clk_i) begin : LASTOUT
                        if (local_train[1]) registered_output <= TRAINING_PATTERN[0 +: NUM_BITS];
                        else registered_output <= max_out;

                        if (local_train[1]) corr_index <= TRAINING_PATTERN[NUM_BITS +: NUM_CORR_BITS];
                        else begin
                            corr_index[(NUM_STAGES-stage-1)*2 +: 2] <= index_out;
                            // the second part maps to
                            // corr_indices[6+4*index_out +: 4]
                            // for  later stages:
                            // stage 1 is [22+2*index_out +: 2]
                            // stage 2 obviously has no feed up
                            case(index_out)
                                2'b00: corr_index[0 +: (NUM_STAGES-stage-1)*2] <= corr_indices[number_of_index_bits(stage+1, NUM_STAGES) +: (NUM_STAGES-stage-1)*2];
                                2'b01: corr_index[0 +: (NUM_STAGES-stage-1)*2] <= corr_indices[number_of_index_bits(stage+1, NUM_STAGES)+(NUM_STAGES-stage-1)*2 +: (NUM_STAGES-stage-1)*2];
                                2'b10: corr_index[0 +: (NUM_STAGES-stage-1)*2] <= corr_indices[number_of_index_bits(stage+1, NUM_STAGES)+(NUM_STAGES-stage-1)*2*2 +: (NUM_STAGES-stage-1)*2];
                                2'b11: corr_index[0 +: (NUM_STAGES-stage-1)*2] <= corr_indices[number_of_index_bits(stage+1, NUM_STAGES)+(NUM_STAGES-stage-1)*2*3 +: (NUM_STAGES-stage-1)*2];
                            endcase
                        end
                    end
                end else if (stage == (NUM_STAGES-1)) begin : FIRST
                    always @(posedge clk_i) begin : FIRSTOUT
                        registered_output <= max_out;
                        corr_index[(NUM_STAGES-stage-1)*2 +: 2] <= index_out;
                    end
                end else begin : NORMAL
                    always @(posedge clk_i) begin : OUT
                        registered_output <= max_out;                        
                        corr_index[(NUM_STAGES-stage-1)*2 +: 2] <= index_out;
                        // For each stage, you need to start looking at number_of_index_bits(stage+1,NUM_STAGES), with an offset of
                        // 4*comparator*(NUM_STAGES-stage-1)*2 bits
                        // Note that the (NUM_STAGES-stage-1) here is because it's actually 1 stage back -
                        // the other instances of (NUM_STAGES-stage-1)*2 are because the last 2 bits come
                        // from the comparator index. 
                        // For stage 1 this would be starting at 22, with an offset of 4*comparator*1*2 = 8*comparator.                        
                        //
                        // This offset is not present in the last stage because comparator is always 0 there.
                        case(index_out)
                            2'b00: corr_index[0 +: (NUM_STAGES-stage-1)*2] <= corr_indices[number_of_index_bits(stage+1, NUM_STAGES)+4*comparator*(NUM_STAGES-stage-1)*2 +: (NUM_STAGES-stage-1)*2];
                            2'b01: corr_index[0 +: (NUM_STAGES-stage-1)*2] <= corr_indices[number_of_index_bits(stage+1, NUM_STAGES)+4*comparator*(NUM_STAGES-stage-1)*2+(NUM_STAGES-stage-1)*2 +: (NUM_STAGES-stage-1)*2];
                            2'b10: corr_index[0 +: (NUM_STAGES-stage-1)*2] <= corr_indices[number_of_index_bits(stage+1, NUM_STAGES)+4*comparator*(NUM_STAGES-stage-1)*2+(NUM_STAGES-stage-1)*2*2 +: (NUM_STAGES-stage-1)*2];
                            2'b11: corr_index[0 +: (NUM_STAGES-stage-1)*2] <= corr_indices[number_of_index_bits(stage+1, NUM_STAGES)+4*comparator*(NUM_STAGES-stage-1)*2+(NUM_STAGES-stage-1)*2*3 +: (NUM_STAGES-stage-1)*2];
                        endcase
                    end
                end
                assign result_vector[ number_of_entries(stage-1)*NUM_BITS + comparator*NUM_BITS +: NUM_BITS ] = registered_output;
                // Now assign the feed-up portion.               
                // for stage 0 this starts at 0 and is 6 bits long. 
                // For stage 1, this starts at 6, with an offset of 4 for every comparator, with each one being 4 bits long.
                // For stage 2, this starts at 22, with an offset of 2 for every comparator, with each one being 2 bits long.
                assign corr_indices[number_of_index_bits(stage, NUM_STAGES)+(NUM_STAGES-stage)*2*comparator +: (NUM_STAGES-stage)*2] = corr_index;
            end
        end        
	endgenerate
	
	assign max_o = result_vector[0 +: NUM_BITS];
    assign maxcorr_o = corr_indices[0 +: NUM_CORR_BITS];
    
endmodule
