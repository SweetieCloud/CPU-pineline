/* * Module: register_file
 */
`timescale 1ns / 1ps

module register_file(
    input clk, rst,
    input ce,                   // [M?I] Thêm Clock Enable
    input [2:0] ReadAddr_rs,
    input [2:0] ReadAddr_rt,
    output [15:0] ReadData_rs,
    output [15:0] ReadData_rt,
    
    input WriteEn,             
    input [2:0] WriteAddr,
    input [15:0] WriteData,
    
    input HILO_WriteEn,       
    input [15:0] HI_in,
    input [15:0] LO_in,
    
    input MTSR_WriteEn,        
    input [2:0] Funct_MTSR,     
    input [15:0] Data_MTSR,  
    
    input MFSR_ReadEn,        
    input [2:0] Funct_MFSR,    
    output reg [15:0] ReadData_MFSR
);
    // 8 thanh ghi ?a d?ng 16-bit
    reg [15:0] registers [0:7];
    
    // Thanh ghi ??c bi?t
    reg [15:0] HI, LO;
    reg [15:0] RA, AT;
    
    integer i;

    // --- 1. WRITE OPERATION (?ã b?c thêm CE) ---
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1) registers[i] <= 0;
            HI <= 0; LO <= 0; RA <= 0; AT <= 0;
        end
        else if (ce) begin // [M?I] Ch? ghi khi có Clock Enable
            if (WriteEn && (WriteAddr != 0)) begin // Không bao gi? ghi vào $0
                registers[WriteAddr] <= WriteData;
            end
            
            if (HILO_WriteEn) begin
                HI <= HI_in;
                LO <= LO_in;
            end
            
            if (MTSR_WriteEn) begin
                case (Funct_MTSR)
                    3'b010: RA <= Data_MTSR; // mtra
                    3'b011: AT <= Data_MTSR; // mtat
                    3'b100: HI <= Data_MTSR; // mthi
                    3'b101: LO <= Data_MTSR; // mtlo
                endcase
            end
        end
    end
    
    // --- 2. READ OPERATION (T? h?p - Combinational) ---
    assign ReadData_rs = (ReadAddr_rs == 0) ? 16'h0000 : registers[ReadAddr_rs];
    assign ReadData_rt = (ReadAddr_rt == 0) ? 16'h0000 : registers[ReadAddr_rt];
    
    always @(*) begin
        if (MFSR_ReadEn) begin
            case (Funct_MFSR)
                3'b000: ReadData_MFSR = 16'h0000;
                3'b001: ReadData_MFSR = 16'h0000;
                3'b010: ReadData_MFSR = RA;
                3'b011: ReadData_MFSR = AT;
                3'b100: ReadData_MFSR = HI;
                3'b101: ReadData_MFSR = LO;
                default: ReadData_MFSR = 16'h0000;
            endcase
        end else begin
            ReadData_MFSR = 16'h0000;
        end
    end
endmodule