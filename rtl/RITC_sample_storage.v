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

	wire [31:0] user_block_data[7:0];
	assign user_dat_o = user_block_data[user_addr_i[10:8]];
	
	reg [8:0] write_addr = {9{1'b0}};
	wire [9:0] write_addr_plus_one = write_addr + 1;
	reg [9:0] read_addr = {10{1'b0}};
	reg write_enable = 0;
	reg write_was_enabled = 0;
	reg addr0_sync = 0;
	wire [7:0] byte_write_enable = {8{write_enable}};
	
	wire [35:0] A_output[1:0];
	wire [35:0] B_output[1:0];
	wire [35:0] C_output[1:0];
	wire [35:0] D_output[1:0];
	wire [35:0] E_output[1:0];
	wire [35:0] F_output[1:0];
	
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
		if (!write_done_user_clk[1]) read_addr <= {10{1'b0}};
		else if (user_sel_i && user_wr_i) read_addr <= user_addr_i[9:0];
		else if (write_done_user_clk[1] && user_sel_i && user_rd_i)
			read_addr <= read_addr + 1;
	end	
	
	BRAM_SDP_MACRO #(.BRAM_SIZE("18Kb"),.DO_REG(0),
						  .READ_WIDTH(36),.WRITE_WIDTH(36))
						  u_A0_storage(.DI({{12{1'b0}},A[23:0]}),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(A_output[0]),.RDADDR(read_addr[9:1]),.RDEN(read_enable),.RDCLK(user_clk_i));
	BRAM_SDP_MACRO #(.BRAM_SIZE("18Kb"),.DO_REG(0),
						  .READ_WIDTH(36),.WRITE_WIDTH(36))
						  u_A1_storage(.DI({{12{1'b0}},A[47:24]}),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(A_output[1]),.RDADDR(read_addr[9:1]),.RDEN(read_enable),.RDCLK(user_clk_i));
	
	BRAM_SDP_MACRO #(.BRAM_SIZE("18Kb"),.DO_REG(0),
						  .READ_WIDTH(36),.WRITE_WIDTH(36))
						  u_B0_storage(.DI({{12{1'b0}},B[23:0]}),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(B_output[0]),.RDADDR(read_addr[9:1]),.RDEN(read_enable),.RDCLK(user_clk_i));
	BRAM_SDP_MACRO #(.BRAM_SIZE("18Kb"),.DO_REG(0),
						  .READ_WIDTH(36),.WRITE_WIDTH(36))
						  u_B1_storage(.DI({{12{1'b0}},B[47:24]}),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(B_output[1]),.RDADDR(read_addr[9:1]),.RDEN(read_enable),.RDCLK(user_clk_i));
	
	BRAM_SDP_MACRO #(.BRAM_SIZE("18Kb"),.DO_REG(0),
						  .READ_WIDTH(36),.WRITE_WIDTH(36))
						  u_C0_storage(.DI({{12{1'b0}},C[23:0]}),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(C_output[0]),.RDADDR(read_addr[9:1]),.RDEN(read_enable),.RDCLK(user_clk_i));
	BRAM_SDP_MACRO #(.BRAM_SIZE("18Kb"),.DO_REG(0),
						  .READ_WIDTH(36),.WRITE_WIDTH(36))
						  u_C1_storage(.DI({{12{1'b0}},C[47:24]}),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(C_output[1]),.RDADDR(read_addr[9:1]),.RDEN(read_enable),.RDCLK(user_clk_i));
	
	BRAM_SDP_MACRO #(.BRAM_SIZE("18Kb"),.DO_REG(0),
						  .READ_WIDTH(36),.WRITE_WIDTH(36))
						  u_D0_storage(.DI({{12{1'b0}},D[23:0]}),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(D_output[0]),.RDADDR(read_addr[9:1]),.RDEN(read_enable),.RDCLK(user_clk_i));
	BRAM_SDP_MACRO #(.BRAM_SIZE("18Kb"),.DO_REG(0),
						  .READ_WIDTH(36),.WRITE_WIDTH(36))
						  u_D1_storage(.DI({{12{1'b0}},D[47:24]}),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(D_output[1]),.RDADDR(read_addr[9:1]),.RDEN(read_enable),.RDCLK(user_clk_i));
	
	BRAM_SDP_MACRO #(.BRAM_SIZE("18Kb"),.DO_REG(0),
						  .READ_WIDTH(36),.WRITE_WIDTH(36))
						  u_E0_storage(.DI({{12{1'b0}},E[23:0]}),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(E_output[0]),.RDADDR(read_addr[9:1]),.RDEN(read_enable),.RDCLK(user_clk_i));
	BRAM_SDP_MACRO #(.BRAM_SIZE("18Kb"),.DO_REG(0),
						  .READ_WIDTH(36),.WRITE_WIDTH(36))
						  u_E1_storage(.DI({{12{1'b0}},E[47:24]}),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(E_output[1]),.RDADDR(read_addr[9:1]),.RDEN(read_enable),.RDCLK(user_clk_i));
	
	BRAM_SDP_MACRO #(.BRAM_SIZE("18Kb"),.DO_REG(0),
						  .READ_WIDTH(36),.WRITE_WIDTH(36))
						  u_F0_storage(.DI({{12{1'b0}},F[23:0]}),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(F_output[0]),.RDADDR(read_addr[9:1]),.RDEN(read_enable),.RDCLK(user_clk_i));
	BRAM_SDP_MACRO #(.BRAM_SIZE("18Kb"),.DO_REG(0),
						  .READ_WIDTH(36),.WRITE_WIDTH(36))
						  u_F1_storage(.DI({{12{1'b0}},F[47:24]}),.WRADDR(write_addr),.WE(byte_write_enable),.WREN(write_enable),.WRCLK(sysclk_i),
											.DO(F_output[1]),.RDADDR(read_addr[9:1]),.RDEN(read_enable),.RDCLK(user_clk_i));
	
											
	// Pull off the bottom 24 bits that contain 8 3-bit samples										
	assign user_block_data[0] = A_output[read_addr[0]][24:0];
	assign user_block_data[1] = B_output[read_addr[0]][24:0];
	assign user_block_data[2] = C_output[read_addr[0]][24:0];
	assign user_block_data[3] = D_output[read_addr[0]][24:0];
	assign user_block_data[4] = E_output[read_addr[0]][24:0];
	assign user_block_data[5] = F_output[read_addr[0]][24:0];
	assign user_block_data[6] = C_output[read_addr[0]][24:0];
	assign user_block_data[7] = D_output[read_addr[0]][24:0];

	assign done_o = write_done_user_clk[1];
	assign sync_latch_o = addr0_sync_user_clk[1];
endmodule
