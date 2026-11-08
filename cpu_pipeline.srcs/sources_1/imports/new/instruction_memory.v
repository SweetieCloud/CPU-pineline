`timescale 1ns / 1ps
`include "defines.vh"

module instruction_memory #(
    parameter RAM_DEPTH = 4096
)(
    input  wire [31:0] i_addr,
    output wire [31:0] o_instr
);

    (* ram_style = "distributed" *) reg [31:0] mem [0:RAM_DEPTH-1];

`ifndef SYNTHESIS
    integer k;
    initial begin
        for (k = 0; k < RAM_DEPTH; k = k + 1) begin
            mem[k] = 32'h00000013; // NOP
        end
        $readmemh("memory_contents.hex", mem);
    end
`endif

    assign o_instr = mem[i_addr[13:2]];

endmodule
