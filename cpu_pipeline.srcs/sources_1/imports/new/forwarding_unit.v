`timescale 1ns / 1ps

module forwarding_unit (
    input  wire [4:0] i_id_ex_rs1,       // ??a ch? RS1 t?i c�ng ?o?n EX
    input  wire [4:0] i_id_ex_rs2,       // ??a ch? RS2 t?i c�ng ?o?n EX

    input  wire [4:0] i_ex_mem_rd,       // ??a ch? thanh ghi ?�ch t?i EX/MEM
    input  wire       i_ex_mem_reg_write,// T�n hi?u ghi thanh ghi t?i EX/MEM

    input  wire [4:0] i_mem_wb_rd,       // ??a ch? thanh ghi ?�ch t?i MEM/WB
    input  wire       i_mem_wb_reg_write,// T�n hi?u ghi thanh ghi t?i MEM/WB

    output reg  [1:0] o_forward_a,       // Mux select cho To�n h?ng A (RS1)
    output reg  [1:0] o_forward_b        // Mux select cho To�n h?ng B (RS2)
);

    // Encode t�n hi?u Forwarding:
    // 2'b00: L?y d? li?u g?c t? ID/EX pipeline register
    // 2'b10: Forward t? c�ng ?o?n EX/MEM (?u ti�n cao h?n - Hazard g?n nh?t)
    // 2'b01: Forward t? c�ng ?o?n MEM/WB (Hazard xa h?n)

    always @(*) begin
        // ---------------------------------------------------------------------
        // 1. Forwarding cho To�n h?ng A (i_id_ex_rs1)
        // ---------------------------------------------------------------------
        if (i_ex_mem_reg_write && (i_ex_mem_rd != 5'b00000) && (i_ex_mem_rd == i_id_ex_rs1)) begin
            o_forward_a = 2'b10;
        end
        else if (i_mem_wb_reg_write && (i_mem_wb_rd != 5'b00000) && (i_mem_wb_rd == i_id_ex_rs1)) begin
            o_forward_a = 2'b01;
        end
        else begin
            o_forward_a = 2'b00;
        end

        // ---------------------------------------------------------------------
        // 2. Forwarding cho To�n h?ng B (i_id_ex_rs2)
        // ---------------------------------------------------------------------
        if (i_ex_mem_reg_write && (i_ex_mem_rd != 5'b00000) && (i_ex_mem_rd == i_id_ex_rs2)) begin
            o_forward_b = 2'b10;
        end
        else if (i_mem_wb_reg_write && (i_mem_wb_rd != 5'b00000) && (i_mem_wb_rd == i_id_ex_rs2)) begin
            o_forward_b = 2'b01;
        end
        else begin
            o_forward_b = 2'b00;
        end
    end

endmodule