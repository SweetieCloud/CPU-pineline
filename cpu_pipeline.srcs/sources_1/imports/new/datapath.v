/* * Module: datapath (Pipelined Version - Industrial Standard)
 */
`timescale 1ns / 1ps

module datapath(
    input clk, 
    input ce,            
    input rst,
    output halt,          
    output [15:0] current_pc,       
    
    // I/O Memory-Mapped
    output [15:0] mem_addr_out,
    output [15:0] mem_writedata_out,
    output mem_write_en_out,
    output [15:0] debug_wb_data
);

    // ==========================================
    // KHAI BÁO DÂY (WIRES) 
    // ==========================================
    wire [15:0] pc_next, pc_current, pc_plus_2;
    wire [15:0] instr_IF;
    wire PCWrite, IF_ID_Write, IF_ID_Flush;

    wire [15:0] pc_plus_2_ID, instr_ID, read_data1_ID, read_data2_ID, imm_ext_ID;
    wire Ctrl_JumpReg;
    wire [15:0] mfsr_val_ID;  
    
    wire Ctrl_RegWrite, Ctrl_MemtoReg, Ctrl_MemRead, Ctrl_MemWrite;
    wire Ctrl_ALUSrc, Ctrl_RegDst, Ctrl_Branch, Ctrl_Jump;
    wire Ctrl_HILO_Write, Ctrl_MTSR_Write, Ctrl_MFSR_Read;
    wire [4:0] Ctrl_ALUOp;
    wire Ctrl_IsBGTZ, Ctrl_Halt;
    wire Hazard_ID_EX_Flush, ID_Flush_Final;

    wire [15:0] pc_plus_2_EX, read_data1_EX, read_data2_EX, imm_ext_EX;
    wire [2:0]  rs_EX, rt_EX, rd_EX;
    wire [4:0]  alu_op_EX;
    wire        reg_write_EX, mem_to_reg_EX, mem_read_EX, mem_write_EX;
    wire        alu_src_EX, reg_dst_EX, hilo_write_EX, mtsr_write_EX, mfsr_read_EX;
    wire        IsBGTZ_EX;

    wire [1:0]  forward_A, forward_B;
    wire [15:0] alu_in_A, alu_in_B_temp, alu_in_B_final;
    wire [15:0] alu_result_EX, hi_out_EX, lo_out_EX;
    wire        zero_flag_EX, negative_flag_EX, gtz_flag_EX;
    wire [2:0]  write_reg_EX;

    wire        branch_taken;
    wire [15:0] branch_target_addr;

    wire        reg_write_MEM, mem_to_reg_MEM, mem_read_MEM, mem_write_MEM;
    wire        hilo_write_MEM, mtsr_write_MEM;
    wire [15:0] alu_result_MEM, write_data_MEM, hi_out_MEM, lo_out_MEM;
    wire [2:0]  write_reg_MEM;
    wire [15:0] mem_read_data_MEM;

    wire        reg_write_WB, mem_to_reg_WB, hilo_write_WB, mtsr_write_WB;
    wire [15:0] mem_data_WB, alu_result_WB, hi_out_WB, lo_out_WB;
    wire [2:0]  write_reg_WB;
    wire [15:0] final_write_data_WB;

    assign halt = Ctrl_Halt;
    assign mem_addr_out = alu_result_MEM;
    assign mem_writedata_out = write_data_MEM;
    assign mem_write_en_out = mem_write_MEM;
    assign debug_wb_data = final_write_data_WB;

    // ==========================================
    // 1. IF STAGE
    // ==========================================
    wire [15:0] jump_target_ID = {pc_plus_2_ID[15:13], instr_ID[11:0], 1'b0};
    wire        jump_taken_ID = (instr_ID[15:12] == 4'b0111);
    
    assign pc_next = (branch_taken)  ? branch_target_addr : 
                     (jump_taken_ID) ? jump_target_ID :     
                     pc_plus_2;

    wire final_pc_write = PCWrite & (~Ctrl_Halt);
    wire final_if_id_write = IF_ID_Write & (~Ctrl_Halt);

    reg [15:0] pc;
    always @(posedge clk or posedge rst) begin
        if (rst) 
            pc <= 0;
        else if (ce) begin // Clock Enable
            if (final_pc_write) pc <= pc_next;
        end
    end
    
    assign pc_plus_2 = pc + 2;
    assign current_pc = pc;

    instruction_memory imem (
        .Address(pc),
        .Instruction(instr_IF)
    );

    assign IF_ID_Flush = branch_taken || jump_taken_ID; 

    if_id_reg IF_ID (
        .clk(clk), 
        .ce(ce),          
        .reset(rst),
        .en(final_if_id_write),
        .flush(IF_ID_Flush),
        .pc_plus_2_in(pc_plus_2),
        .instr_in(instr_IF),
        .pc_plus_2_out(pc_plus_2_ID),
        .instr_out(instr_ID)
    );

    // ==========================================
    // 2. ID STAGE
    // ==========================================
    control_unit ctrl_unit (
        .opcode(instr_ID[15:12]),
        .funct(instr_ID[2:0]),
        .RegWrite(Ctrl_RegWrite), .MemtoReg(Ctrl_MemtoReg),
        .MemRead(Ctrl_MemRead), .MemWrite(Ctrl_MemWrite),
        .ALUSrc(Ctrl_ALUSrc), .RegDst(Ctrl_RegDst),
        .Branch(Ctrl_Branch), .Jump(Ctrl_Jump), .JumpReg(Ctrl_JumpReg), .ALUOp(Ctrl_ALUOp),
        .HILO_WriteEn(Ctrl_HILO_Write), .MTSR_WriteEn(Ctrl_MTSR_Write), 
        .MFSR_ReadEn(Ctrl_MFSR_Read), .IsBGTZ(Ctrl_IsBGTZ),
        .Halt(Ctrl_Halt)        
    );

    register_file reg_file (
        .clk(clk), 
        .ce(ce),        
        .rst(rst),
        .ReadAddr_rs(instr_ID[11:9]),
        .ReadAddr_rt(instr_ID[8:6]),
        .ReadData_rs(read_data1_ID),
        .ReadData_rt(read_data2_ID),
        .WriteEn(reg_write_WB),
        .WriteAddr(write_reg_WB),
        .WriteData(final_write_data_WB),
        .HILO_WriteEn(hilo_write_WB),
        .HI_in(hi_out_WB), .LO_in(lo_out_WB),
        .MTSR_WriteEn(mtsr_write_WB),
        .Funct_MTSR(write_reg_WB), 
        .Data_MTSR(final_write_data_WB),
        .MFSR_ReadEn(Ctrl_MFSR_Read),
        .Funct_MFSR(instr_ID[2:0]),
        .ReadData_MFSR(mfsr_val_ID)
    );
    
    sign_extend se (
        .Imm_6bit(instr_ID[5:0]),
        .Imm_16bit(imm_ext_ID)
    );

    hazard_unit hazard (
        .ID_EX_MemRead(mem_read_EX),
        .ID_EX_rt(rt_EX),
        .IF_ID_rs(instr_ID[11:9]),
        .IF_ID_rt(instr_ID[8:6]),
        .Branch_Taken(branch_taken),
        .PCWrite(PCWrite),
        .IF_ID_Write(IF_ID_Write),
        .IF_ID_Flush(),  
        .ID_EX_Flush(Hazard_ID_EX_Flush)
    );
    
    assign ID_Flush_Final = Hazard_ID_EX_Flush || branch_taken;

    id_ex_reg ID_EX (
        .clk(clk), 
        .ce(ce),         
        .reset(rst),
        .flush(ID_Flush_Final),
        .RegWrite_in(Ctrl_RegWrite), .MemtoReg_in(Ctrl_MemtoReg),
        .MemRead_in(Ctrl_MemRead), .MemWrite_in(Ctrl_MemWrite),
        .ALUSrc_in(Ctrl_ALUSrc), .RegDst_in(Ctrl_RegDst),
        .ALUOp_in(Ctrl_ALUOp),
        .HILO_WriteEn_in(Ctrl_HILO_Write), .MTSR_WriteEn_in(Ctrl_MTSR_Write), 
        .MFSR_ReadEn_in(Ctrl_MFSR_Read),
        .pc_plus_2_in(pc_plus_2_ID),
        .read_data1_in(Ctrl_MFSR_Read ? mfsr_val_ID : read_data1_ID),
        .read_data2_in(read_data2_ID),
        .imm_ext_in(imm_ext_ID),
        .rs_in(instr_ID[11:9]),
        .rt_in(instr_ID[8:6]),
        .rd_in(instr_ID[5:3]),
        .IsBGTZ_in(Ctrl_IsBGTZ),
        
        .RegWrite_out(reg_write_EX), .MemtoReg_out(mem_to_reg_EX),
        .MemRead_out(mem_read_EX), .MemWrite_out(mem_write_EX),
        .ALUSrc_out(alu_src_EX), .RegDst_out(reg_dst_EX),
        .ALUOp_out(alu_op_EX),
        .HILO_WriteEn_out(hilo_write_EX), .MTSR_WriteEn_out(mtsr_write_EX),
        .MFSR_ReadEn_out(mfsr_read_EX),
        .pc_plus_2_out(pc_plus_2_EX),
        .read_data1_out(read_data1_EX),
        .read_data2_out(read_data2_EX),
        .imm_ext_out(imm_ext_EX),
        .rs_out(rs_EX), .rt_out(rt_EX), .rd_out(rd_EX),
        .IsBGTZ_out(IsBGTZ_EX)
    );

    // ==========================================
    // 3. EX STAGE
    // ==========================================
    forwarding_unit fwd_unit (
        .ID_EX_rs(rs_EX),
        .ID_EX_rt(rt_EX),
        .EX_MEM_RegWriteAddr(write_reg_MEM),
        .EX_MEM_RegWrite(reg_write_MEM),
        .MEM_WB_RegWriteAddr(write_reg_WB),
        .MEM_WB_RegWrite(reg_write_WB),
        .ForwardA(forward_A),
        .ForwardB(forward_B)
    );

    assign alu_in_A = (forward_A == 2'b10) ? alu_result_MEM :
                      (forward_A == 2'b01) ? final_write_data_WB :
                      read_data1_EX;
                      
    assign alu_in_B_temp = (forward_B == 2'b10) ? alu_result_MEM :
                           (forward_B == 2'b01) ? final_write_data_WB :
                           read_data2_EX;
                           
    assign alu_in_B_final = (alu_src_EX) ? imm_ext_EX : alu_in_B_temp;

    // [S?A L?I] Logic c? GTZ m?i (BGTZ nh?y khi > 0 t?c là Không âm và Không b?ng 0)
    assign gtz_flag_EX = (!negative_flag_EX) && (!zero_flag_EX);

    alu alu_inst (
        .A(alu_in_A),
        .B(alu_in_B_final),
        .ALUOp(alu_op_EX),
        .Result(alu_result_EX),
        .HILO_Out({hi_out_EX, lo_out_EX}),  
        .Zero(zero_flag_EX), 
        .Negative(negative_flag_EX),    
        .Overflow()  
    );

    assign write_reg_EX = (reg_dst_EX) ? rd_EX : rt_EX;

    wire [15:0] branch_offset = imm_ext_EX << 1;
    assign branch_target_addr = pc_plus_2_EX + branch_offset;

    wire is_branch_op = (alu_op_EX == 5'b00100) && (reg_write_EX == 0);
    assign branch_taken = is_branch_op && 
                          ( (IsBGTZ_EX && gtz_flag_EX) || (!IsBGTZ_EX && !zero_flag_EX) );

    ex_mem_reg EX_MEM (
        .clk(clk), 
        .ce(ce),           
        .reset(rst),
        .RegWrite_in(reg_write_EX), .MemtoReg_in(mem_to_reg_EX),
        .MemRead_in(mem_read_EX), .MemWrite_in(mem_write_EX),
        .HILO_WriteEn_in(hilo_write_EX), .MTSR_WriteEn_in(mtsr_write_EX),
        .alu_result_in(alu_result_EX),
        .write_data_in(alu_in_B_temp), 
        .hi_out_in(hi_out_EX), .lo_out_in(lo_out_EX),
        .write_reg_in(write_reg_EX),
        
        .RegWrite_out(reg_write_MEM), .MemtoReg_out(mem_to_reg_MEM),
        .MemRead_out(mem_read_MEM), .MemWrite_out(mem_write_MEM),
        .HILO_WriteEn_out(hilo_write_MEM), .MTSR_WriteEn_out(mtsr_write_MEM),
        .alu_result_out(alu_result_MEM),
        .write_data_out(write_data_MEM),
        .hi_out_out(hi_out_MEM), .lo_out_out(lo_out_MEM),
        .write_reg_out(write_reg_MEM)
    );

    // ==========================================
    // 4. MEM STAGE
    // ==========================================
    data_memory dmem (
        .clk(clk),
        .ce(ce),            
        .Address(alu_result_MEM),
        .DataIn(write_data_MEM),
        .MemRead(mem_read_MEM),
        .MemWrite(mem_write_MEM),
        .DataOut(mem_read_data_MEM)
    );

    mem_wb_reg MEM_WB (
        .clk(clk), 
        .ce(ce),           
        .reset(rst),
        .RegWrite_in(reg_write_MEM), .MemtoReg_in(mem_to_reg_MEM),
        .HILO_WriteEn_in(hilo_write_MEM), .MTSR_WriteEn_in(mtsr_write_MEM),
        .mem_data_in(mem_read_data_MEM),
        .alu_result_in(alu_result_MEM),
        .hi_out_in(hi_out_MEM), .lo_out_in(lo_out_MEM),
        .write_reg_in(write_reg_MEM),
        
        .RegWrite_out(reg_write_WB), .MemtoReg_out(mem_to_reg_WB),
        .HILO_WriteEn_out(hilo_write_WB), .MTSR_WriteEn_out(mtsr_write_WB),
        .mem_data_out(mem_data_WB),
        .alu_result_out(alu_result_WB),
        .hi_out_out(hi_out_WB), .lo_out_out(lo_out_WB),
        .write_reg_out(write_reg_WB)
    );

    // ==========================================
    // 5. WB STAGE
    // ==========================================
    assign final_write_data_WB = (mem_to_reg_WB) ? mem_data_WB : alu_result_WB;

endmodule
