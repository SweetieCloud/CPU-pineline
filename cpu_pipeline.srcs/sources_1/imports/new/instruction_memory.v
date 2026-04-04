/*
 * Module: instruction_memory (Bộ nhớ Lệnh)
 * Chức năng: Hoạt động như một ROM.
 * Nhận địa chỉ từ PC và xuất ra lệnh 16-bit.
 * Bộ nhớ được khởi tạo từ file "program.hex".
 */
 `timescale 1ns / 1ps
module instruction_memory(
    input [15:0] Address,      // �?ịa chỉ lệnh (từ PC)
    output [15:0] Instruction  // Lệnh 16-bit tại địa chỉ đó
);

    // Khai báo bộ nhớ. 
    // Kích thước 2^16 = 65536 từ, mỗi từ 16 bit.
    // (�?ịa chỉ là 16-bit, nhưng tài liệu nói PC nhảy 2,
    // nên ta chỉ dùng các địa chỉ chẵn)
    reg [15:0] mem [0:65535];

    
    // Y�u c?u file "program_full.hex" ph?i n?m c�ng th? m?c m� ph?ng (Simulation Folder)
    initial begin
        $readmemh("program_full.hex", mem);    
    end
    // Logic đ�?c (Tổ hợp - Combinational)
    // Lấy lệnh tại địa chỉ được chỉ định.
    // �?ịa chỉ từ PC là địa chỉ byte, nhưng lệnh là 16-bit (2 byte).
    // Chúng ta giả định PC luôn tr�? đến địa chỉ chẵn (đã xử lý ở datapath)
    // Ta cần chia địa chỉ cho 2 (dịch phải 1 bit) để làm index cho mảng.
    assign Instruction = mem[Address >> 1];

endmodule