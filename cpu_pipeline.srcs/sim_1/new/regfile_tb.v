`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/04/2026 11:33:21 PM
// Design Name: 
// Module Name: regfile_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module regfile_tb;

    // Inputs
    reg clk, rst, ce;
    reg [2:0] ReadAddr_rs, ReadAddr_rt, WriteAddr;
    reg WriteEn;
    reg [15:0] WriteData;
    
    reg HILO_WriteEn, MTSR_WriteEn, MFSR_ReadEn;
    reg [15:0] HI_in, LO_in, Data_MTSR;
    reg [2:0] Funct_MTSR, Funct_MFSR;

    // Outputs
    wire [15:0] ReadData_rs, ReadData_rt, ReadData_MFSR;

    // Instantiate Register File
    register_file uut (
        .clk(clk), .rst(rst), .ce(ce),
        .ReadAddr_rs(ReadAddr_rs), .ReadAddr_rt(ReadAddr_rt),
        .ReadData_rs(ReadData_rs), .ReadData_rt(ReadData_rt),
        .WriteEn(WriteEn), .WriteAddr(WriteAddr), .WriteData(WriteData),
        .HILO_WriteEn(HILO_WriteEn), .HI_in(HI_in), .LO_in(LO_in),
        .MTSR_WriteEn(MTSR_WriteEn), .Funct_MTSR(Funct_MTSR), .Data_MTSR(Data_MTSR),
        .MFSR_ReadEn(MFSR_ReadEn), .Funct_MFSR(Funct_MFSR), .ReadData_MFSR(ReadData_MFSR)
    );

    // Clock gen
    initial begin clk = 0; forever #5 clk = ~clk; end

    integer errors = 0;

    initial begin
        $display("\n=== STARTING REGISTER FILE UNIT TEST ===");
        
        // 1. INITIALIZATION & RESET TEST
        rst = 1; ce = 1; WriteEn = 0; HILO_WriteEn = 0; MTSR_WriteEn = 0; MFSR_ReadEn = 0;
        #15; rst = 0;

        // 2. TEST: GHI VÀO THANH GHI $0 (Zero Protection)
        // Mong ??i: Dù có c? ghi giá tr? 9999 vào $0, ??c ra v?n ph?i là 0
        WriteAddr = 0; WriteData = 16'd9999; WriteEn = 1;
        #10;
        WriteEn = 0; ReadAddr_rs = 0;
        #1; // ??i combinational logic
        if (ReadData_rs !== 16'd0) begin $display("[FAIL] Zero Register written!"); errors = errors + 1; end
        else $display("[PASS] Zero Register Protection");

        // 3. TEST: CLOCK ENABLE (CE) PROTECTION
        // Mong ??i: Khi ce = 0, ghi vào $1 s? th?t b?i
        ce = 0; WriteAddr = 1; WriteData = 16'hAAAA; WriteEn = 1;
        #10;
        ce = 1; WriteEn = 0; ReadAddr_rs = 1;
        #1;
        if (ReadData_rs === 16'hAAAA) begin $display("[FAIL] CE bypassed!"); errors = errors + 1; end
        else $display("[PASS] Clock Enable Protection");

        // 4. TEST: BÌNH TH??NG (Ghi $2, ??c $2)
        ce = 1; WriteAddr = 2; WriteData = 16'h5555; WriteEn = 1;
        #10;
        WriteEn = 0; ReadAddr_rt = 2;
        #1;
        if (ReadData_rt !== 16'h5555) begin $display("[FAIL] Normal Read/Write"); errors = errors + 1; end
        else $display("[PASS] Normal Read/Write ($2 = 5555)");

        // 5. TEST: ??C/GHI SPECIAL REGISTERS (HI/LO)
        HILO_WriteEn = 1; HI_in = 16'hBEEF; LO_in = 16'hDEAD;
        #10;
        HILO_WriteEn = 0; MFSR_ReadEn = 1; Funct_MFSR = 3'b100; // ??c HI
        #1;
        if (ReadData_MFSR !== 16'hBEEF) begin $display("[FAIL] HI Register Read/Write"); errors = errors + 1; end
        else $display("[PASS] HI Register Checked");

        // 6. TEST: GHI B?NG L?NH MTSR VÀ ??C B?NG MFSR (Thanh ghi RA)
        MTSR_WriteEn = 1; Funct_MTSR = 3'b010; Data_MTSR = 16'h1234; // Ghi RA
        #10;
        MTSR_WriteEn = 0; MFSR_ReadEn = 1; Funct_MFSR = 3'b010; // ??c RA
        #1;
        if (ReadData_MFSR !== 16'h1234) begin $display("[FAIL] MTSR/MFSR for RA"); errors = errors + 1; end
        else $display("[PASS] Special Regs MTSR/MFSR Checked");

        $display("=== REG FILE UNIT TEST DONE. ERRORS: %0d ===\n", errors);
        $stop;
    end
endmodule