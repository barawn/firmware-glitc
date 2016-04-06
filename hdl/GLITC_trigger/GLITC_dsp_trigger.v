`timescale 1ns / 1ps
// 'threshold_i' here results in a strict greater than.
module GLITC_dsp_trigger #(parameter POWERBITS=12) (
        input phi_mask_i,
        input [POWERBITS+1:0] threshold_i,
 
        input threshold_update_i,
        input threshold_clk_i,
        
        input [POWERBITS-1:0] ext_power_i,
        input ext_valid_i,
        input [POWERBITS-1:0] int0_power_i,
        input [POWERBITS-1:0] int1_power_i,
        input clk_i,        
        output trig_o        
    );
    
    reg [POWERBITS-1:0] int0_power_store_0 = {POWERBITS{1'b0}};
    reg [POWERBITS-1:0] int0_power_store_1 = {POWERBITS{1'b0}};
    reg [POWERBITS-1:0] int1_power_store_0 = {POWERBITS{1'b0}};
    reg [POWERBITS-1:0] int1_power_store_1 = {POWERBITS{1'b0}};
    
    always @(posedge clk_i) begin
        int0_power_store_0 <= int0_power_i;
        int0_power_store_1 <= int0_power_store_0;
        int1_power_store_0 <= int1_power_i;
        int1_power_store_1 <= int1_power_store_0;
    end
    wire threshold_update_sysclk;
    flag_sync u_update_sync(.in_clkA(threshold_update_i),.clkA(threshold_clk_i),
                            .out_clkB(threshold_update_sysclk),.clkB(clk_i));
    // AAAAUGH WHY IS THIS SO HARD
    // for ALUMODE = 0011 (Z-(X+Y+CIN))
    // it's really not(X+Y+(notZ))
    // if Z is threshold, then (notZ) is very very big
    // if X+Z overflows, then lots of top bits will be set (negative input)
    // Z = threshold_i
    // Y = C = 0
    // X = A:B = int0_power_i
    // OPMODE = 011_0011
    // following again, not(Z) + X won't overflow again, so inverting, inputs will still be negative
    // we don't *need* the carry output in this case: just pick off the top bit in the output
    
    wire [47:0] first_dsp_xin = { {48-POWERBITS{1'b0}}, int0_power_i };
    wire [47:0] first_dsp_zin = { {48-POWERBITS+2{1'b0}}, threshold_i };
    wire [47:0] first_dsp_out;
    DSP48E1 #(.USE_SIMD("ONE48"),
    .AREG(1),
    .BREG(1),
    .CREG(1),
    .ACASCREG(1),
    .BCASCREG(1),
    .PREG(1),
    .ALUMODEREG(0),
    .DREG(0),
    .ADREG(0),
    .OPMODEREG(0),
    .CARRYINREG(0),
    .CARRYINSELREG(0),
    .INMODEREG(0),
    .MREG(0),
    .USE_MULT("NONE"),
    .USE_PATTERN_DETECT("NO_PATDET"),
    .A_INPUT("DIRECT"),
    .B_INPUT("DIRECT"),
    .USE_DPORT("FALSE")) u_first_dsp( .A(first_dsp_xin[18 +: 30]),
                                      .B(first_dsp_xin[0 +: 18]),
                                      .C(first_dsp_zin),
                                      .PCOUT(first_dsp_out),
                                      .CARRYIN(1'b0),
                                      .CARRYINSEL(3'h0),
                                      .ALUMODE(4'h3),
                                        // X output is A:B
                                        // Y output is 0
                                        // Z output is C
                                      .OPMODE(7'b0110011),
                                      .INMODE(4'h0),
                                      .CEP(1'b1),
                                      .CEA2(1'b1),
                                      .CEB2(1'b1),
                                      .CEC(threshold_update_sysclk),
                                      .CLK(clk_i));

    // Second stage DSP.
    // ALUMODE is Z-(X+Y+CIN) = 0011
    // Z = PCIN
    // Y = 0
    // X = A:B = int1_power_i
    // OPMODE = 0010011
    // AREG=2
    // BREG=2
    // CREG=0
    // PREG=1
    wire [47:0] second_dsp_xin = { {48-POWERBITS{1'b0}}, int1_power_i };
    wire [47:0] second_dsp_out;
    DSP48E1 #(.USE_SIMD("ONE48"),
    .AREG(2),
    .BREG(2),
    .CREG(0),
    .ACASCREG(2),
    .BCASCREG(2),
    .PREG(1),
    .ALUMODEREG(0),
    .DREG(0),
    .ADREG(0),
    .OPMODEREG(0),
    .CARRYINREG(0),
    .CARRYINSELREG(0),
    .INMODEREG(0),
    .MREG(0),
    .USE_MULT("NONE"),
    .USE_PATTERN_DETECT("NO_PATDET"),
    .A_INPUT("DIRECT"),
    .B_INPUT("DIRECT"),
    .USE_DPORT("FALSE")) u_second_dsp( .A(second_dsp_xin[18 +: 30]),
                                      .B(second_dsp_xin[0 +: 18]),
                                      .PCIN(first_dsp_out),
                                      .PCOUT(second_dsp_out),
                                      .CARRYIN(1'b0),
                                      .CARRYINSEL(3'h0),
                                      .ALUMODE(4'h3),
                                        // X output is A:B
                                        // Y output is 0
                                        // Z output is C
                                      .OPMODE(7'b0010011),
                                      .INMODE(4'h0),
                                      .CEP(1'b1),
                                      .CEA1(1'b1),
                                      .CEB1(1'b1),
                                      .CEA2(1'b1),
                                      .CEB2(1'b1),
                                      .CEC(1'b0),
                                      .CLK(clk_i));    
    // Third stage DSP.
    // ALUMODE is Z-(X+Y+CIN) = 0011
    // Z = PCIN
    // Y = C = ext_power_i
    // X = 0
    // OPMODE = 001_1100
    // AREG = 0
    // BREG = 0
    // CREG = 0
    // PREG = 1
    wire [47:0] third_dsp_yin = { {48-POWERBITS{1'b0}}, ext_power_i };
    wire [47:0] third_dsp_out;
    DSP48E1 #(.USE_SIMD("ONE48"),
    .AREG(0),
    .BREG(0),
    .CREG(0),
    .ACASCREG(0),
    .BCASCREG(0),
    .PREG(1),
    .ALUMODEREG(0),
    .DREG(0),
    .ADREG(0),
    .OPMODEREG(0),
    .CARRYINREG(0),
    .CARRYINSELREG(0),
    .INMODEREG(0),
    .MREG(0),
    .USE_MULT("NONE"),
    .USE_PATTERN_DETECT("NO_PATDET"),
    .A_INPUT("DIRECT"),
    .B_INPUT("DIRECT"),
    .USE_DPORT("FALSE")) u_third_dsp( .C(third_dsp_yin),
                                      .PCIN(second_dsp_out),
                                      .P(third_dsp_out),
                                      .CARRYIN(1'b0),
                                      .CARRYINSEL(3'h0),
                                      .ALUMODE(4'h3),
                                        // X output is A:B
                                        // Y output is 0
                                        // Z output is C
                                      .OPMODE(7'b0011100),
                                      .INMODE(4'h0),
                                      .CEP(1'b1),
                                      .RSTP(phi_mask_i),
                                      .CEA2(1'b0),
                                      .CEB2(1'b0),
                                      .CEC(1'b1),
                                      .RSTC(ext_valid_i),
                                      .CLK(clk_i));    
    // Top bit is a sign bit. If result is negative, we've exceeded the threshold.
    assign trig_o = third_dsp_out[47];    
        
endmodule
