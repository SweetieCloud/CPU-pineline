`timescale 1ns / 1ps

module hazard_unit (
    // Tin hieu kiem tra Load-Use Hazard
    input  wire       i_id_ex_mem_read,  // Lenh tai EX la Load (LW, LB, LH...)
    input  wire [4:0] i_id_ex_rd,        // Thanh ghi dich tai EX Stage
    input  wire [4:0] i_if_id_rs1,       // Thanh ghi nguon 1 tai ID Stage
    input  wire [4:0] i_if_id_rs2,       // Thanh ghi nguon 2 tai ID Stage
    input  wire       i_uses_rs1,        // Lenh tai ID thuc su su dung RS1
    input  wire       i_uses_rs2,        // Lenh tai ID thuc su su dung RS2

    // Tin hieu Control Hazard & Trap
    input  wire       i_branch_mispredict, // Du doan re nhanh sai (can Flush IF/ID)
    input  wire       i_jump_taken,        // Lenh JAL/JALR tai ID Stage
    input  wire       i_mret,              // Lenh MRET tai ID Stage
    input  wire       i_trap_taken,        // Trap (Ngat/Exception) duoc chap nhan

    // Tin hieu Stall tu Bus AXI
    input  wire       i_axi_i_stall,       // AXI Instruction Fetch Master dang ban
    input  wire       i_axi_d_stall,       // AXI Data Access Master dang ban

    // Tin hieu Multi-Cycle Divider & Multiplier & CSR Hazard
    input  wire       i_div_busy,          // Bo chia dang tinh toan tai EX Stage
    input  wire       i_id_ex_is_mul,      // Lenh tai EX Stage la Nhan phan cung (MUL)
    input  wire       i_branch,            // Lenh tai ID Stage la Re nhanh co dieu kien
    input  wire       i_id_ex_is_csr,      // Lenh tai EX Stage la CSR (doc CSR tai WB)
    input  wire       i_ex_mem_is_csr,     // Lenh tai MEM Stage la CSR (doc CSR tai WB)
    input  wire [4:0] i_ex_mem_rd,         // Thanh ghi dich tai MEM Stage

    // Tin hieu dieu khien Pipeline
    output reg        o_pc_write,          // 1: Cho phep cap nhat PC, 0: Giu nguyen PC
    output reg        o_if_id_write,       // 1: Cho phep ghi IF/ID reg, 0: Giu nguyen IF/ID
    output reg        o_if_id_flush,       // 1: Xoa lenh trong IF/ID stage (Flush)
    output reg        o_id_ex_flush,       // 1: Chen Bubble vao ID/EX stage (Stall Load-Use)
    output reg        o_pipeline_hold,     // 1: Giu nguyen trang thai toan bo Pipeline (Bus Stall)
    output reg        o_id_ex_hold,        // 1: Dong bang ID/EX khi Divider dang ban
    output reg        o_ex_mem_flush,      // 1: Chen Bubble vao EX/MEM khi Divider dang ban
    output wire       o_hazard_stall       // 1: Pipeline dang ban xu ly Hazard
);

    wire load_use_hazard;
    assign load_use_hazard = i_id_ex_mem_read && (i_id_ex_rd != 5'b00000) &&
                             ((i_uses_rs1 && (i_id_ex_rd == i_if_id_rs1)) ||
                              (i_uses_rs2 && (i_id_ex_rd == i_if_id_rs2)));

    // Multiplier-to-Branch Hazard: Stall 1 chu ky neu nhanh re tai ID phu thuoc ket qua MUL tai EX
    // Giup cat dut critical path 23ns qua DSP48E1 vao Branch Comparator & BTB
    wire mul_use_hazard;
    assign mul_use_hazard = i_id_ex_is_mul && (i_id_ex_rd != 5'b00000) && (i_branch || i_jump_taken) &&
                            ((i_uses_rs1 && (i_id_ex_rd == i_if_id_rs1)) ||
                             (i_uses_rs2 && (i_id_ex_rd == i_if_id_rs2)));

    // CSR-Use Hazard: Vi CSR File duoc truy xuat o WB Stage, neu lenh tai ID doc thanh ghi rd
    // cua lenh CSR dang o EX hoac MEM, stall de doi CSR lui ve WB Stage va forward wb_final_data
    wire csr_use_hazard;
    assign csr_use_hazard = (i_id_ex_is_csr && (i_id_ex_rd != 5'b00000) &&
                             ((i_uses_rs1 && (i_id_ex_rd == i_if_id_rs1)) ||
                              (i_uses_rs2 && (i_id_ex_rd == i_if_id_rs2)))) ||
                            (i_ex_mem_is_csr && (i_ex_mem_rd != 5'b00000) &&
                             ((i_uses_rs1 && (i_ex_mem_rd == i_if_id_rs1)) ||
                              (i_uses_rs2 && (i_ex_mem_rd == i_if_id_rs2))));

    assign o_hazard_stall = load_use_hazard || mul_use_hazard || csr_use_hazard || i_div_busy;

    always @(*) begin
        // Gia tri mac dinh: Pipeline hoat dong binh thuong
        o_pc_write      = 1'b1;
        o_if_id_write   = 1'b1;
        o_if_id_flush   = 1'b0;
        o_id_ex_flush   = 1'b0;
        o_pipeline_hold = 1'b0;
        o_id_ex_hold    = 1'b0;
        o_ex_mem_flush  = 1'b0;

        // ---------------------------------------------------------------------
        // TH 1: Bus Stall (Dong bang CPU khi AXI dang ban - Uu tien tuyet doi)
        // ---------------------------------------------------------------------
        if (i_axi_i_stall || i_axi_d_stall) begin
            o_pc_write      = 1'b0;
            o_if_id_write   = 1'b0;
            o_pipeline_hold = 1'b1;
        end
        // ---------------------------------------------------------------------
        // TH 2: Trap Taken (Ngat / Exception - Flush IF/ID va ID/EX)
        // ---------------------------------------------------------------------
        else if (i_trap_taken) begin
            o_if_id_flush = 1'b1;
            o_id_ex_flush = 1'b1;
        end
        // ---------------------------------------------------------------------
        // TH 3: Divider Multi-Cycle Stall (Stall PC, IF/ID, ID/EX, Bubble EX/MEM)
        // ---------------------------------------------------------------------
        else if (i_div_busy) begin
            o_pc_write     = 1'b0;
            o_if_id_write  = 1'b0;
            o_id_ex_hold   = 1'b1;
            o_ex_mem_flush = 1'b1;
        end
        // ---------------------------------------------------------------------
        // TH 4: Load-Use, Multiplier-Branch & CSR-Use Hazard (Chen 1 chu ky Bubble vao EX)
        // ---------------------------------------------------------------------
        else if (load_use_hazard || mul_use_hazard || csr_use_hazard) begin
            o_pc_write    = 1'b0;
            o_if_id_write = 1'b0;
            o_id_ex_flush = 1'b1;
        end
        // ---------------------------------------------------------------------
        // TH 5: Control Hazard (Flush IF/ID khi nhay / du doan re nhanh sai / MRET)
        // ---------------------------------------------------------------------
        else if (i_branch_mispredict || i_jump_taken || i_mret) begin
            o_if_id_flush = 1'b1;
        end
    end

endmodule
