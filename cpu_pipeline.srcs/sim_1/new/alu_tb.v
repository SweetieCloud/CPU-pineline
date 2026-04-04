`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/04/2026 11:30:03 PM
// Design Name: 
// Module Name: alu_tb
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

module alu_tb;

    // Inputs
    reg signed [15:0] A;
    reg signed [15:0] B;
    reg [4:0] ALUOp;

    // Outputs
    wire [15:0] Result;
    wire [31:0] HILO_Out;
    wire Zero;
    wire Negative;
    wire Overflow;

    // Instantiate ALU
    alu uut (
        .A(A), .B(B), .ALUOp(ALUOp),
        .Result(Result), .HILO_Out(HILO_Out),
        .Zero(Zero), .Negative(Negative), .Overflow(Overflow)
    );

    integer errors = 0;

    initial begin
        $display("\n=== STARTING ALU UNIT TEST ===");

        // 1. TEST BÌNH TH??NG: C?ng 2 s? d??ng (A=50, B=100)
        A = 16'd50; B = 16'd100; ALUOp = 5'b00001; // OP_ADD
        #10;
        if (Result !== 16'd150 || Overflow !== 0) 
            begin $display("[FAIL] Normal ADD"); errors = errors+1; end
        else $display("[PASS] Normal ADD");

        // 2. EDGE CASE: C?ng ra s? âm (A = -50, B = 20)
        A = -16'd50; B = 16'd20; ALUOp = 5'b00001;
        #10;
        if (Result !== -16'd30 || Negative !== 1) 
            begin $display("[FAIL] Negative ADD"); errors = errors+1; end
        else $display("[PASS] Negative ADD");

        // 3. EDGE CASE: Tràn s? d??ng (Overflow)
        // 16-bit signed max = 32767. L?y 30000 + 10000 = 40000 (V??t ng??ng)
        A = 16'd30000; B = 16'd10000; ALUOp = 5'b00001;
        #10;
        if (Overflow !== 1) 
            begin $display("[FAIL] Positive Overflow Detection"); errors = errors+1; end
        else $display("[PASS] Positive Overflow Detection");

        // 4. EDGE CASE: Tr? 2 s? b?ng nhau (Ki?m tra c? Zero)
        A = 16'd500; B = 16'd500; ALUOp = 5'b00011; // OP_SUB
        #10;
        if (Result !== 0 || Zero !== 1) 
            begin $display("[FAIL] Zero Flag Validation"); errors = errors+1; end
        else $display("[PASS] Zero Flag Validation");

        // 5. TEST: Shift Left Logic (D?ch bit)
        A = 16'h000F; B = 16'd4; ALUOp = 5'b01101; // OP_SHL
        #10;
        if (Result !== 16'h00F0) 
            begin $display("[FAIL] Shift Left Logic"); errors = errors+1; end
        else $display("[PASS] Shift Left Logic");

        $display("=== ALU UNIT TEST DONE. ERRORS: %0d ===\n", errors);
        $stop;
    end
endmodule