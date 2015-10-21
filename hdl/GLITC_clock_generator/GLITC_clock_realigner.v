`timescale 1ns / 1ps
module GLITC_clock_realigner(
        input clk_i,
        input realign_i,
        output realigned_o,
        output ps_en_o,
        output ps_increment_ndecrement_o,
        input ps_done_i
    );
    // Nominally at 162.5 MHz we're operating at VCO/4.
    // There are 56 steps per VCO period so we want to step forward 112. 
    parameter NUM_SHIFTS = 112;
    reg [7:0] shift_counter = {8{1'b0}};
    localparam FSM_BITS=2;
    localparam [FSM_BITS-1:0] IDLE = 0;
    localparam [FSM_BITS-1:0] ENABLE = 1;
    localparam [FSM_BITS-1:0] WAITING = 2;
    localparam [FSM_BITS-1:0] DONE = 3;
    reg [FSM_BITS-1:0] state = IDLE;
    
    always @(posedge clk_i) begin
        case (state)
            IDLE: if (realign_i) state <= ENABLE;
            ENABLE: state <= WAITING;
            WAITING: if (ps_done_i) begin
                if (shift_counter == (NUM_SHIFTS-1)) state <= DONE;
                else state <= ENABLE;
            end
            DONE: state <= IDLE;
       endcase
       if (state == WAITING && ps_done_i) shift_counter <= shift_counter + 1;
       else if (state == IDLE) shift_counter <= {8{1'b0}};
    end
    assign ps_en_o = (state == ENABLE);
    assign ps_increment_ndecrement_o = 1'b1;                    
    assign realigned_o = (state == DONE);
endmodule
