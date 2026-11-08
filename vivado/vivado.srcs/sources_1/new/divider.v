`timescale 1ns / 1ps
`include "defines.vh"

// =============================================================================
// RV32M MULTI-CYCLE HARDWARE DIVIDER & REMAINDER UNIT
// =============================================================================
// Ho tro day du 4 lenh chia cua RV32M:
//   - DIV  (funct3 = 100): Chia co dau, lay thuong
//   - DIVU (funct3 = 101): Chia khong dau, lay thuong
//   - REM  (funct3 = 110): Chia co dau, lay so du
//   - REMU (funct3 = 111): Chia khong dau, lay so du
//
// Dac diem thiet ke cao cap:
//   1. Thuat toan Restoring Shift-Subtract 32 chu ky (FSM Binary 2-bit: IDLE -> CALC -> DONE),
//      tong thoi gian 34 chu ky (33 chu ky stall pipeline), toi uu dien tich va Fmax.
//   2. Fast-Exit (1-cycle execution / 0-cycle stall) cho cac corner cases theo RISC-V Spec:
//      - Chia cho 0 (x / 0 = -1, x % 0 = x)
//      - Signed Overflow (-2^31 / -1 = -2^31, -2^31 % -1 = 0)
//   3. Tin hieu o_busy / o_done ket noi voi Hazard Unit de stall pipeline chinh xac.
// =============================================================================

module divider (
    input  wire                   i_clk,
    input  wire                   i_rst_n,
    input  wire                   i_start,
    input  wire [2:0]             i_funct3,
    input  wire [`DATA_WIDTH-1:0] i_dividend, // rs1 (so bi chia)
    input  wire [`DATA_WIDTH-1:0] i_divisor,  // rs2 (so chia)

    output reg  [`DATA_WIDTH-1:0] o_result,
    output wire                   o_busy,
    output wire                   o_done
);

    // Giai ma kieu phep toan tu funct3
    wire is_rem      = i_funct3[1]; // 1: REM / REMU, 0: DIV / DIVU
    wire is_unsigned = i_funct3[0]; // 1: DIVU / REMU, 0: DIV / REM

    // Kiem tra Corner Cases theo chuan RISC-V Spec
    wire is_zero_div = (i_divisor == 32'd0);
    wire is_overflow = (!is_unsigned && (i_dividend == 32'h80000000) && (i_divisor == 32'hFFFFFFFF));
    wire fast_exit   = is_zero_div || is_overflow;

    // Tinh toan ket qua Corner Case tuc thi (0-cycle / 1-cycle)
    reg [`DATA_WIDTH-1:0] corner_res;
    always @(*) begin
        if (is_zero_div) begin
            corner_res = is_rem ? i_dividend : 32'hFFFFFFFF;
        end else if (is_overflow) begin
            corner_res = is_rem ? 32'h00000000 : 32'h80000000;
        end else begin
            corner_res = 32'd0;
        end
    end

    // Lay tri tuyet doi cho phep toan co dau
    wire [31:0] unsigned_dividend = (!is_unsigned && i_dividend[31]) ? (-i_dividend) : i_dividend;
    wire [31:0] unsigned_divisor  = (!is_unsigned && i_divisor[31])  ? (-i_divisor)  : i_divisor;

    // FSM States
    localparam STATE_IDLE = 2'b00;
    localparam STATE_CALC = 2'b01;
    localparam STATE_DONE = 2'b10;

    reg [1:0]  state;
    reg [5:0]  count;
    reg [31:0] reg_remainder;
    reg [31:0] reg_quotient;
    reg [31:0] reg_divisor;
    reg        sign_q;
    reg        sign_r;
    reg        is_rem_reg;

    // Logic dich va tru
    wire [32:0] rem_next = {reg_remainder[30:0], reg_quotient[31]};
    wire [32:0] rem_sub  = rem_next - {1'b0, reg_divisor};

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state         <= STATE_IDLE;
            count         <= 6'd0;
            reg_remainder <= 32'd0;
            reg_quotient  <= 32'd0;
            reg_divisor   <= 32'd0;
            sign_q        <= 1'b0;
            sign_r        <= 1'b0;
            is_rem_reg    <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (i_start && !fast_exit) begin
                        state         <= STATE_CALC;
                        count         <= 6'd31;
                        reg_remainder <= 32'd0;
                        reg_quotient  <= unsigned_dividend;
                        reg_divisor   <= unsigned_divisor;
                        sign_q        <= is_unsigned ? 1'b0 : (i_dividend[31] ^ i_divisor[31]);
                        sign_r        <= is_unsigned ? 1'b0 : i_dividend[31];
                        is_rem_reg    <= is_rem;
                    end
                end

                STATE_CALC: begin
                    if (!rem_sub[32]) begin // rem_next >= reg_divisor
                        reg_remainder <= rem_sub[31:0];
                        reg_quotient  <= {reg_quotient[30:0], 1'b1};
                    end else begin
                        reg_remainder <= rem_next[31:0];
                        reg_quotient  <= {reg_quotient[30:0], 1'b0};
                    end

                    if (count == 6'd0) begin
                        state <= STATE_DONE;
                    end else begin
                        count <= count - 1'b1;
                    end
                end

                STATE_DONE: begin
                    state <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

    // Xu ly dau cho ket qua cuoi cung
    wire [31:0] calc_quo = sign_q ? (-reg_quotient) : reg_quotient;
    wire [31:0] calc_rem = sign_r ? (-reg_remainder) : reg_remainder;

    // Ngo ra trang thai cho Hazard Unit & Datapath
    assign o_busy = (state == STATE_CALC) || ((state == STATE_IDLE) && i_start && !fast_exit);
    assign o_done = (state == STATE_DONE) || ((state == STATE_IDLE) && i_start && fast_exit);

    always @(*) begin
        if ((state == STATE_IDLE) && fast_exit) begin
            o_result = corner_res;
        end else if (state == STATE_DONE) begin
            o_result = is_rem_reg ? calc_rem : calc_quo;
        end else begin
            o_result = 32'd0;
        end
    end

endmodule
