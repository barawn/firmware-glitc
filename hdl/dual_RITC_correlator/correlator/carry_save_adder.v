`timescale 1ns / 1ps
// stupidest module ever
module carry_save_adder(
        X,
        Y,
        Z,
        C,
        S
    );
    parameter NBITS = 1;
    input [NBITS-1:0] X;
    input [NBITS-1:0] Y;
    input [NBITS-1:0] Z;
    output [NBITS-1:0] C;
    output [NBITS-1:0] S;
    
    generate
        genvar i;
        for (i=0;i<NBITS;i=i+1) begin
            assign S[i] = X[i] ^ Y[i] ^ Z[i];
            assign C[i] = ((X[i] ^ Y[i]) && Z[i]) || (X[i] && Y[i]);
        end
    endgenerate
endmodule
