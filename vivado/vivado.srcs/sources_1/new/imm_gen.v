`timescale 1ns / 1ps
`include "defines.vh"

module imm_gen #(
    parameter DATA_WIDTH = 32
)(
    input  wire [DATA_WIDTH-1:0] i_instr,    // C�u l?nh 32-bit t? IF/ID
    input  wire [2:0]            i_imm_src,  // T�n hi?u ch?n ki?u Imm t? Decoder
    output reg  [DATA_WIDTH-1:0] o_imm_ext   // Gi� tr? Immediate ?� Sign-Extend 32-bit
);

    always @(*) begin
        case (i_imm_src)
            // -----------------------------------------------------------------
            // I-Type: [31:20] -> 12-bit (Load, ALU Imm, JALR)
            // -----------------------------------------------------------------
            `IMM_I: begin
                o_imm_ext = {{20{i_instr[31]}}, i_instr[31:20]};
            end

            // -----------------------------------------------------------------
            // S-Type: { [31:25], [11:7] } -> 12-bit (Store: SB, SH, SW)
            // -----------------------------------------------------------------
            `IMM_S: begin
                o_imm_ext = {{20{i_instr[31]}}, i_instr[31:25], i_instr[11:7]};
            end

            // -----------------------------------------------------------------
            // B-Type: { [31], [7], [30:25], [11:8], 1'b0 } -> 13-bit (Branch)
            // -----------------------------------------------------------------
            `IMM_B: begin
                o_imm_ext = {{19{i_instr[31]}}, i_instr[31], i_instr[7], i_instr[30:25], i_instr[11:8], 1'b0};
            end

            // -----------------------------------------------------------------
            // U-Type: { [31:12], 12'b0 } -> 32-bit (LUI, AUIPC)
            // -----------------------------------------------------------------
            `IMM_U: begin
                o_imm_ext = {i_instr[31:12], 12'b0};
            end

            // -----------------------------------------------------------------
            // J-Type: { [31], [19:12], [20], [30:21], 1'b0 } -> 21-bit (JAL)
            // -----------------------------------------------------------------
            `IMM_J: begin
                o_imm_ext = {{11{i_instr[31]}}, i_instr[31], i_instr[19:12], i_instr[20], i_instr[30:21], 1'b0};
            end

            default: begin
                o_imm_ext = {DATA_WIDTH{1'b0}};
            end
        endcase
    end

endmodule