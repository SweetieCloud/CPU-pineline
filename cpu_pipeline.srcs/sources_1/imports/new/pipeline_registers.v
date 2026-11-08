`timescale 1ns / 1ps
`include "defines.vh"

// =============================================================================
// 1. IF/ID PIPELINE REGISTER
// =============================================================================
module if_id_reg (
    input  wire                   i_clk,
    input  wire                   i_rst_n,
    input  wire                   i_hold,   // 1: Dong bang thanh ghi (Stall)
    input  wire                   i_flush,  // 1: Xoa lenh (Flush - NOP)
    input  wire                   i_valid,  // 1: Lenh tu I-Bus hop le
    input  wire [`ADDR_WIDTH-1:0] i_pc,
    input  wire [`DATA_WIDTH-1:0] i_instr,
    input  wire                   i_pred_taken,  // Ket qua du doan re nhanh tai IF
    input  wire [`ADDR_WIDTH-1:0] i_pred_target, // Dia chi dich du doan tai IF
    output reg  [`ADDR_WIDTH-1:0] o_pc,
    output reg  [`DATA_WIDTH-1:0] o_instr,
    output reg                    o_pred_taken,
    output reg  [`ADDR_WIDTH-1:0] o_pred_target
);
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_pc          <= `ADDR_WIDTH'b0;
            o_instr       <= 32'h00000013; // NOP (addi x0, x0, 0)
            o_pred_taken  <= 1'b0;
            o_pred_target <= `ADDR_WIDTH'b0;
        end else if (!i_hold) begin
            if (i_flush) begin
                o_pc          <= `ADDR_WIDTH'b0;
                o_instr       <= 32'h00000013; // NOP
                o_pred_taken  <= 1'b0;
                o_pred_target <= `ADDR_WIDTH'b0;
            end else if (i_valid) begin
                o_pc          <= i_pc;
                o_instr       <= i_instr;
                o_pred_taken  <= i_pred_taken;
                o_pred_target <= i_pred_target;
            end else begin
                // Khi khong co lenh hop le moi tu I-Bus, xoa IF/ID ve NOP (Bubble)
                o_pc          <= `ADDR_WIDTH'b0;
                o_instr       <= 32'h00000013; // NOP
                o_pred_taken  <= 1'b0;
                o_pred_target <= `ADDR_WIDTH'b0;
            end
        end
    end
endmodule

