`timescale 1ns / 1ps

//% Version 2 of the RITC sample storage module.
//%
//% This is a more full-featured module: the control is now inside this module,
//% it now contains a pretrigger and a viable external trigger. It also contains
//% a "training view" and an autoclear function, as well as the dynamic INL correction.
//% It also contains pedestal control for the correlator. So I may actually export this
//% to a separate "dual_RITC_correlator_control" module for clean separation.
//%
//% Each buffer is 256 (162.5 MHz) samples (= 4096 2.6 GSa/s samples) long
//% There are 2 reads needed per channel per sample (24 bits per read)
//% Yielding a total length of 512*6 = 3072 reads needed for a full sample.
module RITC_sample_storage_v2(
        input user_clk_i,
        input user_wr_i,
        input user_rd_i,
        input user_sel_i,
        input sample_sel_i,
        input [11:0] user_addr_i,
        input [31:0] user_dat_i,
        output [31:0] user_dat_o,
        output [31:0] sample_dat_o,

        output [31:0] dinl_cdi_o,
        output dinl_ce_o,

        output ped_rst_o,
        output [47:0] ped_o,
        output [4:0] ped_addr_o,
        output ped_update_o,
        
        input sysclk_i,
        input sync_i,
        input [47:0] A,
        input [47:0] B,
        input [47:0] C,
        input [47:0] D,
        input [47:0] E,
        input [47:0] F,
        
        input trigger_i,
        input ext_trigger_i,
        output [70:0] debug_o
    );
    
    // Input registers. These get merged with other registers in the design.
    reg [47:0] Ai = {48{1'b0}};
    reg [47:0] Bi = {48{1'b0}};
    reg [47:0] Ci = {48{1'b0}};
    reg [47:0] Di = {48{1'b0}};
    reg [47:0] Ei = {48{1'b0}};
    reg [47:0] Fi = {48{1'b0}};
    
    // Local sync register.
    reg local_sync = 0;
    
    // The address generator provides the pretrigger and buffer handling.
    // The memory blocks provide the actual storage.
    
    wire [9:0] write_addr;
    wire write_enable;
    wire trigger_active;
    wire global_trigger;
    reg global_trigger_reg = 0;
    
    reg soft_trigger = 0;
    wire soft_trig_flag;
    reg reset = 0;
    wire reset_flag;
    reg clear = 0;
    wire clear_flag;
    
    reg [1:0] buffer_write_addr_reg = {2{1'b0}};
    reg [1:0] buffer_read_addr_reg = {2{1'b0}};

    // read is OK whenever the write pointer isn't equal to the read pointer.
    reg read_is_safe = 0;
    
    reg dinl_ce = 0;
    reg [31:0] dinl_data = {32{1'b0}};

    reg ped_reset = 0;
    reg ped_update = 0;
    reg [47:0] ped_data = {48{1'b0}};
    wire [11:0] ped_data_muxed[3:0];
    assign ped_data_muxed[0] = ped_data[0 +: 12];
    assign ped_data_muxed[1] = ped_data[12 +: 12];
    assign ped_data_muxed[2] = ped_data[24 +: 12];
    assign ped_data_muxed[3] = ped_data[36 +: 12];
    reg [6:0] ped_addr = {7{1'b0}};
    wire [3:0] ped_data_ce;
    assign ped_data_ce[0] = (user_dat_i[17:16] == 2'b00);
    assign ped_data_ce[1] = (user_dat_i[17:16] == 2'b01);
    assign ped_data_ce[2] = (user_dat_i[17:16] == 2'b10);
    assign ped_data_ce[3] = (user_dat_i[17:16] == 2'b11);

    wire [1:0] buffer_write_addr;
    wire [1:0] buffer_read_addr;

    reg [11:0] sample_address = {12{1'b0}};

    reg trigger_enable = 0;
    reg ext_trigger_enable = 0;
    
    reg [1:0] trigger_enable_SYSCLK = {2{1'b0}};
    reg [1:0] ext_trigger_enable_SYSCLK = {2{1'b0}};
    
    reg trigger_SYSCLK = 0;
    reg [1:0] ext_trigger_SYSCLK = {2{1'b0}};
    
    // reorganize STORCTL
    // 0: read ready
    // 1: soft trigger
    // 2: reset
    // 3: clear
    // 4: enable trigger
    // 5: enable ext trigger
    // 6 empty
    // 7 empty
    // [11:8] : buffer_write_addr
    // [15:12] : buffer_read_addr
    // [31:16] : sample_address 
    wire [31:0] STORCTRL = {{4{1'b0}}, sample_address,
                            {2{1'b0}}, buffer_read_addr,
                            {2{1'b0}}, buffer_write_addr,
                            {2{1'b0}}, ext_trigger_enable, trigger_enable,
                            {3{1'b0}}, read_is_safe};
    wire [31:0] DINLCTRL = dinl_data;
    wire [31:0] PEDCTRL = {{9{1'b0}},ped_addr,{4{1'b0}},ped_data_muxed[ped_addr[1:0]]};

    wire sel_storctrl = (user_addr_i[1:0] == 2'b00);
    wire sel_dinlctrl = (user_addr_i[1:0] == 2'b01) || (user_addr_i[1:0] == 2'b10);
    wire sel_pedctrl = (user_addr_i[1:0] == 2'b10);
    
    wire [31:0] user_data_demuxed[3:0];
    assign user_data_demuxed[0] = STORCTRL;
    assign user_data_demuxed[1] = DINLCTRL;
    assign user_data_demuxed[2] = PEDCTRL;
    assign user_data_demuxed[3] = DINLCTRL;

    assign user_dat_o = user_data_demuxed[user_addr_i[1:0]];

    always @(posedge user_clk_i) begin
        // register these in user clk domain. These are Gray-coded so functionally static.
        buffer_read_addr_reg <= buffer_read_addr;
        // register these in user clk domain. These are Gray-coded so functionally static.
        buffer_write_addr_reg <= buffer_write_addr;
        
        read_is_safe <= (buffer_read_addr_reg != buffer_write_addr_reg);
        
        if (user_sel_i && user_wr_i && sel_storctrl) begin        
            reset <= user_dat_i[3];
            clear <= user_dat_i[2];
            soft_trigger <= user_dat_i[1];
            trigger_enable <= user_dat_i[4];
            ext_trigger_enable <= user_dat_i[5];
        end else begin
            reset <= 0;
            clear <= 0;
            soft_trigger <= 0;
        end

        // address 1 can write to dinl_data freely
        // address 3 also issues a CE.        
        if (user_sel_i && user_wr_i && sel_dinlctrl) begin
            dinl_ce <= user_addr_i[1];
            dinl_data <= user_dat_i;
        end else begin
            dinl_ce <= 0;
        end
        
        if (user_sel_i && user_wr_i && sel_pedctrl) begin
            ped_reset <= user_dat_i[31];
            ped_update <= ~user_dat_i[31];

            if (ped_data_ce[0]) ped_data[0 +: 12] <= user_dat_i[11:0];
            if (ped_data_ce[1]) ped_data[12 +: 12] <= user_dat_i[11:0];
            if (ped_data_ce[2]) ped_data[24 +: 12] <= user_dat_i[11:0];
            if (ped_data_ce[3]) ped_data[36 +: 12] <= user_dat_i[11:0];

            ped_addr <= user_dat_i[16 +: 7];
        end else begin
            ped_reset <= 0;
            ped_update <= 0;
        end
        
        if (reset || clear) 
            sample_address <= {12{1'b0}};
        else if (sample_sel_i && user_wr_i)
            sample_address <= user_addr_i;
        else if (sample_sel_i && user_rd_i)
            sample_address <= sample_address + 1;    
    end

    always @(posedge sysclk_i) begin
        ext_trigger_enable_SYSCLK <= {ext_trigger_enable_SYSCLK[0], ext_trigger_enable};
        trigger_enable_SYSCLK <= {trigger_enable_SYSCLK[0], trigger_enable};
        
        trigger_SYSCLK <= trigger_i && trigger_enable_SYSCLK[1];
        ext_trigger_SYSCLK <= {ext_trigger_SYSCLK[0] && ext_trigger_enable_SYSCLK[1], ext_trigger_i};
        
        global_trigger_reg <= trigger_SYSCLK || ext_trigger_SYSCLK[1] || soft_trig_flag;
        Ai <= A;
        Bi <= B;
        Ci <= C;
        Di <= D;
        Ei <= E;
        Fi <= F;
        // Generate a real copy of sync.
        local_sync <= ~sync_i;        
    end        

    assign global_trigger = global_trigger_reg;

    flag_sync u_clear_flag_sync(.in_clkA(clear),.clkA(user_clk_i),.out_clkB(clear_flag),.clkB(sysclk_i));
    flag_sync u_reset_flag_sync(.in_clkA(reset),.clkA(user_clk_i),.out_clkB(reset_flag),.clkB(sysclk_i));
    flag_sync u_softtrig_flag_sync(.in_clkA(soft_trigger),.clkA(user_clk_i),.out_clkB(soft_trig_flag),.clkB(sysclk_i));

    RITC_sample_storage_address_generator u_addrgen(.clk_i(sysclk_i),.sync_i(local_sync),.trigger_i(global_trigger),.reset_i(reset_flag),
                                                    .clear_i(clear_flag),.active_o(trigger_active),.write_buffer_o(buffer_write_addr),
                                                    .read_buffer_o(buffer_read_addr),.write_addr_o(write_addr),
                                                    .write_en_o(write_enable));

    assign debug_o[0 +: 10] = write_addr;
    assign debug_o[10 +: 2] = buffer_write_addr;
    assign debug_o[12 +: 2] = buffer_read_addr;
    assign debug_o[14] = global_trigger;
    assign debug_o[15] = trigger_active;
    assign debug_o[16] = write_enable;
    assign debug_o[17] = reset_flag;
    assign debug_o[18] = local_sync;
    assign debug_o[19] = clear_flag;
    assign debug_o[20 +: 48] = Ai;
    
    RITC_sample_memory u_mem(.clk_i(sysclk_i),.A(Ai),.B(Bi),.C(Ci),.D(Di),.E(Ei),.F(Fi),
                             .waddr_i(write_addr),.we_i(write_enable),.active_i(trigger_active),.trigger_i(global_trigger),
                             .rd_clk_i(user_clk_i),.raddr_i({sample_address[11:9],buffer_read_addr_reg,sample_address[8:0]}),.en_i(read_is_safe),.dat_o(sample_dat_o));

    assign dinl_ce_o = dinl_ce;
    assign dinl_cdi_o = dinl_data;

    assign ped_rst_o = ped_reset;
    assign ped_addr_o = ped_addr[6:2];
    assign ped_o = ped_data; 
    assign ped_update_o = ped_update;
endmodule
