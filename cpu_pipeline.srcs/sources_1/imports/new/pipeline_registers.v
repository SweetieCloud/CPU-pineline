/* * File: pipeline_registers.v
 */
`timescale 1ns / 1ps

module if_id_reg(
    input clk, reset, ce,
    input en,           
    input flush,       
    input [15:0] pc_plus_2_in, instr_in,
    
    output reg [15:0] pc_plus_2_out, instr_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_plus_2_out <= 0;
            instr_out     <= 0; 
        end else if (ce) begin  
            if (flush) begin  
                pc_plus_2_out <= 0;
                instr_out     <= 0;
            end else if (en) begin
                pc_plus_2_out <= pc_plus_2_in;
                instr_out     <= instr_in;
            end
        end
    end
endmodule

module id_ex_reg(
    input clk, reset, ce, 
    input flush, 
    
    input RegWrite_in, MemtoReg_in, MemRead_in, MemWrite_in,
    input ALUSrc_in, RegDst_in,
    input [4:0] ALUOp_in,
    input HILO_WriteEn_in, MTSR_WriteEn_in, MFSR_ReadEn_in,
    input IsBGTZ_in,
    
    input [15:0] pc_plus_2_in, read_data1_in, read_data2_in, imm_ext_in,
    input [2:0] rs_in, rt_in, rd_in,
    
    output reg RegWrite_out, MemtoReg_out, MemRead_out, MemWrite_out,
    output reg ALUSrc_out, RegDst_out,
    output reg [4:0] ALUOp_out,
    output reg HILO_WriteEn_out, MTSR_WriteEn_out, MFSR_ReadEn_out,
    output reg IsBGTZ_out,
    
    // Data Outputs
    output reg [15:0] pc_plus_2_out, read_data1_out, read_data2_out, imm_ext_out,
    output reg [2:0] rs_out, rt_out, rd_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            RegWrite_out <= 0; MemtoReg_out <= 0;
            MemRead_out <= 0; MemWrite_out <= 0;
            ALUSrc_out <= 0; RegDst_out <= 0;
            ALUOp_out <= 0;
            HILO_WriteEn_out <= 0; MTSR_WriteEn_out <= 0; MFSR_ReadEn_out <= 0;
            IsBGTZ_out <= 0;
            pc_plus_2_out <= 0; read_data1_out <= 0; read_data2_out <= 0; imm_ext_out <= 0;
            rs_out <= 0; rt_out <= 0; rd_out <= 0;
        end else if (ce) begin
            if (flush) begin  
                RegWrite_out <= 0; MemtoReg_out <= 0;
                MemRead_out <= 0; MemWrite_out <= 0;
                ALUSrc_out <= 0; RegDst_out <= 0;
                ALUOp_out <= 0;
                HILO_WriteEn_out <= 0; MTSR_WriteEn_out <= 0; MFSR_ReadEn_out <= 0;
                IsBGTZ_out <= 0;
   
            end else begin
                RegWrite_out <= RegWrite_in; MemtoReg_out <= MemtoReg_in;
                MemRead_out <= MemRead_in; MemWrite_out <= MemWrite_in;
                ALUSrc_out <= ALUSrc_in; RegDst_out <= RegDst_in;
                ALUOp_out <= ALUOp_in;
                HILO_WriteEn_out <= HILO_WriteEn_in; MTSR_WriteEn_out <= MTSR_WriteEn_in; MFSR_ReadEn_out <= MFSR_ReadEn_in;
                IsBGTZ_out <= IsBGTZ_in;
                
                pc_plus_2_out <= pc_plus_2_in;
                read_data1_out <= read_data1_in; read_data2_out <= read_data2_in;
                imm_ext_out <= imm_ext_in;
                rs_out <= rs_in; rt_out <= rt_in; rd_out <= rd_in;
            end
        end
    end
endmodule

module ex_mem_reg(
    input clk, reset, ce,
    
    input RegWrite_in, MemtoReg_in, MemRead_in, MemWrite_in,
    input HILO_WriteEn_in, MTSR_WriteEn_in,
    
    input [15:0] alu_result_in, write_data_in, hi_out_in, lo_out_in,
    input [2:0]  write_reg_in,
    
    output reg RegWrite_out, MemtoReg_out, MemRead_out, MemWrite_out,
    output reg HILO_WriteEn_out, MTSR_WriteEn_out,
    
    output reg [15:0] alu_result_out, write_data_out, hi_out_out, lo_out_out,
    output reg [2:0]  write_reg_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            RegWrite_out <= 0; MemtoReg_out <= 0;
            MemRead_out <= 0; MemWrite_out <= 0;
            HILO_WriteEn_out <= 0; MTSR_WriteEn_out <= 0;
            alu_result_out <= 0; write_data_out <= 0; hi_out_out <= 0; lo_out_out <= 0;
            write_reg_out <= 0;
        end else if (ce) begin
            RegWrite_out <= RegWrite_in; MemtoReg_out <= MemtoReg_in;
            MemRead_out <= MemRead_in; MemWrite_out <= MemWrite_in;
            HILO_WriteEn_out <= HILO_WriteEn_in; MTSR_WriteEn_out <= MTSR_WriteEn_in;
            
            alu_result_out <= alu_result_in;
            write_data_out <= write_data_in;
            hi_out_out <= hi_out_in;
            lo_out_out <= lo_out_in;
            write_reg_out <= write_reg_in;
        end
    end
endmodule

module mem_wb_reg(
    input clk, reset, ce,
    
    input RegWrite_in, MemtoReg_in, HILO_WriteEn_in, MTSR_WriteEn_in, 
    
    input [15:0] mem_data_in, alu_result_in, hi_out_in, lo_out_in,
    input [2:0]  write_reg_in,
    
    output reg RegWrite_out, MemtoReg_out, HILO_WriteEn_out, MTSR_WriteEn_out,
    
    output reg [15:0] mem_data_out, alu_result_out, hi_out_out, lo_out_out,
    output reg [2:0]  write_reg_out
);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            RegWrite_out <= 0; MemtoReg_out <= 0;
            HILO_WriteEn_out <= 0; MTSR_WriteEn_out <= 0;
            mem_data_out <= 0; alu_result_out <= 0; hi_out_out <= 0; lo_out_out <= 0;
            write_reg_out <= 0;
        end else if (ce) begin
            RegWrite_out <= RegWrite_in; MemtoReg_out <= MemtoReg_in;
            HILO_WriteEn_out <= HILO_WriteEn_in; MTSR_WriteEn_out <= MTSR_WriteEn_in;
            
            mem_data_out <= mem_data_in;
            alu_result_out <= alu_result_in;
            hi_out_out <= hi_out_in;
            lo_out_out <= lo_out_in;
            write_reg_out <= write_reg_in;
        end
    end
endmodule
