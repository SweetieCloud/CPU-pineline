`timescale 1ns / 1ps

module alu (
    input signed [15:0] A,
    input signed [15:0] B,
    input [4:0] ALUOp,
    output reg [15:0] Result,
    output reg [31:0] HILO_Out, 
    
    // Status Flags
    output wire Zero,
    output wire Negative,
    output reg Overflow
);

    // =========================================================================
    // FLAGS ASSIGNMENT
    // =========================================================================
    assign Zero = (Result == 16'b0);
    assign Negative = Result[15]; // L?y bit d?u (MSB)

    // =========================================================================
    // ALU OPERATIONS
    // =========================================================================
    always @(*) begin 
        Overflow = 0;
        HILO_Out = 32'b0;
        Result   = 16'b0;

        case(ALUOp)
            5'b00001: begin // OP_ADD (C?ng có d?u)
                Result = A + B; 
                if ((A[15] == B[15]) && (Result[15] != A[15])) Overflow = 1;
            end
            5'b00010: Result = A + B; // OP_ADDU 
            
            5'b00011: begin // OP_SUB  
                Result = A - B; 
                if ((A[15] != B[15]) && (Result[15] != A[15])) Overflow = 1;
            end
            5'b00100: Result = A - B; // OP_SUBU
            
            // Logic Operations
            5'b00101: Result = A & B; // OP_AND
            5'b00110: Result = A | B; // OP_OR
            5'b00111: Result = ~(A | B); // OP_NOR
            5'b01000: Result = A ^ B; // OP_XOR
            
            // Set on Less Than
            5'b01001: Result = (A < B) ? 16'd1 : 16'd0; // OP_SLT  
            5'b01010: Result = ($unsigned(A) < $unsigned(B)) ? 16'd1 : 16'd0; // OP_SLTU
            5'b01011: Result = (A == B) ? 16'd1 : 16'd0; // OP_SEQ
            
            // Shifter Operations
            5'b01100: Result = A >> B[3:0]; // OP_SHR (Logic)
            5'b01101: Result = A << B[3:0]; // OP_SHL
            
            // Math
            5'b10000: HILO_Out = A * B; // OP_MULT
            5'b10100: Result = A + B; // OP_ADDR_CALC (Base + Offset)
            
            default: Result = 16'b0;
        endcase
    end
endmodule
