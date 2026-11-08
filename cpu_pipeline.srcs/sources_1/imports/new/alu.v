`timescale 1ns / 1ps
`include "defines.vh"

module alu #(
    parameter DATA_WIDTH = 32
)(
    input  wire [DATA_WIDTH-1:0] i_in_a,    // To�n h?ng A (RS1 ho?c PC)
    input  wire [DATA_WIDTH-1:0] i_in_b,    // To�n h?ng B (RS2 ho?c Immediate)
    input  wire [3:0]            i_alu_op,  // T�n hi?u ?i?u khi?n t? Decoder

    output reg  [DATA_WIDTH-1:0] o_result,  // K?t qu? t�nh to�n 32-bit
    output wire                  o_zero     // C? Zero (True n?u Result == 0)
);

    // C? Zero d�ng cho ki?m tra k?t qu?
    assign o_zero = (o_result == {DATA_WIDTH{1'b0}});

    always @(*) begin
        case (i_alu_op)
            `ALU_ADD: begin
                o_result = i_in_a + i_in_b;
            end

            `ALU_SUB: begin
                o_result = i_in_a - i_in_b;
            end

            `ALU_SLL: begin // Shift Left Logical
                o_result = i_in_a << i_in_b[4:0];
            end

            `ALU_SLT: begin // Set Less Than (Signed)
                o_result = ($signed(i_in_a) < $signed(i_in_b)) ? 32'd1 : 32'd0;
            end

            `ALU_SLTU: begin // Set Less Than (Unsigned)
                o_result = (i_in_a < i_in_b) ? 32'd1 : 32'd0;
            end

            `ALU_XOR: begin
                o_result = i_in_a ^ i_in_b;
            end

            `ALU_SRL: begin // Shift Right Logical
                o_result = i_in_a >> i_in_b[4:0];
            end

            `ALU_SRA: begin // Shift Right Arithmetic (D?ch gi? d?u)
                o_result = $signed(i_in_a) >>> i_in_b[4:0];
            end

            `ALU_OR: begin
                o_result = i_in_a | i_in_b;
            end

            `ALU_AND: begin
                o_result = i_in_a & i_in_b;
            end

            `ALU_COPY_B: begin // D�ng cho l?nh LUI (L?y tr?c ti?p Immediate)
                o_result = i_in_b;
            end

            default: begin
                o_result = {DATA_WIDTH{1'b0}};
            end
        endcase
    end

endmodule