// =============================================================================
// 2. ID/EX PIPELINE REGISTER
// =============================================================================
module id_ex_reg (
    input  wire                   i_clk,
    input  wire                   i_rst_n,
    input  wire                   i_hold,
    input  wire                   i_flush,

    // Tin hieu dieu khien tu ID Stage
    input  wire                   i_reg_write,
    input  wire [1:0]             i_wb_src,
    input  wire                   i_alu_src_a,
    input  wire                   i_alu_src_b,
    input  wire [3:0]             i_alu_op,
    input  wire                   i_mem_req_read,
    input  wire                   i_mem_req_write,
    input  wire [1:0]             i_csr_op,
    input  wire                   i_ecall_halt,
    input  wire                   i_is_mul,        // 1: Phep nhan RV32M
    input  wire                   i_is_div,        // 1: Phep chia RV32M

    // Du lieu tu ID Stage
    input  wire [`ADDR_WIDTH-1:0] i_pc,
    input  wire [`DATA_WIDTH-1:0] i_rs1_data,
    input  wire [`DATA_WIDTH-1:0] i_rs2_data,
    input  wire [`DATA_WIDTH-1:0] i_imm_ext,
    input  wire [4:0]             i_rs1_addr,
    input  wire [4:0]             i_rs2_addr,
    input  wire [4:0]             i_rd_addr,
    input  wire [2:0]             i_funct3,
    input  wire [11:0]            i_csr_addr,

    // Ngo ra sang EX Stage
    output reg                    o_reg_write,
    output reg  [1:0]             o_wb_src,
    output reg                    o_alu_src_a,
    output reg                    o_alu_src_b,
    output reg  [3:0]             o_alu_op,
    output reg                    o_mem_req_read,
    output reg                    o_mem_req_write,
    output reg  [1:0]             o_csr_op,
    output reg                    o_ecall_halt,
    output reg                    o_is_mul,
    output reg                    o_is_div,
    output reg  [`ADDR_WIDTH-1:0] o_pc,
    output reg  [`DATA_WIDTH-1:0] o_rs1_data,
    output reg  [`DATA_WIDTH-1:0] o_rs2_data,
    output reg  [`DATA_WIDTH-1:0] o_imm_ext,
    output reg  [4:0]             o_rs1_addr,
    output reg  [4:0]             o_rs2_addr,
    output reg  [4:0]             o_rd_addr,
    output reg  [2:0]             o_funct3,
    output reg  [11:0]            o_csr_addr
);
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_reg_write     <= 1'b0;
            o_wb_src        <= `WB_SRC_ALU;
            o_alu_src_a     <= 1'b0;
            o_alu_src_b     <= 1'b0;
            o_alu_op        <= `ALU_ADD;
            o_mem_req_read  <= 1'b0;
            o_mem_req_write <= 1'b0;
            o_csr_op        <= 2'b00;
            o_ecall_halt    <= 1'b0;
            o_is_mul        <= 1'b0;
            o_is_div        <= 1'b0;
            o_pc            <= `ADDR_WIDTH'b0;
            o_rs1_data      <= `DATA_WIDTH'b0;
            o_rs2_data      <= `DATA_WIDTH'b0;
            o_imm_ext       <= `DATA_WIDTH'b0;
            o_rs1_addr      <= 5'b0;
            o_rs2_addr      <= 5'b0;
            o_rd_addr       <= 5'b0;
            o_funct3        <= 3'b0;
            o_csr_addr      <= 12'b0;
        end else if (!i_hold) begin
            if (i_flush) begin
                o_reg_write     <= 1'b0;
                o_wb_src        <= `WB_SRC_ALU;
                o_alu_src_a     <= 1'b0;
                o_alu_src_b     <= 1'b0;
                o_alu_op        <= `ALU_ADD;
                o_mem_req_read  <= 1'b0;
                o_mem_req_write <= 1'b0;
                o_csr_op        <= 2'b00;
                o_ecall_halt    <= 1'b0;
                o_is_mul        <= 1'b0;
                o_is_div        <= 1'b0;
                o_pc            <= `ADDR_WIDTH'b0;
                o_rs1_data      <= `DATA_WIDTH'b0;
                o_rs2_data      <= `DATA_WIDTH'b0;
                o_imm_ext       <= `DATA_WIDTH'b0;
                o_rs1_addr      <= 5'b0;
                o_rs2_addr      <= 5'b0;
                o_rd_addr       <= 5'b0;
                o_funct3        <= 3'b0;
                o_csr_addr      <= 12'b0;
            end else begin
                o_reg_write     <= i_reg_write;
                o_wb_src        <= i_wb_src;
                o_alu_src_a     <= i_alu_src_a;
                o_alu_src_b     <= i_alu_src_b;
                o_alu_op        <= i_alu_op;
                o_mem_req_read  <= i_mem_req_read;
                o_mem_req_write <= i_mem_req_write;
                o_csr_op        <= i_csr_op;
                o_ecall_halt    <= i_ecall_halt;
                o_is_mul        <= i_is_mul;
                o_is_div        <= i_is_div;
                o_pc            <= i_pc;
                o_rs1_data      <= i_rs1_data;
                o_rs2_data      <= i_rs2_data;
                o_imm_ext       <= i_imm_ext;
                o_rs1_addr      <= i_rs1_addr;
                o_rs2_addr      <= i_rs2_addr;
                o_rd_addr       <= i_rd_addr;
                o_funct3        <= i_funct3;
                o_csr_addr      <= i_csr_addr;
            end
        end
    end
endmodule

