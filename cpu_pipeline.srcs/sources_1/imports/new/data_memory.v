/* Module: data_memory.v */
`timescale 1ns / 1ps
module data_memory(
    input clk,
    input ce,
    input [15:0] Address,
    input [15:0] DataIn,
    input MemRead,
    input MemWrite,
    output [15:0] DataOut
);
    reg [15:0] mem [0:65535];

    // Ghi đồng bộ (Synchronous Write)
    always @(posedge clk) begin
    if (ce) begin
        if (MemWrite) begin
            mem[Address >> 1] <= DataIn; 
        end
        end
    end
    assign DataOut = (MemRead) ? mem[Address >> 1] : 16'h0000;
endmodule