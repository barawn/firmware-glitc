`timescale 1ns / 1ps
module GLITC_trigger_dual_scaler(
        input clk_i,
        input upper_trigger_i,
        input lower_trigger_i,
        input hsk_update_i,
        input hsk_clk_i,
        output [23:0] upper_scaler_o,
        output [23:0] lower_scaler_o
    );
    
    // The scalers can count up to 2^23 (8.3M).
    // They stop counting past that (okay, they should count to 2^23 + 1).
    // To gain 2 resets, we use A:B for one input,
    // and C for the other input.
    // OPMODE = 0101100
    // ALUMODE = 0000
    // USE_SIMD = TWO24
    // PREG = 1
    // CREG = 1
    // AREG = 1
    // BREG = 1
    // RSTP = hsk_update_SYSCLK    
    // CEA2 = 1
    // CEB2 = 1
    // CEC  = 1
    // CEP  = 1
    // RSTA = P[23]
    // RSTB = P[23]
    // RSTC = P[47]
    // Then the cascade out goes up to the storage DSP.
    // The storage DSP just has a clock enable on the P registers (hsk_update_SYSCLK) so it updates
    // once and is done.

    wire [47:0] accumulator_x = {{23{1'b0}}, upper_trigger_i, {24{1'b0}}};
    wire [47:0] accumulator_y = {{47{1'b0}}, lower_trigger_i};
    wire [47:0] accumulator_cascade_out;
    wire [47:0] accumulator_out;
    wire [47:0] storage_out;
    wire hsk_update_SYSCLK;
    
    flag_sync u_update_sync(.in_clkA(hsk_update_i),.clkA(hsk_clk_i),
                            .out_clkB(hsk_update_SYSCLK),.clkB(clk_i));
    
    DSP48E1 #(.USE_SIMD("TWO24"),
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
    .USE_DPORT("FALSE")) u_accumulator( .A(accumulator_x[18 +: 30]),.B(accumulator_x[0 +: 18]),.C(accumulator_y),
                                      .P(accumulator_out),
                                      .PCOUT(accumulator_cascade_out),
                                      .CARRYIN(1'b0),
                                      .CARRYINSEL(3'h0),
                                      .ALUMODE(4'h0),
                                        // X output is A:B
                                        // Y output is C
                                        // Z output is P
                                      .OPMODE(7'b0101111),
                                      .INMODE(4'h0),
                                      .RSTA(accumulator_out[47]),
                                      .RSTB(accumulator_out[47]),
                                      .RSTC(accumulator_out[23]),
                                      .RSTP(hsk_update_SYSCLK),
                                      .CEP(1'b1),
                                      .CEA2(1'b1),
                                      .CEB2(1'b1),
                                      .CEC(1'b1),
                                      .CLK(clk_i));
    DSP48E1 #(.USE_SIMD("TWO24"),
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
                                      .USE_DPORT("FALSE")) u_storage( .A(accumulator_x[18 +: 30]),.B(accumulator_x[0 +: 18]),.C(accumulator_y),
                                                                        .P(storage_out),
                                                                        .PCIN(accumulator_cascade_out),
                                                                        .CARRYIN(1'b0),
                                                                        .CARRYINSEL(3'h0),
                                                                        .ALUMODE(4'h0),
                                                                          // X output is A:B
                                                                          // Y output is C
                                                                          // Z output is P
                                                                        .OPMODE(7'b0010000),
                                                                        .CEP(hsk_update_SYSCLK),
                                                                        .CLK(clk_i));
    assign upper_scaler_o = storage_out[24 +: 24];
    assign lower_scaler_o = storage_out[0 +: 24];
    
endmodule
