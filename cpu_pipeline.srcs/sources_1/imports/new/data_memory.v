`timescale 1ns / 1ps
`include "defines.vh"

module data_memory #(
    parameter RAM_DEPTH = 4096
)(
    input  wire        i_clk,
    input  wire        i_mem_read,
    input  wire        i_mem_write,
    input  wire [31:0] i_addr,
    input  wire [31:0] i_wdata,
    input  wire [3:0]  i_wstrb,
    output wire [31:0] o_rdata
);

    (* ram_style = "distributed" *) reg [31:0] mem [0:RAM_DEPTH-1];

`ifndef SYNTHESIS
    integer k;
    initial begin
        for (k = 0; k < RAM_DEPTH; k = k + 1) begin
            mem[k] = 32'h00000000;
        end
    end
`endif

    always @(posedge i_clk) begin
        if (i_mem_write) begin
            if (i_wstrb[0]) mem[i_addr[13:2]][7:0]   <= i_wdata[7:0];
            if (i_wstrb[1]) mem[i_addr[13:2]][15:8]  <= i_wdata[15:8];
            if (i_wstrb[2]) mem[i_addr[13:2]][23:16] <= i_wdata[23:16];
            if (i_wstrb[3]) mem[i_addr[13:2]][31:24] <= i_wdata[31:24];
        end
    end

    assign o_rdata = (i_mem_read) ? mem[i_addr[13:2]] : 32'b0;

endmodule
