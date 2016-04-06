`timescale 1ns / 1ps
module GLITC_trigger #(parameter POWERBITS=12, parameter CORRBITS=5) (
        input clk_i,
        input [POWERBITS-1:0] upper_glitc_i,
        input [CORRBITS-1:0] upper_glitc_corr_i,
        input upper_glitc_valid_i,
        input [POWERBITS-1:0] upper_phi_i,
        input [CORRBITS-1:0] upper_phi_corr_i,
        input [POWERBITS-1:0] lower_phi_i,
        input [CORRBITS-1:0] lower_phi_corr_i,
        input [POWERBITS-1:0] lower_glitc_i,
        input [CORRBITS-1:0] lower_glitc_corr_i,
        input lower_glitc_valid_i,
        output [1:0] trigger_o,

        input hsk_update_i,
        
        input user_clk_i,
        input user_sel_i,
        input user_wr_i,
        input [3:0] user_addr_i,
        input [31:0] user_dat_i,
        output [31:0] user_dat_o
    );

    // this is our simple first pass at a trigger. just make it work for now.

    // address space:
    // 0x0: THRESH0
    // 0x1: THRESH1
    // 0x2: SCALER0
    // 0x3: SCALER1
    wire [23:0] upper_scaler;
    wire [23:0] lower_scaler;
    reg [12:0] upper_phi_threshold = {13{1'b0}};
    reg upper_thresh_update = 0;
    reg [12:0] lower_phi_threshold = {13{1'b0}};
    reg lower_thresh_update = 0;
    reg upper_phi_mask = 1;
    reg lower_phi_mask = 1;
    wire [31:0] user_dat_muxed[3:0];

    wire [31:0] THRESH0 = {{15{1'b0}}, lower_phi_mask, {3{1'b0}}, lower_phi_threshold};
    wire [31:0] THRESH1 = {{15{1'b0}}, upper_phi_mask, {3{1'b0}}, upper_phi_threshold};
    wire [31:0] SCALER0 = {{12{1'b0}}, lower_scaler};
    wire [31:0] SCALER1 = {{12{1'b0}}, upper_scaler};
    
    assign user_dat_muxed[0] = THRESH0;
    assign user_dat_muxed[1] = THRESH1;
    assign user_dat_muxed[2] = SCALER0;
    assign user_dat_muxed[3] = SCALER1;
    assign user_dat_o = user_dat_muxed[user_addr_i[1:0]];
    
    always @(posedge user_clk_i) begin
        if (user_sel_i && user_wr_i && user_addr_i[1:0] == 2'b01) begin
            upper_phi_threshold <= user_dat_i[12:0];
            upper_phi_mask <= user_dat_i[16];
            upper_thresh_update <= 1;
        end else begin 
            upper_thresh_update <= 0;
        end
        if (user_sel_i && user_wr_i && user_addr_i[1:0] == 2'b00) begin
            lower_phi_threshold <= user_dat_i[12:0];
            lower_phi_mask <= user_dat_i[16];
            lower_thresh_update <= 1;
        end else begin
            lower_thresh_update <= 0;
        end
    end
    // upper_phi_i/lower_phi_i need to be delayed for 5 total clock cycles.
    // We actually do 3 clocks of this inside the DSP block:
    // e.g.
    // register upper_phi_i, lower_phi_i
    // reregister upper_phi_i, lower_phi_i (2 clock delay)
    // pass to DSP
    // register at input (3 clock delay) upper_phi_i
    // register at input upper_phi_threshold
    // calculate upper_phi_threshold - upper_phi_i
    // register that output (4 clock delay now) and pass that up
    // register at input lower_phi_i (4 clock delay now)
    // calculate PCIN - lower_phi_i
    // register that output (5 clock delay total) and pass that up
    // calculate PCIN - upper_glitc_i
    // trigger is carry out
    // Need 3 DSPs for this
    GLITC_dsp_trigger u_upper(.phi_mask_i(upper_phi_mask),
                              .threshold_i(upper_phi_threshold),
                              .threshold_clk_i(user_clk_i),
                              .threshold_update_i(upper_thresh_update),
                              .ext_power_i(upper_glitc_i),
                              .ext_valid_i(lower_glitc_valid_i),
                              .int0_power_i(upper_phi_i),
                              .int1_power_i(lower_phi_i),
                              .clk_i(clk_i),
                              .trig_o(trigger_o[1]));
    GLITC_dsp_trigger u_lower(.phi_mask_i(lower_phi_mask),
                              .threshold_i(lower_phi_threshold),
                              .threshold_clk_i(user_clk_i),
                              .threshold_update_i(lower_thresh_update),
                              .ext_power_i(lower_glitc_i),
                              .ext_valid_i(lower_glitc_valid_i),
                              .int0_power_i(upper_phi_i),
                              .int1_power_i(lower_phi_i),
                              .clk_i(clk_i),
                              .trig_o(trigger_o[0]));
    GLITC_trigger_dual_scaler(.clk_i(clk_i),
                              .upper_trigger_i(trigger_o[1]),
                              .lower_trigger_i(trigger_o[0]),
                              .hsk_update_i(hsk_update_i),
                              .hsk_clk_i(user_clk_i),
                              .upper_scaler_o(upper_scaler),
                              .lower_scaler_o(lower_scaler));
                                         
endmodule
