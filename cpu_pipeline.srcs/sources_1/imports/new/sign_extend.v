/* Module: sign_extend.v */
`timescale 1ns / 1ps
module sign_extend(
    input [5:0] Imm_6bit,
    output [15:0] Imm_16bit
);
 
    assign Imm_16bit = {{10{Imm_6bit[5]}}, Imm_6bit};
endmodule