// =============================================================================
// 3. EX/MEM PIPELINE REGISTER
// =============================================================================
module ex_mem_reg (
    input  wire                   i_clk,
    input  wire                   i_rst_n,
    input  wire                   i_hold,
    input  wire                   i_flush, // 1: Xoa lenh (Chen Bubble khi Divider ban)

    // Tin hieu dieu khien tu EX Stage
    input  wire                   i_reg_write,
    input  wire [1:0]             i_wb_src,
    input  wire                   i_mem_req_read,
    input  wire                   i_mem_req_write,
    input  wire [1:0]             i_csr_op,
    input  wire                   i_ecall_halt,

    // Du lieu tu EX Stage
    input  wire [`ADDR_WIDTH-1:0] i_pc,
    input  wire [`DATA_WIDTH-1:0] i_alu_result,
    input  wire [`DATA_WIDTH-1:0] i_rs2_data,
    input  wire [4:0]             i_rd_addr,
    input  wire [2:0]             i_funct3,
    input  wire [11:0]            i_csr_addr,
    input  wire [`DATA_WIDTH-1:0] i_csr_wdata,

    // Ngo ra sang MEM Stage
    output reg                    o_reg_write,
    output reg  [1:0]             o_wb_src,
    output reg                    o_mem_req_read,
    output reg                    o_mem_req_write,
    output reg  [1:0]             o_csr_op,
    output reg                    o_ecall_halt,
    output reg  [`ADDR_WIDTH-1:0] o_pc,
    output reg  [`DATA_WIDTH-1:0] o_alu_result,
    output reg  [`DATA_WIDTH-1:0] o_rs2_data,
    output reg  [4:0]             o_rd_addr,
    output reg  [2:0]             o_funct3,
    output reg  [11:0]            o_csr_addr,
    output reg  [`DATA_WIDTH-1:0] o_csr_wdata
);
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_reg_write     <= 1'b0;
            o_wb_src        <= `WB_SRC_ALU;
            o_mem_req_read  <= 1'b0;
            o_mem_req_write <= 1'b0;
            o_csr_op        <= 2'b00;
            o_ecall_halt    <= 1'b0;
            o_pc            <= `ADDR_WIDTH'b0;
            o_alu_result    <= `DATA_WIDTH'b0;
            o_rs2_data      <= `DATA_WIDTH'b0;
            o_rd_addr       <= 5'b0;
            o_funct3        <= 3'b0;
            o_csr_addr      <= 12'b0;
            o_csr_wdata     <= `DATA_WIDTH'b0;
        end else if (!i_hold) begin
            if (i_flush) begin
                o_reg_write     <= 1'b0;
                o_wb_src        <= `WB_SRC_ALU;
                o_mem_req_read  <= 1'b0;
                o_mem_req_write <= 1'b0;
                o_csr_op        <= 2'b00;
                o_ecall_halt    <= 1'b0;
                o_pc            <= `ADDR_WIDTH'b0;
                o_alu_result    <= `DATA_WIDTH'b0;
                o_rs2_data      <= `DATA_WIDTH'b0;
                o_rd_addr       <= 5'b0;
                o_funct3        <= 3'b0;
                o_csr_addr      <= 12'b0;
                o_csr_wdata     <= `DATA_WIDTH'b0;
            end else begin
                o_reg_write     <= i_reg_write;
                o_wb_src        <= i_wb_src;
                o_mem_req_read  <= i_mem_req_read;
                o_mem_req_write <= i_mem_req_write;
                o_csr_op        <= i_csr_op;
                o_ecall_halt    <= i_ecall_halt;
                o_pc            <= i_pc;
                o_alu_result    <= i_alu_result;
                o_rs2_data      <= i_rs2_data;
                o_rd_addr       <= i_rd_addr;
                o_funct3        <= i_funct3;
                o_csr_addr      <= i_csr_addr;
                o_csr_wdata     <= i_csr_wdata;
            end
        end
    end
endmodule

// =============================================================================
// 4. MEM/WB PIPELINE REGISTER
// =============================================================================
module mem_wb_reg (
    input  wire                   i_clk,
    input  wire                   i_rst_n,
    input  wire                   i_hold,

    // Tin hieu dieu khien tu MEM Stage
    input  wire                   i_reg_write,
    input  wire [1:0]             i_wb_src,
    input  wire [1:0]             i_csr_op,
    input  wire                   i_ecall_halt,

    // Du lieu tu MEM Stage
    input  wire [`ADDR_WIDTH-1:0] i_pc,
    input  wire [`DATA_WIDTH-1:0] i_mem_rdata,
    input  wire [`DATA_WIDTH-1:0] i_alu_result,
    input  wire [4:0]             i_rd_addr,
    input  wire [11:0]            i_csr_addr,
    input  wire [`DATA_WIDTH-1:0] i_csr_wdata,

    // Ngo ra sang WB Stage
    output reg                    o_reg_write,
    output reg  [1:0]             o_wb_src,
    output reg  [1:0]             o_csr_op,
    output reg                    o_ecall_halt,
    output reg  [`ADDR_WIDTH-1:0] o_pc,
    output reg  [`DATA_WIDTH-1:0] o_mem_rdata,
    output reg  [`DATA_WIDTH-1:0] o_alu_result,
    output reg  [4:0]             o_rd_addr,
    output reg  [11:0]            o_csr_addr,
    output reg  [`DATA_WIDTH-1:0] o_csr_wdata
);
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_reg_write  <= 1'b0;
            o_wb_src     <= `WB_SRC_ALU;
            o_csr_op     <= 2'b00;
            o_ecall_halt <= 1'b0;
            o_pc         <= `ADDR_WIDTH'b0;
            o_mem_rdata  <= `DATA_WIDTH'b0;
            o_alu_result <= `DATA_WIDTH'b0;
            o_rd_addr    <= 5'b0;
            o_csr_addr   <= 12'b0;
            o_csr_wdata  <= `DATA_WIDTH'b0;
        end else if (!i_hold) begin
            o_reg_write  <= i_reg_write;
            o_wb_src     <= i_wb_src;
            o_csr_op     <= i_csr_op;
            o_ecall_halt <= i_ecall_halt;
            o_pc         <= i_pc;
            o_mem_rdata  <= i_mem_rdata;
            o_alu_result <= i_alu_result;
            o_rd_addr    <= i_rd_addr;
            o_csr_addr   <= i_csr_addr;
            o_csr_wdata  <= i_csr_wdata;
        end
    end
endmodule
