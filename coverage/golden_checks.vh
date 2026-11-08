// Golden Model Scoreboard Verification
        if (dut.cpu_inst.datapath_inst.reg_file.registers[0] === 32'h00000000) begin
            $display("[PASS] [GOLDEN_CHECK] x0  = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[0]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x0  = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[0]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[1] === 32'h00000000) begin
            $display("[PASS] [GOLDEN_CHECK] x1  = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[1]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x1  = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[1]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[2] === 32'h00000000) begin
            $display("[PASS] [GOLDEN_CHECK] x2  = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[2]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x2  = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[2]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[3] === 32'h60127000) begin
            $display("[PASS] [GOLDEN_CHECK] x3  = 0x%08X (Exp: 0x60127000)", dut.cpu_inst.datapath_inst.reg_file.registers[3]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x3  = 0x%08X (Exp: 0x60127000)", dut.cpu_inst.datapath_inst.reg_file.registers[3]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[4] === 32'h6f646000) begin
            $display("[PASS] [GOLDEN_CHECK] x4  = 0x%08X (Exp: 0x6f646000)", dut.cpu_inst.datapath_inst.reg_file.registers[4]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x4  = 0x%08X (Exp: 0x6f646000)", dut.cpu_inst.datapath_inst.reg_file.registers[4]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[5] === 32'hffffffff) begin
            $display("[PASS] [GOLDEN_CHECK] x5  = 0x%08X (Exp: 0xffffffff)", dut.cpu_inst.datapath_inst.reg_file.registers[5]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x5  = 0x%08X (Exp: 0xffffffff)", dut.cpu_inst.datapath_inst.reg_file.registers[5]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[6] === 32'hfffff919) begin
            $display("[PASS] [GOLDEN_CHECK] x6  = 0x%08X (Exp: 0xfffff919)", dut.cpu_inst.datapath_inst.reg_file.registers[6]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x6  = 0x%08X (Exp: 0xfffff919)", dut.cpu_inst.datapath_inst.reg_file.registers[6]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[7] === 32'hb3433000) begin
            $display("[PASS] [GOLDEN_CHECK] x7  = 0x%08X (Exp: 0xb3433000)", dut.cpu_inst.datapath_inst.reg_file.registers[7]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x7  = 0x%08X (Exp: 0xb3433000)", dut.cpu_inst.datapath_inst.reg_file.registers[7]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[8] === 32'hd62fc000) begin
            $display("[PASS] [GOLDEN_CHECK] x8  = 0x%08X (Exp: 0xd62fc000)", dut.cpu_inst.datapath_inst.reg_file.registers[8]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x8  = 0x%08X (Exp: 0xd62fc000)", dut.cpu_inst.datapath_inst.reg_file.registers[8]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[9] === 32'h00000021) begin
            $display("[PASS] [GOLDEN_CHECK] x9  = 0x%08X (Exp: 0x00000021)", dut.cpu_inst.datapath_inst.reg_file.registers[9]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x9  = 0x%08X (Exp: 0x00000021)", dut.cpu_inst.datapath_inst.reg_file.registers[9]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[10] === 32'h49041000) begin
            $display("[PASS] [GOLDEN_CHECK] x10 = 0x%08X (Exp: 0x49041000)", dut.cpu_inst.datapath_inst.reg_file.registers[10]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x10 = 0x%08X (Exp: 0x49041000)", dut.cpu_inst.datapath_inst.reg_file.registers[10]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[11] === 32'h00000001) begin
            $display("[PASS] [GOLDEN_CHECK] x11 = 0x%08X (Exp: 0x00000001)", dut.cpu_inst.datapath_inst.reg_file.registers[11]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x11 = 0x%08X (Exp: 0x00000001)", dut.cpu_inst.datapath_inst.reg_file.registers[11]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[12] === 32'h00000000) begin
            $display("[PASS] [GOLDEN_CHECK] x12 = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[12]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x12 = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[12]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[13] === 32'hd62fc5a8) begin
            $display("[PASS] [GOLDEN_CHECK] x13 = 0x%08X (Exp: 0xd62fc5a8)", dut.cpu_inst.datapath_inst.reg_file.registers[13]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x13 = 0x%08X (Exp: 0xd62fc5a8)", dut.cpu_inst.datapath_inst.reg_file.registers[13]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[14] === 32'h9c8aa000) begin
            $display("[PASS] [GOLDEN_CHECK] x14 = 0x%08X (Exp: 0x9c8aa000)", dut.cpu_inst.datapath_inst.reg_file.registers[14]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x14 = 0x%08X (Exp: 0x9c8aa000)", dut.cpu_inst.datapath_inst.reg_file.registers[14]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[15] === 32'h0edb6000) begin
            $display("[PASS] [GOLDEN_CHECK] x15 = 0x%08X (Exp: 0x0edb6000)", dut.cpu_inst.datapath_inst.reg_file.registers[15]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x15 = 0x%08X (Exp: 0x0edb6000)", dut.cpu_inst.datapath_inst.reg_file.registers[15]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[16] === 32'h000001bb) begin
            $display("[PASS] [GOLDEN_CHECK] x16 = 0x%08X (Exp: 0x000001bb)", dut.cpu_inst.datapath_inst.reg_file.registers[16]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x16 = 0x%08X (Exp: 0x000001bb)", dut.cpu_inst.datapath_inst.reg_file.registers[16]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[17] === 32'h00000001) begin
            $display("[PASS] [GOLDEN_CHECK] x17 = 0x%08X (Exp: 0x00000001)", dut.cpu_inst.datapath_inst.reg_file.registers[17]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x17 = 0x%08X (Exp: 0x00000001)", dut.cpu_inst.datapath_inst.reg_file.registers[17]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[18] === 32'h000005a8) begin
            $display("[PASS] [GOLDEN_CHECK] x18 = 0x%08X (Exp: 0x000005a8)", dut.cpu_inst.datapath_inst.reg_file.registers[18]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x18 = 0x%08X (Exp: 0x000005a8)", dut.cpu_inst.datapath_inst.reg_file.registers[18]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[19] === 32'ha92c4000) begin
            $display("[PASS] [GOLDEN_CHECK] x19 = 0x%08X (Exp: 0xa92c4000)", dut.cpu_inst.datapath_inst.reg_file.registers[19]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x19 = 0x%08X (Exp: 0xa92c4000)", dut.cpu_inst.datapath_inst.reg_file.registers[19]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[20] === 32'h00000000) begin
            $display("[PASS] [GOLDEN_CHECK] x20 = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[20]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x20 = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[20]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[21] === 32'h00000000) begin
            $display("[PASS] [GOLDEN_CHECK] x21 = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[21]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x21 = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[21]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[22] === 32'h6fbd0000) begin
            $display("[PASS] [GOLDEN_CHECK] x22 = 0x%08X (Exp: 0x6fbd0000)", dut.cpu_inst.datapath_inst.reg_file.registers[22]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x22 = 0x%08X (Exp: 0x6fbd0000)", dut.cpu_inst.datapath_inst.reg_file.registers[22]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[23] === 32'h4a0a4000) begin
            $display("[PASS] [GOLDEN_CHECK] x23 = 0x%08X (Exp: 0x4a0a4000)", dut.cpu_inst.datapath_inst.reg_file.registers[23]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x23 = 0x%08X (Exp: 0x4a0a4000)", dut.cpu_inst.datapath_inst.reg_file.registers[23]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[24] === 32'h00000000) begin
            $display("[PASS] [GOLDEN_CHECK] x24 = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[24]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x24 = 0x%08X (Exp: 0x00000000)", dut.cpu_inst.datapath_inst.reg_file.registers[24]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[25] === 32'h6bb57000) begin
            $display("[PASS] [GOLDEN_CHECK] x25 = 0x%08X (Exp: 0x6bb57000)", dut.cpu_inst.datapath_inst.reg_file.registers[25]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x25 = 0x%08X (Exp: 0x6bb57000)", dut.cpu_inst.datapath_inst.reg_file.registers[25]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[26] === 32'h49041000) begin
            $display("[PASS] [GOLDEN_CHECK] x26 = 0x%08X (Exp: 0x49041000)", dut.cpu_inst.datapath_inst.reg_file.registers[26]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x26 = 0x%08X (Exp: 0x49041000)", dut.cpu_inst.datapath_inst.reg_file.registers[26]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[27] === 32'hf96fd000) begin
            $display("[PASS] [GOLDEN_CHECK] x27 = 0x%08X (Exp: 0xf96fd000)", dut.cpu_inst.datapath_inst.reg_file.registers[27]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x27 = 0x%08X (Exp: 0xf96fd000)", dut.cpu_inst.datapath_inst.reg_file.registers[27]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[28] === 32'h00000001) begin
            $display("[PASS] [GOLDEN_CHECK] x28 = 0x%08X (Exp: 0x00000001)", dut.cpu_inst.datapath_inst.reg_file.registers[28]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x28 = 0x%08X (Exp: 0x00000001)", dut.cpu_inst.datapath_inst.reg_file.registers[28]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[29] === 32'hbafdd000) begin
            $display("[PASS] [GOLDEN_CHECK] x29 = 0x%08X (Exp: 0xbafdd000)", dut.cpu_inst.datapath_inst.reg_file.registers[29]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x29 = 0x%08X (Exp: 0xbafdd000)", dut.cpu_inst.datapath_inst.reg_file.registers[29]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[30] === 32'h0ecc2000) begin
            $display("[PASS] [GOLDEN_CHECK] x30 = 0x%08X (Exp: 0x0ecc2000)", dut.cpu_inst.datapath_inst.reg_file.registers[30]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x30 = 0x%08X (Exp: 0x0ecc2000)", dut.cpu_inst.datapath_inst.reg_file.registers[30]);
            fail_count = fail_count + 1;
        end
        if (dut.cpu_inst.datapath_inst.reg_file.registers[31] === 32'hffffffff) begin
            $display("[PASS] [GOLDEN_CHECK] x31 = 0x%08X (Exp: 0xffffffff)", dut.cpu_inst.datapath_inst.reg_file.registers[31]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GOLDEN_CHECK] x31 = 0x%08X (Exp: 0xffffffff)", dut.cpu_inst.datapath_inst.reg_file.registers[31]);
            fail_count = fail_count + 1;
        end