/* * Module: forwarding_unit
 */
`timescale 1ns / 1ps

module forwarding_unit(
    input [2:0] ID_EX_rs,
    input [2:0] ID_EX_rt,
    
    input [2:0] EX_MEM_RegWriteAddr,
    input EX_MEM_RegWrite,      
    
    input [2:0] MEM_WB_RegWriteAddr,
    input MEM_WB_RegWrite,      
    
    output reg [1:0] ForwardA, // Cho toán hạng A (rs)
    output reg [1:0] ForwardB  // Cho toán hạng B (rt)
);

    always @(*) begin
        // 1. Forwarding cho Toán hạng A (rs)
        ForwardA = 2'b00; 
        if (EX_MEM_RegWrite && (EX_MEM_RegWriteAddr != 0) && (EX_MEM_RegWriteAddr == ID_EX_rs)) begin
            ForwardA = 2'b10;
        end
        else if (MEM_WB_RegWrite && (MEM_WB_RegWriteAddr != 0) && (MEM_WB_RegWriteAddr == ID_EX_rs)) begin
            ForwardA = 2'b01;
        end

        ForwardB = 2'b00;
        
        if (EX_MEM_RegWrite && (EX_MEM_RegWriteAddr != 0) && (EX_MEM_RegWriteAddr == ID_EX_rt)) begin
            ForwardB = 2'b10;
        end
        else if (MEM_WB_RegWrite && (MEM_WB_RegWriteAddr != 0) && (MEM_WB_RegWriteAddr == ID_EX_rt)) begin
            ForwardB = 2'b01;
        end
    end

endmodule