`timescale 1ns / 1ps
`include "defines.vh"

module register_file (
    input  wire                       i_clk,
    input  wire                       i_rst_n,

    // Cong doc 1 (RS1)
    input  wire [`REG_ADDR_WIDTH-1:0]  i_rs1_addr,
    output wire [`DATA_WIDTH-1:0]      o_rs1_data,

    // Cong doc 2 (RS2)
    input  wire [`REG_ADDR_WIDTH-1:0]  i_rs2_addr,
    output wire [`DATA_WIDTH-1:0]      o_rs2_data,

    // Cong ghi (RD)
    input  wire                       i_reg_write,
    input  wire [`REG_ADDR_WIDTH-1:0]  i_rd_addr,
    input  wire [`DATA_WIDTH-1:0]      i_rd_data
);

    // Mang 32 thanh ghi 32-bit (x0 - x31)
    // Khong su dung reset bat dong bo tren mang nho de cho phep Vivado infer RAM32M (Distributed RAM)
    (* ram_style = "distributed" *) reg [`DATA_WIDTH-1:0] registers [`REG_NUM-1:0];

    // Khoi tao ban dau cho mo phong (Simulation only)
`ifndef SYNTHESIS
    integer k;
    initial begin
        for (k = 0; k < `REG_NUM; k = k + 1) begin
            registers[k] = `DATA_WIDTH'b0;
        end
    end
`endif

    // -------------------------------------------------------------------------
    // 1. Doc bat dong bo tich hop Internal Forwarding (Write-Through)
    // -------------------------------------------------------------------------
    // Uu tien 1: Doc x0 -> Luon tra ve 0
    // Uu tien 2: Dia chi doc trung dia chi ghi o WB stage va co lenh ghi -> Bypass i_rd_data
    // Uu tien 3: Doc truc tiep tu mang thanh ghi
    assign o_rs1_data = (i_rs1_addr == 5'b00000) ? `DATA_WIDTH'b0 :
                        ((i_rs1_addr == i_rd_addr) && i_reg_write) ? i_rd_data :
                        registers[i_rs1_addr];

    assign o_rs2_data = (i_rs2_addr == 5'b00000) ? `DATA_WIDTH'b0 :
                        ((i_rs2_addr == i_rd_addr) && i_reg_write) ? i_rd_data :
                        registers[i_rs2_addr];

    // -------------------------------------------------------------------------
    // 2. Ghi dong bo theo suon duong xung nhip (Bao ve tuyet doi x0)
    // -------------------------------------------------------------------------
    always @(posedge i_clk) begin
        if (i_reg_write && (i_rd_addr != 5'b00000)) begin
            registers[i_rd_addr] <= i_rd_data;
        end
    end

endmodule
