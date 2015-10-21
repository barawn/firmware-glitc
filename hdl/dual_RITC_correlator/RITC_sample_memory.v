`timescale 1ns / 1ps
module RITC_sample_memory(
        input clk_i,
        input [47:0] A,
        input [47:0] B,
        input [47:0] C,
        input [47:0] D,
        input [47:0] E,
        input [47:0] F,
        input [9:0] waddr_i,
        input active_i,
        input trigger_i,
        input we_i,
        
        input rd_clk_i,
        input [13:0] raddr_i,
        input en_i,
        output [31:0] dat_o        
    );
    
    // Top 3 addresses define which channels you're reading from.
    // Bottom address defines first 8 or last 8.
    // raddr_i[10:9] is the buffer you're reading from
    // raddr_i[8:1] is the sample address.
    
    wire [35:0] user_block_data[15:0];
    assign dat_o = user_block_data[{raddr_i[13:11],raddr_i[0]}][31:0];

    `define BRAM BRAM_SDP_MACRO #(.BRAM_SIZE("36Kb"),.DO_REG(0),.READ_WIDTH(36),.WRITE_WIDTH(36))
    
    // The A and D early blocks also contain the active_i/trigger_i indicators to tell you where
    // the trigger occurred in the data.
    `BRAM u_a0(.DI({4'b0000,active_i,trigger_i,{6{1'b0}},A[0 +: 24]}),.WRADDR(waddr_i),.WE({8{1'b1}}),.WREN(we_i),.WRCLK(clk_i),
               .DO(user_block_data[0]),.RDADDR(raddr_i[10:1]),.RDEN(en_i),.RDCLK(rd_clk_i));
    `BRAM u_a1(.DI({{12{1'b0}},A[24 +: 24]}),.WRADDR(waddr_i),.WE({8{1'b1}}),.WREN(we_i),.WRCLK(clk_i),
               .DO(user_block_data[1]),.RDADDR(raddr_i[10:1]),.RDEN(en_i),.RDCLK(rd_clk_i));
    `BRAM u_b0(.DI({{12{1'b0}},B[0 +: 24]}),.WRADDR(waddr_i),.WE({8{1'b1}}),.WREN(we_i),.WRCLK(clk_i),
               .DO(user_block_data[2]),.RDADDR(raddr_i[10:1]),.RDEN(en_i),.RDCLK(rd_clk_i));
    `BRAM u_b1(.DI({{12{1'b0}},B[24 +: 24]}),.WRADDR(waddr_i),.WE({8{1'b1}}),.WREN(we_i),.WRCLK(clk_i),
               .DO(user_block_data[3]),.RDADDR(raddr_i[10:1]),.RDEN(en_i),.RDCLK(rd_clk_i));
    `BRAM u_c0(.DI({{12{1'b0}},C[0 +: 24]}),.WRADDR(waddr_i),.WE({8{1'b1}}),.WREN(we_i),.WRCLK(clk_i),
               .DO(user_block_data[4]),.RDADDR(raddr_i[10:1]),.RDEN(en_i),.RDCLK(rd_clk_i));
    `BRAM u_c1(.DI({{12{1'b0}},C[24 +: 24]}),.WRADDR(waddr_i),.WE({8{1'b1}}),.WREN(we_i),.WRCLK(clk_i),
               .DO(user_block_data[5]),.RDADDR(raddr_i[10:1]),.RDEN(en_i),.RDCLK(rd_clk_i));
    `BRAM u_d0(.DI({4'b0000,active_i,trigger_i,{6{1'b0}},D[0 +: 24]}),.WRADDR(waddr_i),.WE({8{1'b1}}),.WREN(we_i),.WRCLK(clk_i),
               .DO(user_block_data[6]),.RDADDR(raddr_i[10:1]),.RDEN(en_i),.RDCLK(rd_clk_i));
    `BRAM u_d1(.DI({{12{1'b0}},D[24 +: 24]}),.WRADDR(waddr_i),.WE({8{1'b1}}),.WREN(we_i),.WRCLK(clk_i),
               .DO(user_block_data[7]),.RDADDR(raddr_i[10:1]),.RDEN(en_i),.RDCLK(rd_clk_i));
    `BRAM u_e0(.DI({{12{1'b0}},E[0 +: 24]}),.WRADDR(waddr_i),.WE({8{1'b1}}),.WREN(we_i),.WRCLK(clk_i),
               .DO(user_block_data[8]),.RDADDR(raddr_i[10:1]),.RDEN(en_i),.RDCLK(rd_clk_i));
    `BRAM u_e1(.DI({{12{1'b0}},E[24 +: 24]}),.WRADDR(waddr_i),.WE({8{1'b1}}),.WREN(we_i),.WRCLK(clk_i),
               .DO(user_block_data[9]),.RDADDR(raddr_i[10:1]),.RDEN(en_i),.RDCLK(rd_clk_i));
    `BRAM u_f0(.DI({{12{1'b0}},F[0 +: 24]}),.WRADDR(waddr_i),.WE({8{1'b1}}),.WREN(we_i),.WRCLK(clk_i),
               .DO(user_block_data[10]),.RDADDR(raddr_i[10:1]),.RDEN(en_i),.RDCLK(rd_clk_i));
    `BRAM u_f1(.DI({{12{1'b0}},F[24 +: 24]}),.WRADDR(waddr_i),.WE({8{1'b1}}),.WREN(we_i),.WRCLK(clk_i),
               .DO(user_block_data[11]),.RDADDR(raddr_i[10:1]),.RDEN(en_i),.RDCLK(rd_clk_i));
    assign user_block_data[12] = user_block_data[4];
    assign user_block_data[13] = user_block_data[5];
    assign user_block_data[14] = user_block_data[6];
    assign user_block_data[15] = user_block_data[7];
    
    `undef BRAM
    
endmodule
