/* * File: hazard_unit.v
 */
`timescale 1ns / 1ps

module hazard_unit(
    // Inputs từ tầng ID/EX (Lệnh đang thực thi)
    input ID_EX_MemRead,
    input [2:0] ID_EX_rt,
    
    // Inputs từ tầng IF/ID (Lệnh đang giải mã)
    input [2:0] IF_ID_rs,
    input [2:0] IF_ID_rt,
    
    input Branch_Taken, 
    
    // Outputs điều khiển Pipeline
    output reg PCWrite,         // 1 = Cho phép PC chạy, 0 = Đứng yên
    output reg IF_ID_Write,     // 1 = Cho phép IF/ID ghi, 0 = Giữ nguyên lệnh cũ
    output reg IF_ID_Flush,     // 1 = Xóa lệnh ở IF/ID (khi Branch)
    output reg ID_EX_Flush      // 1 = Biến lệnh ở ID/EX thành NOP (khi Stall)
);

    always @(*) begin
        PCWrite = 1;
        IF_ID_Write = 1;
        IF_ID_Flush = 0;
        ID_EX_Flush = 0;
        if (ID_EX_MemRead && 
           ((ID_EX_rt == IF_ID_rs) || (ID_EX_rt == IF_ID_rt))) begin
            
            // Stall Pipeline:
            PCWrite     = 0; // PC đứng yên (để fetch lại lệnh hiện tại)
            IF_ID_Write = 0; // IF/ID giữ nguyên (để decode lại lệnh hiện tại)
            ID_EX_Flush = 1; // Lệnh ở EX trở thành NOP (bong bóng)
        end
        
        // 2. Kiểm tra Control Hazard (Branch Taken)
        if (Branch_Taken) begin
            IF_ID_Flush = 1;
        end
    end

endmodule