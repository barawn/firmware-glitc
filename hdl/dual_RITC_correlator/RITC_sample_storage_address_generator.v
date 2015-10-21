`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/29/2015 10:08:48 AM
// Design Name: 
// Module Name: RITC_sample_storage_address_generator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module RITC_sample_storage_address_generator(
        input clk_i,
        input sync_i,
        input trigger_i,
        input reset_i,
        input clear_i,
        output active_o,
        output [1:0] write_buffer_o,
        output [1:0] read_buffer_o,
        output [9:0] write_addr_o,
        output write_en_o
    );

    // Sample storage connects to 12 RAMB36s, giving a total of 1024 samples of storage.
    // We split that up into 4 blocks of 256 samples each.
    // So the top 2 address bits are a buffer indicator.
    reg [1:0] buffer_write_address = {2{1'b0}};
    reg [1:0] buffer_read_address = {2{1'b0}};
    reg write_enable = 0;
    // Low 7 bit address. This is a ring buffer: it constantly increments.    
    reg [6:0] write_address = {6{1'b0}};
    // Next write address.
    wire [7:0] write_address_plus_one = write_address + 1;

    // Post trigger and trigger holdoff counter. When this expires first, buffer switches. When it expires second, trigger reenabled.
    reg [5:0] post_trigger_counter = {7{1'b0}};
    // Next counter.
    wire [6:0] post_trigger_counter_plus_one = post_trigger_counter + 1;
    // Flag to indicate that the post trigger counter has completed.
    reg post_trigger_done = 0;

    // Trigger has occurred and the post-trigger counter is running.
    reg trigger_active = 0;
    
    // Trigger is being held off to fill the pre-trigger window.
    reg pretrigger_filling = 0;

    // All buffers are currently filled. Note that this keeps the post trigger counter running (trigger_active will not clear).
    reg all_buffers_full = 0;

    // The next buffer to switch to when post_trigger_counter fills with trigger_active set.
    reg [1:0] next_buffer = {2{1'b0}};
    
    // Or of all trigger inputs.
    wire global_trigger;
    // Flag to reset the sample storage system.
    wire reset_flag;
    // Flag to indicate a buffer is done being read.
    wire buffer_clear_flag;
    
    // Logically we split the buffer up into 4 buffers of 256 clocks (4096 samples).
    // The 8 bits that make up the in-buffer address are constantly counting,
    // with the low bit actually being the 'sync' input (so address=0 is always
    // sync=0, address=1 is always sync=1, etc.).
    always @(posedge clk_i) begin
        // Write address increment. This is constant.
        if (reset_i) write_address <= {7{1'b0}};
        else if (sync_i) write_address <= write_address_plus_one[6:0];

        if (!trigger_active) post_trigger_counter <= {7{1'b0}};
        else if (sync_i) post_trigger_counter <= post_trigger_counter_plus_one;

        post_trigger_done <= post_trigger_counter_plus_one[6] && !sync_i;
        
        if (reset_i || (pretrigger_filling && post_trigger_done)) trigger_active <= 0;
        else if (trigger_i) trigger_active <= 1;
        
        if (reset_i) pretrigger_filling <= 0;
        else if (post_trigger_done) begin
            if (trigger_active && !all_buffers_full) pretrigger_filling <= ~pretrigger_filling;
            else pretrigger_filling <= 0;
        end

        // Write enable shuts off after the post trigger counter rolls once
        // when buffers are full. It will reenable the next time that counter
        // hits when the buffers aren't full.
        if (reset_i) write_enable <= 1;
        else if (post_trigger_done) begin
            if (trigger_active && !pretrigger_filling) write_enable <= !all_buffers_full;
        end
        
        if (reset_i) buffer_write_address <= {2{1'b0}};
        else if (post_trigger_done && !pretrigger_filling) buffer_write_address <= next_buffer;
                        
        if (reset_i) buffer_read_address <= {2{1'b0}};
        else if (clear_i) begin
            case(buffer_read_address)
                2'b00: buffer_read_address <= 2'b01;
                2'b01: buffer_read_address <= 2'b11;
                2'b11: buffer_read_address <= 2'b10;
                2'b10: buffer_read_address <= 2'b00;
            endcase
        end
        
        all_buffers_full <= (buffer_write_address == 2'b10 && buffer_read_address == 2'b00) ||
                            (buffer_write_address == 2'b00 && buffer_read_address == 2'b01) ||
                            (buffer_write_address == 2'b01 && buffer_read_address == 2'b11) ||
                            (buffer_write_address == 2'b11 && buffer_read_address == 2'b10);
        
        // If all buffers are full, then next_buffer just holds the current buffer.
        // Note that write gets disabled in this case (since if last_write
        // address && all_buffers_full, then write_enable goes low). When the buffer_clear_flag
        // comes in, in the next cycle, all buffers full goes low again. and next_buffer updates.
        // Then the next time that the write address hits its highest value, write enable goes high
        // we move to the next buffer, and all is good.                             
        if (!all_buffers_full) begin
            case (buffer_write_address)
                2'b00: next_buffer <= 2'b01;
                2'b01: next_buffer <= 2'b11;
                2'b11: next_buffer <= 2'b10;
                2'b10: next_buffer <= 2'b00;
            endcase
        end else begin
            next_buffer <= buffer_write_address;
        end
    end
    
    assign active_o = trigger_active && !pretrigger_filling;
    assign write_buffer_o = buffer_write_address;
    assign read_buffer_o = buffer_read_address;
    assign write_addr_o = { buffer_write_address, write_address, sync_i };
    assign write_en_o = write_enable;
endmodule
