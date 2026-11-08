`timescale 1ns / 1ps

// =============================================================================
// MODULE: DYNAMIC BRANCH PREDICTOR (BIMODAL 2-BIT SATURATING COUNTER + BTB)
// Arch: 2-bit BHT (Branch History Table) + Direct-Mapped Branch Target Buffer (BTB)
// Standard: RISC-V Branch Prediction & Timing Closure Optimization
// =============================================================================
module branch_predictor #(
    parameter ENTRY_COUNT = 64, // So luong entry trong BTB va BHT (luy thua cua 2)
    parameter ADDR_WIDTH  = 32
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,

    // -------------------------------------------------------------------------
    // 1. Prediction Interface (IF Stage: Tra cuu va du doan ngay trong chu ky IF)
    // -------------------------------------------------------------------------
    input  wire [ADDR_WIDTH-1:0] i_pc,           // Dia chi PC dang fetch
    output wire                  o_pred_taken,   // 1: Du doan re nhanh (Taken), 0: Not Taken
    output wire [ADDR_WIDTH-1:0] o_pred_target,  // Dia chi dich du doan tu BTB

    // -------------------------------------------------------------------------
    // 2. Update / Training Interface (ID Stage: Cap nhat sau khi re nhanh thuc su)
    // -------------------------------------------------------------------------
    input  wire                  i_update_en,    // 1: Kich hoat huan luyen (khi co lenh Branch/Jump giai quyet o ID)
    input  wire [ADDR_WIDTH-1:0] i_update_pc,    // Dia chi PC cua lenh Branch dang cap nhat
    input  wire                  i_update_taken, // Ket qua re nhanh thuc te (1: Taken, 0: Not Taken)
    input  wire [ADDR_WIDTH-1:0] i_update_target // Dia chi dich thuc te
);

    localparam INDEX_BITS = $clog2(ENTRY_COUNT); // Vi du: 64 entries -> 6 bits (index pc[7:2])
    localparam TAG_BITS   = ADDR_WIDTH - INDEX_BITS - 2; // Tag = pc[31:8] (24 bits)

    // Dinh nghia trang thai 2-bit Saturating Counter
    localparam STATE_SNT = 2'b00; // Strongly Not Taken
    localparam STATE_WNT = 2'b01; // Weakly Not Taken
    localparam STATE_WT  = 2'b10; // Weakly Taken
    localparam STATE_ST  = 2'b11; // Strongly Taken

    // Bang lich su re nhanh BHT (2-bit saturating counter cho moi entry)
    reg [1:0] bht [0:ENTRY_COUNT-1];

    // Bang luu dia chi dich BTB (Branch Target Buffer)
    reg                                              btb_valid  [0:ENTRY_COUNT-1];
    (* ram_style = "distributed" *) reg [TAG_BITS-1:0]   btb_tag    [0:ENTRY_COUNT-1];
    (* ram_style = "distributed" *) reg [ADDR_WIDTH-1:0] btb_target [0:ENTRY_COUNT-1];

`ifndef SYNTHESIS
    integer init_idx;
    initial begin
        for (init_idx = 0; init_idx < ENTRY_COUNT; init_idx = init_idx + 1) begin
            btb_tag[init_idx]    = {TAG_BITS{1'b0}};
            btb_target[init_idx] = {ADDR_WIDTH{1'b0}};
        end
    end
`endif

    // Tach truong dia chi PC cho Prediction (IF Stage)
    wire [INDEX_BITS-1:0] if_index = i_pc[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0]   if_tag   = i_pc[ADDR_WIDTH-1:INDEX_BITS+2];

    // Tach truong dia chi PC cho Update (ID Stage)
    wire [INDEX_BITS-1:0] upd_index = i_update_pc[INDEX_BITS+1:2];
    wire [TAG_BITS-1:0]   upd_tag   = i_update_pc[ADDR_WIDTH-1:INDEX_BITS+2];

    // -------------------------------------------------------------------------
    // 1. LOGIC DU DOAN (PREDICTION LOGIC - COMBINATIONAL READ-THROUGH)
    // -------------------------------------------------------------------------
    // Kiem tra BTB Hit: Entry hop le va Tag trung khop
    wire btb_hit = btb_valid[if_index] && (btb_tag[if_index] == if_tag);

    // BHT du doan Taken khi bit MSB cua bo dem bang 1 (WT hoac ST)
    wire bht_predict_taken = bht[if_index][1];

    // Du doan Taken chi khi BTB Hit VA BHT du doan Taken
    assign o_pred_taken  = btb_hit && bht_predict_taken;
    assign o_pred_target = btb_hit ? btb_target[if_index] : (i_pc + 32'd4);

    // -------------------------------------------------------------------------
    // 2. LOGIC HUAN LUYEN / CAP NHAT (UPDATE / TRAINING LOGIC - SYNCHRONOUS)
    // -------------------------------------------------------------------------
    // Tach btb_tag va btb_target sang khoi always @(posedge i_clk) khong co async reset
    // de cho phep Vivado suy dien Distributed LUTRAM thay vi Flip-Flop roi rac
    always @(posedge i_clk) begin
        if (i_update_en && i_update_taken) begin
            btb_tag[upd_index]    <= upd_tag;
            btb_target[upd_index] <= i_update_target;
        end
    end

    integer k;
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            for (k = 0; k < ENTRY_COUNT; k = k + 1) begin
                bht[k]       <= STATE_WNT; // Mac dinh khoi tao Weakly Not Taken (01)
                btb_valid[k] <= 1'b0;
            end
        end else if (i_update_en) begin
            // 2.1 Cap nhat bo dem 2-bit BHT theo ket qua thuc te
            case (bht[upd_index])
                STATE_SNT: bht[upd_index] <= (i_update_taken) ? STATE_WNT : STATE_SNT;
                STATE_WNT: bht[upd_index] <= (i_update_taken) ? STATE_WT  : STATE_SNT;
                STATE_WT:  bht[upd_index] <= (i_update_taken) ? STATE_ST  : STATE_WNT;
                STATE_ST:  bht[upd_index] <= (i_update_taken) ? STATE_ST  : STATE_WT;
                default:   bht[upd_index] <= STATE_WNT;
            endcase

            // 2.2 Cap nhat BTB Valid neu lenh thuc te co re nhanh (Taken)
            if (i_update_taken) begin
                btb_valid[upd_index] <= 1'b1;
            end
        end
    end

endmodule
