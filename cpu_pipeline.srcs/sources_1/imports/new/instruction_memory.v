/*
 * Module: instruction_memory 
 */
 `timescale 1ns / 1ps
module instruction_memory(
 input [15:0] Address,       
 output [15:0] Instruction   
);

    reg [15:0] mem [0:65535];
    initial begin
        $readmemh("program_full.hex", mem);    
    end
    assign Instruction = mem[Address >> 1];

endmodule
