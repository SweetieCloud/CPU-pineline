`timescale 1ns / 1ps
`include "defines.vh"

// =============================================================================
// RV32M HARDWARE MULTIPLIER (Single-Cycle Combinational / DSP-Mapped)
// =============================================================================
// Ho tro day du 4 lenh nhan cua RV32M:
//   - MUL    (funct3 = 000): Lay 32 bit thap (Signed * Signed hoac Unsigned * Unsigned)
//   - MULH   (funct3 = 001): Lay 32 bit cao (Signed * Signed)
//   - MULHSU (funct3 = 010): Lay 32 bit cao (Signed rs1 * Unsigned rs2)
//   - MULHU  (funct3 = 011): Lay 32 bit cao (Unsigned * Unsigned)
// =============================================================================

module multiplier (
    input  wire [`DATA_WIDTH-1:0] i_a,
    input  wire [`DATA_WIDTH-1:0] i_b,
    input  wire [2:0]             i_funct3,
    output reg  [`DATA_WIDTH-1:0] o_result
);

    // Mo rong 33 bit de xu ly chinh xac phep toan co dau / khong dau
    wire signed [32:0] op_a_signed   = {i_a[31], i_a};
    wire signed [32:0] op_b_signed   = {i_b[31], i_b};
    wire signed [32:0] op_b_unsigned = {1'b0, i_b};
    wire [32:0]        op_a_u        = {1'b0, i_a};
    wire [32:0]        op_b_u        = {1'b0, i_b};

    // Tich 66-bit cho tung truong hop dau
    wire signed [65:0] prod_signed_signed = op_a_signed * op_b_signed;
    wire signed [65:0] prod_signed_unsign = op_a_signed * op_b_unsigned;
    wire [65:0]        prod_unsign_unsign = op_a_u * op_b_u;

    always @(*) begin
        case (i_funct3)
            `FUNCT3_MUL:    o_result = prod_signed_signed[31:0];
            `FUNCT3_MULH:   o_result = prod_signed_signed[63:32];
            `FUNCT3_MULHSU: o_result = prod_signed_unsign[63:32];
            `FUNCT3_MULHU:  o_result = prod_unsign_unsign[63:32];
            default:        o_result = 32'd0;
        endcase
    end

endmodule
