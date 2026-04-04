`timescale 1ns / 1ps

module forwarding_tb;

    // Inputs
    reg [2:0] ID_EX_rs, ID_EX_rt;
    reg [2:0] EX_MEM_RegWriteAddr, MEM_WB_RegWriteAddr;
    reg EX_MEM_RegWrite, MEM_WB_RegWrite;

    // Outputs
    wire [1:0] ForwardA, ForwardB;

    // Instantiate Forwarding Unit
    forwarding_unit uut (
        .ID_EX_rs(ID_EX_rs), .ID_EX_rt(ID_EX_rt),
        .EX_MEM_RegWriteAddr(EX_MEM_RegWriteAddr),
        .EX_MEM_RegWrite(EX_MEM_RegWrite),
        .MEM_WB_RegWriteAddr(MEM_WB_RegWriteAddr),
        .MEM_WB_RegWrite(MEM_WB_RegWrite),
        .ForwardA(ForwardA), .ForwardB(ForwardB)
    );

    integer errors = 0;

    initial begin
        $display("\n=== STARTING FORWARDING UNIT TEST ===");
         
        ID_EX_rs = 0; ID_EX_rt = 0;
        EX_MEM_RegWriteAddr = 0; MEM_WB_RegWriteAddr = 0;
        EX_MEM_RegWrite = 0; MEM_WB_RegWrite = 0;
        #10;
 
        ID_EX_rs = 1; ID_EX_rt = 2;
        EX_MEM_RegWrite = 1; EX_MEM_RegWriteAddr = 3; 
        #10;
        if (ForwardA !== 2'b00 || ForwardB !== 2'b00) begin $display("[FAIL] False Forwarding Triggered"); errors = errors+1; end
        else $display("[PASS] No Hazard - Default State");
 
        ID_EX_rs = 1; ID_EX_rt = 2;
        EX_MEM_RegWrite = 1; EX_MEM_RegWriteAddr = 1;
        #10;
        if (ForwardA !== 2'b10) begin $display("[FAIL] EX Hazard on ForwardA"); errors = errors+1; end
        else $display("[PASS] EX Hazard Detection (Forward 10)");
 
        ID_EX_rs = 1; ID_EX_rt = 2;
        EX_MEM_RegWrite = 0; // Không có EX Hazard
        MEM_WB_RegWrite = 1; MEM_WB_RegWriteAddr = 2;
        #10;
        if (ForwardB !== 2'b01) begin $display("[FAIL] MEM Hazard on ForwardB"); errors = errors+1; end
        else $display("[PASS] MEM Hazard Detection (Forward 01)");
 
        ID_EX_rs = 3; ID_EX_rt = 4;
        EX_MEM_RegWrite = 1; EX_MEM_RegWriteAddr = 3; 
        MEM_WB_RegWrite = 1; MEM_WB_RegWriteAddr = 3;
        #10;
        if (ForwardA !== 2'b10) begin $display("[FAIL] Double Hazard Resolution"); errors = errors+1; end
        else $display("[PASS] Double Hazard (Prioritize EX Stage)");
 
        ID_EX_rs = 0; ID_EX_rt = 2;
        EX_MEM_RegWrite = 1; EX_MEM_RegWriteAddr = 0;
        #10;
        if (ForwardA !== 2'b00) begin $display("[FAIL] $0 Register Forwarded!"); errors = errors+1; end
        else $display("[PASS] $0 Register Bypass Constraint");
 
        ID_EX_rs = 5; ID_EX_rt = 6;
        EX_MEM_RegWriteAddr = 5; EX_MEM_RegWrite = 0; // C? ghi ?ang t?t
        #10;
        if (ForwardA !== 2'b00) begin $display("[FAIL] Forwarded without RegWrite Flag"); errors = errors+1; end
        else $display("[PASS] RegWrite Flag Constraint");

        $display("=== FORWARDING UNIT TEST DONE. ERRORS: %0d ===\n", errors);
        $stop;
    end
endmodule
