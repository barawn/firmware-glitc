`timescale 1ns / 1ps
module glitc_intercom_training(
        input clk_i,
        input [19:0] dat_i,
        input training_done_i,
        output train_latch_o,
        input train_latch_seen_i,
        output [19:0] train_o
    );
    
    reg train_latch_waiting = 0;
    reg [19:0] train = {20{1'b0}};
    reg train_latch_flag = 0;
    
    always @(posedge clk_i) begin
        if (train_latch_seen_i || training_done_i) train_latch_waiting <= 0;
        else if (!training_done_i) train_latch_waiting <= 1;
        
        train_latch_flag <= (!train_latch_waiting && !training_done_i);
        if (train_latch_flag) train <= dat_i;
    end
        
    assign train_o = train;
    assign train_latch_o = train_latch_flag;
    
endmodule
