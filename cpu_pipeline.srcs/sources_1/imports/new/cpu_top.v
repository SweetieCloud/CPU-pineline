`timescale 1ns / 1ps

module cpu_top(
    input clk,              // Clock g?c t? board (VD: 125 MHz)
    input rst,              // Nút nh?n Reset (Active High)
    output reg [3:0] led    // 4 ?èn LED
);

    // =========================================================================
    // 1. CLOCK ENABLE GENERATOR (Thay th? cho Generated Clock sai chu?n)
    // =========================================================================
    reg [26:0] counter;
    wire ce; // Clock Enable Pulse
    
    always @(posedge clk or posedge rst) begin
        if (rst) 
            counter <= 0;
        else 
            counter <= counter + 1;
    end




    //Dành cho ch?y board th?t (FPGA)
    
//assign ce = (counter == 27'h7FFFFFF); 
    
    
    
    
    
 assign ce = 1'b1; //Dành cho ch?y mô ph?ng (Simulation) - Ép CE luôn b?t












    // =========================================================================
    // 2. K?T N?I DATAPATH (?ã b? sung tín hi?u I/O và Halt)
    // =========================================================================
    wire [15:0] pc_out;
    wire [15:0] mem_addr;      // ??a ch? trích xu?t t? t?ng MEM
    wire [15:0] mem_writedata; // D? li?u c?n ghi t? t?ng MEM
    wire mem_write_en;         // Tín hi?u Write Enable t? MEM
    wire halt_flag;            // C? d?ng CPU t? Control Unit

    datapath datapath_inst (
        .clk(clk),                  // CHU?N: Dùng clock g?c
        .ce(ce),                    // C?p xung Clock Enable vào pipeline
        .rst(rst),
        .halt(halt_flag),           // Tín hi?u Halt ép d?ng PC
        .current_pc(pc_out),
        
        // Trích xu?t các port ?? giao ti?p ngo?i vi (I/O)
        .mem_addr_out(mem_addr),
        .mem_writedata_out(mem_writedata),
        .mem_write_en_out(mem_write_en)
    );

    // =========================================================================
    // 3. MEMORY-MAPPED I/O (Giao ti?p thi?t b? ngo?i vi)
    // =========================================================================
    // Quy ??c: ??a ch? 16'hFFFF ???c map c?ng cho module LED
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            led <= 4'b0000;
        end else if (ce) begin
            // Ch? b?t d? li?u khi l?nh là Store (WriteEn) và ?úng ??a ch? I/O
            if (mem_write_en && (mem_addr == 16'hFFFF)) begin
                led <= mem_writedata[3:0];
            end
        end
    end

endmodule