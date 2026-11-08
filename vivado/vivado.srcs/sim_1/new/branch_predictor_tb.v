`timescale 1ns / 1ps

// =============================================================================
// LAYERED SOC UNIT TESTBENCH: DYNAMIC BRANCH PREDICTOR (2-BIT BHT + BTB)
// =============================================================================
// Kiến trúc kiểm chứng phân tầng chuẩn SoC:
//   - Layer 1 (DUT Layer)    : Cô lập module branch_predictor (64-entry).
//   - Layer 2 (Mock Services): Mock IF Stage Lookup Driver & Mock ID Stage
//                              Resolution Training Service.
//   - Layer 3 (Spy & SVA)    : Bộ đếm Spy theo dõi các lần cập nhật Taken /
//                              Not-Taken và SVA kiểm tra tính hợp lệ của BTB.
//   - Layer 4 (Scoreboard)   : Các hàm expect_pred, expect_bht_state, expect_spy
//                              kiểm tra trực tiếp cả đầu ra lẫn trạng thái 2-bit
//                              FSM (SNT=00, WNT=01, WT=10, ST=11).
// =============================================================================

module branch_predictor_tb;

    parameter ENTRY_COUNT = 64;
    parameter ADDR_WIDTH  = 32;

    localparam SNT = 2'b00; // Strongly Not Taken
    localparam WNT = 2'b01; // Weakly Not Taken
    localparam WT  = 2'b10; // Weakly Taken
    localparam ST  = 2'b11; // Strongly Taken

    reg                   clk;
    reg                   rst_n;

    // Prediction interface (IF stage)
    reg  [ADDR_WIDTH-1:0] pc;
    wire                  pred_taken;
    wire [ADDR_WIDTH-1:0] pred_target;

    // Update interface (ID stage)
    reg                   update_en;
    reg  [ADDR_WIDTH-1:0] update_pc;
    reg                   update_taken;
    reg  [ADDR_WIDTH-1:0] update_target;

    integer pass_count = 0;
    integer errors     = 0;

    // =========================================================================
    // LAYER 1: COMPONENT UNDER TEST (DUT ISOLATION)
    // =========================================================================
    branch_predictor #(
        .ENTRY_COUNT(ENTRY_COUNT),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .i_clk           (clk),
        .i_rst_n         (rst_n),
        .i_pc            (pc),
        .o_pred_taken    (pred_taken),
        .o_pred_target   (pred_target),
        .i_update_en     (update_en),
        .i_update_pc     (update_pc),
        .i_update_taken  (update_taken),
        .i_update_target (update_target)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // =========================================================================
    // LAYER 2 & 3: MOCK TRAINING DRIVER, CALL SPIES & SVA ASSERTIONS
    // =========================================================================
    integer spy_train_total_cnt = 0;
    integer spy_train_taken_cnt = 0;
    integer spy_train_nt_cnt    = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spy_train_total_cnt <= 0;
            spy_train_taken_cnt <= 0;
            spy_train_nt_cnt    <= 0;
        end else if (update_en) begin
            spy_train_total_cnt <= spy_train_total_cnt + 1;
            if (update_taken)
                spy_train_taken_cnt <= spy_train_taken_cnt + 1;
            else
                spy_train_nt_cnt    <= spy_train_nt_cnt + 1;
        end
    end

    // SVA: o_pred_taken can only be 1 if the indexed BTB entry is valid and BHT[1] == 1
    property p_pred_taken_requires_valid_btb;
        @(posedge clk) disable iff (!rst_n)
        pred_taken |-> (dut.btb_valid[pc[7:2]] && dut.bht[pc[7:2]][1]);
    endproperty
    assert property (p_pred_taken_requires_valid_btb)
        else begin
            $error("[SVA ERROR] Branch Predictor asserted o_pred_taken without valid BTB & Taken BHT!");
            errors = errors + 1;
        end

    task train_branch(input [31:0] b_pc, input b_taken, input [31:0] b_target);
        begin
            @(negedge clk);
            update_en     = 1'b1;
            update_pc     = b_pc;
            update_taken  = b_taken;
            update_target = b_target;
            @(posedge clk);
            #1;
            update_en     = 1'b0;
        end
    endtask

    // =========================================================================
    // LAYER 4: SCOREBOARD EXPECTATION MACROS
    // =========================================================================
    task expect_pred(input expected_taken, input [31:0] expected_target, input [127*8:1] desc);
        begin
            #1;
            assert (pred_taken === expected_taken && (expected_taken == 1'b0 || pred_target === expected_target)) begin
                $display(" [PASS] [EXPECT_PRED]  %0s | pred_taken=%b target=0x%08H", desc, pred_taken, pred_target);
                pass_count = pass_count + 1;
            end else begin
                $error(" [FAIL] [EXPECT_PRED]  %0s | Got: taken=%b target=0x%08H | Exp: taken=%b target=0x%08H",
                       desc, pred_taken, pred_target, expected_taken, expected_target);
                errors = errors + 1;
            end
        end
    endtask

    task expect_bht_state(input [5:0] idx, input [1:0] exp_bht, input [127*8:1] desc);
        begin
            #1;
            assert (dut.bht[idx] === exp_bht) begin
                $display(" [PASS] [EXPECT_STATE] %0s | BHT[%0d] = %02b (Exp: %02b)", desc, idx, dut.bht[idx], exp_bht);
                pass_count = pass_count + 1;
            end else begin
                $error(" [FAIL] [EXPECT_STATE] %0s | BHT[%0d] = %02b (Exp: %02b)", desc, idx, dut.bht[idx], exp_bht);
                errors = errors + 1;
            end
        end
    endtask

    task expect_spy(input [127*8:1] desc, input integer actual_cnt, input integer expected_cnt);
        begin
            assert (actual_cnt === expected_cnt) begin
                $display(" [PASS] [EXPECT_SPY]   %0s | Calls = %0d (Exp: %0d)", desc, actual_cnt, expected_cnt);
                pass_count = pass_count + 1;
            end else begin
                $error(" [FAIL] [EXPECT_SPY]   %0s | Calls = %0d (Exp: %0d)", desc, actual_cnt, expected_cnt);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        rst_n = 0;
        pc = 32'h0;
        update_en = 0;
        update_pc = 32'h0;
        update_taken = 0;
        update_target = 32'h0;

        #25;
        rst_n = 1;
        #10;

        $display("\n=========================================================================");
        $display("   [DV] LAYERED UNIT TEST: DYNAMIC BRANCH PREDICTOR (BHT + BTB) START   ");
        $display("=========================================================================");

        // TEST 1: Initial state after Reset (WNT = 2'b01, BTB invalid)
        pc = 32'h00001004; // Index = 1
        expect_bht_state(6'd1, WNT, "Test 1a: Reset BHT[1] initialized to WNT (01)");
        expect_pred(1'b0, 32'h00001008, "Test 1b: Cold start (BTB Miss -> Not Taken)");

        // TEST 2: First Taken -> Updates to Weakly Taken (WT = 10) & BTB Valid
        train_branch(32'h00001004, 1'b1, 32'h00001040);
        pc = 32'h00001004;
        expect_bht_state(6'd1, WT, "Test 2a: BHT[1] transitions WNT(01) -> WT(10)");
        expect_pred(1'b1, 32'h00001040, "Test 2b: Predicts Taken, Target 0x1040");

        // TEST 3: Second Taken -> Updates to Strongly Taken (ST = 11)
        train_branch(32'h00001004, 1'b1, 32'h00001040);
        pc = 32'h00001004;
        expect_bht_state(6'd1, ST, "Test 3a: BHT[1] transitions WT(10) -> ST(11)");
        expect_pred(1'b1, 32'h00001040, "Test 3b: Predicts Strongly Taken");

        // TEST 4: Saturation Test at Upper Bound (ST stays at ST)
        train_branch(32'h00001004, 1'b1, 32'h00001040);
        pc = 32'h00001004;
        expect_bht_state(6'd1, ST, "Test 4a: Upper Saturation ST(11) -> ST(11)");
        expect_pred(1'b1, 32'h00001040, "Test 4b: Still predicts Taken");

        // TEST 5: Hysteresis Resistance (ST -> WT on single Not-Taken)
        train_branch(32'h00001004, 1'b0, 32'h00001040);
        pc = 32'h00001004;
        expect_bht_state(6'd1, WT, "Test 5a: 2-bit Hysteresis ST(11) -> WT(10)");
        expect_pred(1'b1, 32'h00001040, "Test 5b: Still predicts Taken on 1st NT");

        // TEST 6: Second Not Taken -> Transitions to Weakly Not Taken (WNT = 01)
        train_branch(32'h00001004, 1'b0, 32'h00001040);
        pc = 32'h00001004;
        expect_bht_state(6'd1, WNT, "Test 6a: Transitions WT(10) -> WNT(01)");
        expect_pred(1'b0, 32'h00001040, "Test 6b: Prediction flips to Not Taken");

        // TEST 7: Third Not Taken -> Transitions to Strongly Not Taken (SNT = 00)
        train_branch(32'h00001004, 1'b0, 32'h00001040);
        pc = 32'h00001004;
        expect_bht_state(6'd1, SNT, "Test 7a: Transitions WNT(01) -> SNT(00)");
        expect_pred(1'b0, 32'h00001040, "Test 7b: Predicts Strongly Not Taken");

        // TEST 8: Lower Saturation (SNT stays at SNT) & SNT -> WNT transition
        train_branch(32'h00001004, 1'b0, 32'h00001040);
        expect_bht_state(6'd1, SNT, "Test 8a: Lower Saturation SNT(00) -> SNT(00)");
        train_branch(32'h00001004, 1'b1, 32'h00001050);
        expect_bht_state(6'd1, WNT, "Test 8b: Recovery SNT(00) -> WNT(01) on Taken");

        // TEST 9: Tag Aliasing & Collision Immunity
        train_branch(32'h00001004, 1'b1, 32'h00001050); // WNT -> WT
        train_branch(32'h00001004, 1'b1, 32'h00001050); // WT  -> ST
        pc = 32'h00001004;
        expect_pred(1'b1, 32'h00001050, "Test 9a: PC1 (Tag 0x10) predicts Taken to 0x1050");

        pc = 32'h00002004; // Same index 1, different tag 0x20
        expect_pred(1'b0, 32'h00002008, "Test 9b: PC2 (Tag 0x20) BTB Tag Mismatch -> Not Taken");

        // TEST 10: Multiple Concurrent Independent Branches (Index 1 & Index 2)
        train_branch(32'h00000104, 1'b1, 32'h00000180);
        train_branch(32'h00000104, 1'b1, 32'h00000180);
        train_branch(32'h00000108, 1'b0, 32'h00000280);
        train_branch(32'h00000108, 1'b0, 32'h00000280);

        pc = 32'h00000104;
        expect_pred(1'b1, 32'h00000180, "Test 10a: Branch A (Idx 1) Taken");
        pc = 32'h00000108;
        expect_pred(1'b0, 32'h0000010c, "Test 10b: Branch B (Idx 2) Not Taken");

        // TEST 11: Ecosystem Spy Verification
        expect_spy("Total Training Updates Called", spy_train_total_cnt, 14);
        expect_spy("Total Taken Updates Called",    spy_train_taken_cnt, 8);
        expect_spy("Total Not-Taken Updates Called",spy_train_nt_cnt,    6);

        $display("\n-------------------------------------------------------------------------");
        if (errors == 0) begin
            $display("   >>> ALL %0d BRANCH PREDICTOR CHECKS & ASSERTIONS PASSED! <<<", pass_count);
        end else begin
            $display("   >>> [FAILED] %0d BRANCH PREDICTOR CHECKS FAILED! <<<", errors);
        end
        $display("-------------------------------------------------------------------------\n");

        $finish;
    end

endmodule
