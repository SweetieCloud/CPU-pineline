`timescale 1ns / 1ps

module cpu_top(
    input clk,              
    input rst,              
    output reg [3:0] led    
);

    // =========================================================================
    // 1. CLOCK ENABLE GENERATOR 
    // =========================================================================
    reg [26:0] counter;
    wire ce; // Clock Enable Pulse
    
    always @(posedge clk or posedge rst) begin
        if (rst) 
            counter <= 0;
        else 
            counter <= counter + 1;
    end


    //(FPGA)    
//assign ce = (counter == 27'h7FFFFFF); 
    
 assign ce = 1'b1; // (Simulation) 


    // =========================================================================
    // 2. DATAPATH 
    // =========================================================================
    wire [15:0] pc_out;
    wire [15:0] mem_addr;       
    wire [15:0] mem_writedata;  
    wire mem_write_en;        
    wire halt_flag;           

    datapath datapath_inst (
        .clk(clk),                  
        .ce(ce),                  
        .rst(rst),
        .halt(halt_flag),        
        .current_pc(pc_out), 
        .mem_addr_out(mem_addr),
        .mem_writedata_out(mem_writedata),
        .mem_write_en_out(mem_write_en)
    );

    // =========================================================================
    // 3. MEMORY-MAPPED I/O  
    // =========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            led <= 4'b0000;
        end else if (ce) begin
            if (mem_write_en && (mem_addr == 16'hFFFF)) begin
                led <= mem_writedata[3:0];
            end
        end
    end

endmodule
