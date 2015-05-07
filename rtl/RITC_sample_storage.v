`timescale 1ns / 1ps
module RITC_sample_storage(
		input sysclk_i,
		input sync_i,
		input [47:0] A,
		input [47:0] B,
		input [47:0] C,
		input [47:0] D,
		input [47:0] E,
		input [47:0] F,
		
		input user_clk_i,
		input trig_i,
		input clear_i,
		input [10:0] user_addr_i,
		input user_sel_i,
		input user_rd_i,
		input user_wr_i,
		output [31:0] user_dat_o,
		output sync_latch_o,
		output done_o
    );

	wire [31:0] user_block0_data;
	wire [31:0] user_block1_data;
	wire [31:0] user_block2_data;
	wire [31:0] user_data[3:0];
	// Low 32 bits of R0 data.
	assign user_data[0] = user_block0_data;
	// High word of R0 and R1 data. R0 data is in the low 16 bits.
	assign user_data[1] = user_block1_data;
	// Low 32 bits of R1 data.
	assign user_data[2] = user_block2_data;
	// High word of R0 and R1 data, but reversed so R1 data is in the low 16 bits.
	// Helps with reading out individual RITCs.
	assign user_data[3] = {user_block1_data[15:0],user_block1_data[31:16]};
	assign user_dat_o = user_data[user_addr_i[10:9]];
	
	reg [8:0] write_addr = {9{1'b0}};
	wire [9:0] write_addr_plus_one = write_addr + 1;
	reg [8:0] read_addr = {9{1'b0}};
	reg write_enable = 0;
	reg write_was_enabled = 0;
	reg addr0_sync = 0;
	wire [7:0] byte_write_enable = {8{write_enable}};
	wire [71:0] R0_input = {{24{1'b0}},C,B,A};
	wire [71:0] R1_input = {{24{1'b0}},F,E,D};
	wire [71:0] R0_output;
	wire [71:0] R1_output;
	reg read_enable=0;
	reg write_done=0;
	reg [2:0] write_done_user_clk = {2{1'b0}};
	reg [1:0] addr0_sync_user_clk = {2{1'b0}};
	wire trig_flag_sysclk;
	wire clear_flag_sysclk;
	
	flag_sync u_trig_sync(.in_clkA(trig_i),.clkA(user_clk_i),
								 .out_clkB(trig_flag_sysclk),.clkB(sysclk_i));
	flag_sync u_clear_sync(.in_clkA(clear_i),.clkA(user_clk_i),
								  .out_clkB(clear_flag_sysclk),.clkB(sysclk_i));

	
	always @(posedge sysclk_i) begin
		if (trig_flag_sysclk) write_enable <= 1;
		else if (write_addr_plus_one[9]) write_enable <= 0;
		
		if (write_enable) write_addr <= write_addr_plus_one;
		
		write_was_enabled <= write_enable;
		
		if (write_enable && !write_was_enabled) addr0_sync <= sync_i;
		
		if (trig_flag_sysclk || clear_flag_sysclk) write_done <= 0;
		else if (write_addr_plus_one[9]) write_done <= 1;
	end

	// Multiple reads will automatically increment the address pointer.
	// To read from a specific address, write to it first, then read back.
	always @(posedge user_clk_i) begin
		write_done_user_clk <= {write_done_user_clk[1:0],write_done};
		addr0_sync_user_clk <= {addr0_sync_user_clk[0],addr0_sync};
		if ((write_done_user_clk[1] && !write_done_user_clk[2]) ||
			 (user_sel_i && user_rd_i) ||
			 (user_sel_i && user_wr_i))
				read_enable <= 1;
		else
			read_enable <= 0;
		if (!write_done_user_clk[1]) read_addr <= {9{1'b0}};
		else if (user_sel_i && user_wr_i) read_addr <= user_addr_i[8:0];
		else if (write_done_user_clk[1] && user_sel_i && user_rd_i)
			read_addr <= read_addr + 1;
	end	
	
	BRAM_SDP_MACRO #(.BRAM_SIZE("36Kb"),.DO_REG(0),
						  .READ_WIDTH(72),.WRITE_WIDTH(72))
						  u_R0_storage(.DI(R0_input),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(R0_output),.RDADDR(read_addr),.RDEN(read_enable),.RDCLK(user_clk_i));
	BRAM_SDP_MACRO #(.BRAM_SIZE("36Kb"),.DO_REG(0),
						  .READ_WIDTH(72),.WRITE_WIDTH(72))
						  u_R1_storage(.DI(R1_input),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(R1_output),.RDADDR(read_addr),.RDEN(read_enable),.RDCLK(user_clk_i));
	assign user_block0_data = R0_output[31:0];
	assign user_block1_data = {R1_output[47:32],R0_output[47:32]};
	assign user_block2_data = R1_output[31:0];
	assign done_o = write_done_user_clk[1];
	assign sync_latch_o = addr0_sync_user_clk[1];
endmodule
