`timescale 1ns / 1ps
module glitc_intercom_echo_handler #(parameter LATENCY_WIDTH=4) (
        input clk_i,
        input status_rst_i,
        input echo_in_i,
        output echo_out_o,
        input echo_send_i,
        output echo_ready_o,
        output echo_seen_o,
        output [LATENCY_WIDTH-1:0] echo_latency_o
    );
        
    reg waiting_for_echo = 0;
    reg [LATENCY_WIDTH-1:0] latency_timer = {LATENCY_WIDTH{1'b0}};
    wire [LATENCY_WIDTH:0] latency_timer_plus_one = latency_timer + 1;
    reg echo_seen = 0;
    reg echo_ready = 0;
    reg echoing = 0;
    
    always @(posedge clk_i) begin
        if (echo_send_i || (echo_in_i && !waiting_for_echo)) echoing <= 1;
        else echoing <= 0;
        
        if (echo_send_i || status_rst_i) latency_timer <= {LATENCY_WIDTH{1'b0}};
        else if (waiting_for_echo && !latency_timer_plus_one[LATENCY_WIDTH]) latency_timer <= latency_timer_plus_one;
        
        if (echo_send_i) waiting_for_echo <= 1;
        else if (latency_timer_plus_one[LATENCY_WIDTH] || echo_in_i) waiting_for_echo <= 0;
        
        if (status_rst_i || echo_send_i) echo_seen <= 0;
        else if (waiting_for_echo && echo_in_i) echo_seen <= 1;
    
        echo_ready <= (latency_timer_plus_one[LATENCY_WIDTH] || echo_in_i) && waiting_for_echo;
    end        

    assign echo_latency_o = latency_timer;
    assign echo_seen_o = echo_seen;
    assign echo_ready_o = echo_ready;
    assign echo_out_o = echoing;
endmodule
