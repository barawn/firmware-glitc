`timescale 1ns / 1ps

// Sync generation.
module glitc_intercom_sync_generator(
        input clk_i,
        input [1:0] status_rst_i,
        output sync_o,
        input [1:0] send_sync_i,
        output [1:0] sync_command_o,
        input [1:0] sync_in_i,
        output [1:0] sync_received_o,
        output [1:0] resynced_o
    );
    
    reg sync_seen = 0;
    reg [1:0] resynced = {2{1'b0}};
    reg [1:0] sync_received = {2{1'b0}};
    reg sync = 0;
    // sync_command needs to be high at the same time sync is low.
    reg [1:0] send_sync_hold = {2{1'b0}};
    reg [1:0] sync_command = {2{1'b0}};
    
    always @(posedge clk_i) begin
        // When sync_in_i goes, sync will be 1 in 2 clock cycles
        // So if it's 0 when sync_in_i is 1, that means we're resyncing.
        if (status_rst_i[0]) begin
            resynced[0] <= 0;
            sync_received[0] <= 0;
        end else if (sync_in_i[0]) begin
            if (!sync) resynced[0] <= 1;
            sync_received[0] <= 1;
        end
        
        if (status_rst_i[1]) begin
            resynced[1] <= 0;
            sync_received[1] <= 0;
        end else if (sync_in_i[1]) begin
            if (!sync) resynced[1] <= 1;
            sync_received[1] <= 1;
        end
        
        sync_seen <= |sync_in_i;
        
        if (sync_seen) sync <= 1;
        else sync <= ~sync;

        send_sync_hold <= send_sync_i;
        // sync flips every other cycle, so if we just hold send_sync_i,
        // either it, or send_sync_hold will be high when sync is high.
        sync_command[0] <= (send_sync_hold[0] || send_sync_i[0]) && sync;
        sync_command[1] <= (send_sync_hold[1] || send_sync_i[1]) && sync;
   end
   
   assign sync_o = sync;
   assign sync_received_o = sync_received;
   assign resynced_o = resynced;
   assign sync_command_o = sync_command;
endmodule
