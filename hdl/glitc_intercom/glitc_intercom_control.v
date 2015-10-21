`timescale 1ns / 1ps
module glitc_intercom_control #(parameter LATENCY_WIDTH=4) (
        input user_clk_i,
        input user_wr_i,
        input user_sel_i,
        input [3:0] user_addr_i,
        input [31:0] user_dat_i,
        output [31:0] user_dat_o,
        
        output [1:0] iserdes_reset_o,
        output [1:0] oserdes_reset_o,
        output [1:0] ibufds_disable_o,
        output [1:0] oserdes_ce_o,
        
        output [1:0] status_reset_o,
        output [1:0] send_sync_o,
        input [1:0] sync_received_i,
        input [1:0] resynced_i,
        output [1:0] send_echo_o,
        input [1:0] echo_ready_i,
        input [1:0] echo_seen_i,
        input [2*LATENCY_WIDTH-1:0] latency_i,        
        output [1:0] enable_o,

        output [1:0] train_o,

        output [1:0] training_done_o,
        input [1:0] train_latch_i,
        output [1:0] train_latch_seen_o,
        input [39:0] train_i
    );

    wire [31:0] output_registers[3:0];
    wire [31:0] GICTRL0;
    wire [31:0] GICTRL1;
    wire [31:0] GITRAINUP;
    wire [31:0] GITRAINDOWN;
    assign output_registers[0] = GICTRL0;
    assign output_registers[1] = GICTRL1;
    assign output_registers[2] = GITRAINUP;
    assign output_registers[3] = GITRAINDOWN;
    assign user_dat_o = output_registers[user_addr_i[1:0]];

    //% Reset the ISERDESes.
    reg [1:0] iserdes_reset = {2{1'b0}};
    //% Reset the OSERDESes.
    reg [1:0] oserdes_reset = {2{1'b0}};
    //% Disable the IBUFDSes.
    reg [1:0] input_buffer_disable = {2{1'b1}};
    //% Clock enable for the OSERDESes.
    reg [1:0] oserdes_clock_enable = {2{1'b0}};
    
    //% Correlation output enable.
    reg [1:0] correlation_enable = {2{1'b0}};
    //% Input training complete (accept sync/echo commands).
    reg [1:0] input_training_complete = {2{1'b0}};
    //% Put outputs in training mode.
    reg [1:0] output_training_mode = {2{1'b0}};
    //% Send a sync.
    reg [1:0] send_sync = {2{1'b0}};
    //% Sync received on this path.
    reg [1:0] sync_received = {2{1'b0}};
    //% The input 'sync' from this path caused a resynchronization.
    reg [1:0] resynced = {2{1'b0}};
    //% Send an echo.
    reg [1:0] send_echo = {2{1'b0}};
    //% Echo response seen.
    reg [1:0] echo_seen = {2{1'b0}};
    //% Latency timer response from echo.
    reg [2*LATENCY_WIDTH-1:0] echo_latency = {2*LATENCY_WIDTH{1'b0}};
    //% Reset status.
    reg [1:0] status_reset = {2{1'b0}};
    
    //% Training input
    reg [39:0] train = {40{1'b0}};
    //% Training latch seen.
    reg [1:0] train_latch_seen = {2{1'b0}};
    
    wire sel_GICTRL0 = (user_addr_i[1:0] == 2'b00) && user_sel_i;
    wire sel_GICTRL1 = (user_addr_i[1:0] == 2'b01) && user_sel_i;
    
	always @(posedge user_clk_i) begin
        // GICTRL0
        // [0] = ISERDES reset
        // [1] = OSERDES reset
        // [2] = IBUF disable
        // [3] = OSERDES clock enable
        // repeats for bits 16+
        if (sel_GICTRL0 && user_wr_i) begin
            iserdes_reset <= {user_dat_i[16],user_dat_i[0]};
            oserdes_reset <= {user_dat_i[17],user_dat_i[1]};
            input_buffer_disable <= {user_dat_i[18], user_dat_i[2]};
            oserdes_clock_enable <= {user_dat_i[19], user_dat_i[3]};
        end else begin
            iserdes_reset <= {2{1'b0}};
            oserdes_reset <= {2{1'b0}};
        end
        // GICTRL1
        // [0] = enabled
        // [1] = input training done
        // [2] = output training mode
        // [3] = send sync to this path
        // [4] = sync received on this path
        // [5] = resynced from this path
        // [6] = send echo on this path
        // [7] = echo response seen on this path
        // [11:8] = latency timer when echo received
        // [15] = status reset this path (echo seen/resynced/sync received)
        // repeats for bits 16+
        if (sel_GICTRL1 && user_wr_i) begin
            correlation_enable <= {user_dat_i[16],user_dat_i[0]};
            input_training_complete <= {user_dat_i[17],user_dat_i[1]};
            output_training_mode <= {user_dat_i[18],user_dat_i[2]};
            send_sync <= {user_dat_i[19],user_dat_i[3]};
            send_echo <= {user_dat_i[22],user_dat_i[6]};
            status_reset <= {user_dat_i[31],user_dat_i[15]};
        end else begin
            send_sync <= {2{1'b0}};
            send_echo <= {2{1'b0}};
            status_reset <= {2{1'b0}};
        end

        sync_received <= sync_received_i;
        resynced <= resynced_i;
        if (echo_ready_i[0]) begin
            echo_seen[0] <= echo_seen_i[0];
            echo_latency[0 +: LATENCY_WIDTH] <= latency_i[0 +: LATENCY_WIDTH];
        end
        if (echo_ready_i[1]) begin
            echo_seen[1] <= echo_seen_i[1];
            echo_latency[LATENCY_WIDTH +: LATENCY_WIDTH] <= latency_i[LATENCY_WIDTH +: LATENCY_WIDTH];
        end
    
        train_latch_seen <= train_latch_i;
        if (train_latch_i[0]) train[0 +: 20] <= train_i[0 +: 20];
        if (train_latch_i[1]) train[20 +: 20] <= train_i[20 +: 20];
    end    

    assign GICTRL0 = {{12{1'b0}},oserdes_clock_enable[1],input_buffer_disable[1],{2{1'b0}},{12{1'b0}},oserdes_clock_enable[0],input_buffer_disable[0],{2{1'b0}}};
    assign GICTRL1 = {{8-LATENCY_WIDTH{1'b0}},echo_latency[LATENCY_WIDTH +: LATENCY_WIDTH],echo_seen[1],1'b0,resynced[1],sync_received[1],1'b0,output_training_mode[1],input_training_complete[1],correlation_enable[1],
                      {8-LATENCY_WIDTH{1'b0}},echo_latency[0 +: LATENCY_WIDTH],echo_seen[0],1'b0,resynced[0],sync_received[0],1'b0,output_training_mode[0],input_training_complete[0],correlation_enable[0]};
    assign GITRAINUP = {{12{1'b0}},train[0 +: 20]};
    assign GITRAINDOWN = {{12{1'b0}},train[20 +: 20]};
    
    assign iserdes_reset_o = iserdes_reset;
    assign oserdes_reset_o = oserdes_reset;
    assign ibufds_disable_o = input_buffer_disable;
    assign oserdes_ce_o = oserdes_clock_enable;
    assign status_reset_o = status_reset;
    assign send_sync_o = send_sync;
    assign send_echo_o = send_echo;
    assign enable_o = correlation_enable;        
    assign train_o = output_training_mode;
    assign training_done_o = input_training_complete;
    assign train_latch_seen_o = train_latch_seen;
    
endmodule
