`timescale 1ns / 1ps

module cpu_tb;
    reg clk;
    reg rst;
     
    wire [3:0] led;
 
    cpu_top uut (
        .clk(clk),
        .rst(rst),
        .led(led)
    ); 
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end 
    initial begin
        #10000;
        $display("\n[FATAL ERROR] TIMEOUT! CPU failed to reach HALT state.");
        $stop;
    end 
    integer errors = 0;

    initial begin 
        rst = 1;
        #25; 
        rst = 0;
        
        $display("=================================================");
        $display("      [SYSTEM] MIPS 16-BIT PIPELINE BOOTING      ");
        $display("=================================================");
         
        wait(uut.datapath_inst.halt == 1'b1); 
        #50; 

        
        $display("\n[SYSTEM] HALT INSTRUCTION DETECTED. CHECKING STATE...\n");
 
        
        check_reg(1, 16'h0032);  
        check_reg(2, 16'h04FB);  
        check_reg(3, 16'hFB05);  
        check_reg(7, 16'hFFFF);  
 
        if (uut.led === 4'b1011) begin
             $display("[PASS] Memory-Mapped I/O LED = %b", uut.led);
        end else begin
             $display("[FAIL] Memory-Mapped I/O LED: Expected = 1011, Actual = %b", uut.led);
             errors = errors + 1;
        end
 
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
    // TASK: CHECK REG
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
    // TASK: CHECK MEM
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
