`timescale 1ns / 1ps

module cpu_tb;
    reg clk;
    reg rst;
    
    // Giao ti?p I/O
    wire [3:0] led;

    // Kh?i t?o CPU
    cpu_top uut (
        .clk(clk),
        .rst(rst),
        .led(led)
    );

    // 1. T?O CLOCK 100MHz (Chu k? 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 2. WATCHDOG TIMER (Ch?ng treo mô ph?ng)
    initial begin
        #10000;
        $display("\n[FATAL ERROR] TIMEOUT! CPU failed to reach HALT state.");
        $stop;
    end

    // 3. K?CH B?N TEST (SELF-CHECKING)
    integer errors = 0;

    initial begin
        // Kh?i t?o
        rst = 1;
        #25; 
        rst = 0;
        
        $display("=================================================");
        $display("      [SYSTEM] MIPS 16-BIT PIPELINE BOOTING      ");
        $display("=================================================");
        
        // Ch? ??n khi tín hi?u Halt t? Datapath b?t lên 1
        wait(uut.datapath_inst.halt == 1'b1);
        
        // [QUAN TR?NG]: T?ng th?i gian ??i lên 5 cycle (50ns) 
        // ?? l?nh cu?i cùng k?p trôi t? EX qua MEM và ghi vào WB
        #50; 

        
        $display("\n[SYSTEM] HALT INSTRUCTION DETECTED. CHECKING STATE...\n");

        // --- B?T ??U KI?M TRA SO SÁNH CHO BÀI STRESS TEST (50 LOOPS) ---
        
        check_reg(1, 16'h0032); // $1 = 50 (0032) - S? vòng l?p
        check_reg(2, 16'h04FB); // $2 = 1275 (04FB) - T?ng c?ng d?n
        check_reg(3, 16'hFB05); // $3 = -1275 (FB05) - T?ng tr? d?n
        check_reg(7, 16'hFFFF); // $7 = -1 (FFFF) - ??a ch? LED

        // Vì ta xu?t d? li?u ra ??a ch? FFFF (Memory-Mapped I/O),
        // Chân LED c?a cpu_top s? b?t ???c giá tr? cu?i cùng c?a $2 (1275 = 04FB -> 4 bit cu?i là B t?c 4'b1011)
        if (uut.led === 4'b1011) begin
             $display("[PASS] Memory-Mapped I/O LED = %b", uut.led);
        end else begin
             $display("[FAIL] Memory-Mapped I/O LED: Expected = 1011, Actual = %b", uut.led);
             errors = errors + 1;
        end

        // T?ng k?t
        $display("\n=================================================");
        if (errors == 0) begin
            $display("   [PASSED] ALL TESTS SUCCESSFUL! YOU ROCK!      ");
        end else begin
            $display("   [FAILED] %0d ERRORS FOUND. FIX YOUR RTL!      ", errors);
        end
        $display("=================================================\n");
        $stop;
    end

    // ==========================================
    // TASK: HÀM T? ??NG SO SÁNH THANH GHI
    // ==========================================
    task check_reg;
        input integer reg_num;
        input [15:0] expected_val;
        reg [15:0] actual_val;
        begin
            actual_val = uut.datapath_inst.reg_file.registers[reg_num];
            if (actual_val !== expected_val) begin
                $display("[FAIL] Reg $%0d: Expected = %h, Actual = %h", reg_num, expected_val, actual_val);
                errors = errors + 1;
            end else begin
                $display("[PASS] Reg $%0d = %h", reg_num, actual_val);
            end
        end
    endtask

    // ==========================================
    // TASK: HÀM T? ??NG SO SÁNH B? NH?
    // ==========================================
    task check_mem;
        input integer addr;
        input [15:0] expected_val;
        reg [15:0] actual_val;
        begin
            actual_val = uut.datapath_inst.dmem.mem[addr >> 1]; 
            if (actual_val !== expected_val) begin
                $display("[FAIL] Mem[%0d]: Expected = %h, Actual = %h", addr, expected_val, actual_val);
                errors = errors + 1;
            end else begin
                $display("[PASS] Mem[%0d] = %h", addr, actual_val);
            end
        end
    endtask

endmodule