`timescale 1ns / 1ps

// =============================================================================
// MODULE: L1 INSTRUCTION CACHE CONTROLLER (ICACHE)
// =============================================================================
// - Kien truc: Direct-Mapped Cache, 1-cycle Hit Latency (Sustained 1 IPC)
// - Dung luong: 1024 Bytes (64 cache lines x 16 Bytes / line = 4 words/line)
// - Giao tiep CPU: Zero wait-state khi Hit, Stall Pipeline khi Miss
// - Giao tiep Bus: AXI4-Lite Refill Master tu dong nap du 4 words khi Miss
// - Ho tro Invalidate (FENCE.I) va xu ly Flush do Branch Mispredict
// - Chuan cong nghiep: Zero Latch, Dong bo hoa FPGA RAM Distributed/Block RAM
// =============================================================================

module icache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter LINE_WORDS = 4,              // 4 words = 16 bytes per cache line
    parameter NUM_LINES  = 64              // 64 lines = 1024 bytes (1 KB)
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,

    // -------------------------------------------------------------------------
    // CPU Fetch Interface (IF Stage)
    // -------------------------------------------------------------------------
    input  wire                  i_req,           // CPU yeu cau fetch lenh
    input  wire [ADDR_WIDTH-1:0] i_addr,          // Dia chi PC tu CPU
    input  wire                  i_pipeline_hold, // Pipeline bi dong bang boi D-Bus
    input  wire                  i_flush,         // Branch mispredict flush
    input  wire                  i_invalidate,    // Xoa sach cache (FENCE.I)
    output wire [DATA_WIDTH-1:0] o_rdata,         // Lenh tra ve cho CPU
    output wire                  o_valid,         // Lenh tra ve hop le
    output wire                  o_stall,         // 1: Freeze PC & IF/ID vi Cache Miss
    output wire                  o_hit,           // 1: Cache Hit (Thong so giam sat hieu nang)

    // -------------------------------------------------------------------------
    // AXI4-Lite Read Master Interface (Bus Refill tu Main Memory)
    // -------------------------------------------------------------------------
    // Read Address Channel (AR)
    output reg  [ADDR_WIDTH-1:0] o_axi_araddr,
    output reg                   o_axi_arvalid,
    input  wire                  i_axi_arready,
    output wire [2:0]            o_axi_prot,

    // Read Data Channel (R)
    input  wire [DATA_WIDTH-1:0] i_axi_rdata,
    input  wire [1:0]            i_axi_rresp,
    input  wire                  i_axi_rvalid,
    output reg                   o_axi_rready
);

    assign o_axi_prot = 3'b000;

    // -------------------------------------------------------------------------
    // CACHE GEOMETRY & ADDRESS DECODING
    // -------------------------------------------------------------------------
    // Dia chi 32-bit: [31:10] TAG (22 bits) | [9:4] INDEX (6 bits) | [3:2] WORD_SEL (2 bits) | [1:0] BYTE_SEL (2 bits)
    localparam OFFSET_BITS   = 4; // 16 bytes line -> 4 bits
    localparam INDEX_BITS    = 6; // 64 lines      -> 6 bits
    localparam TAG_BITS      = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS; // 22 bits
    localparam WORD_SEL_BITS = 2; // 4 words       -> 2 bits

    // Giai ma dia chi yeu cau hien tai
    wire [INDEX_BITS-1:0]    req_index    = i_addr[OFFSET_BITS+INDEX_BITS-1 : OFFSET_BITS];
    wire [TAG_BITS-1:0]      req_tag      = i_addr[ADDR_WIDTH-1 : OFFSET_BITS+INDEX_BITS];
    wire [WORD_SEL_BITS-1:0] req_word_sel = i_addr[3:2];

    // -------------------------------------------------------------------------
    // FSM STATES FOR CACHE MISS REFILL
    // -------------------------------------------------------------------------
    localparam STATE_IDLE        = 2'b00; // Normal lookup & hit evaluation
    localparam STATE_REFILL_REQ  = 2'b01; // Send AXI AR request for missing word
    localparam STATE_REFILL_DATA = 2'b10; // Receive AXI R data and write into cache line
    localparam STATE_REFILL_DONE = 2'b11; // Line fill complete, serve instruction to CPU

    reg [1:0]                 state;
    reg [ADDR_WIDTH-1:0]      miss_addr;
    reg [INDEX_BITS-1:0]      miss_index;
    reg [TAG_BITS-1:0]        miss_tag;
    reg [WORD_SEL_BITS-1:0]   miss_word_sel;
    reg [WORD_SEL_BITS-1:0]   refill_cnt;
    reg [DATA_WIDTH-1:0]      rdata_buf;
    reg                       flush_pending;

    // -------------------------------------------------------------------------
    // CACHE STORAGE ARRAYS
    // -------------------------------------------------------------------------
    // Tag array: 64 entries x 22 bits
    reg [TAG_BITS-1:0] tag_ram [0:NUM_LINES-1];

    // Valid array: 64 entries x 1 bit
    reg valid_ram [0:NUM_LINES-1];

    // Data array: 256 words (64 lines x 4 words = 1024 Bytes)
    // Su dung mang 1D giup Vivado suy luan truc tiep thanh Distributed RAM (RAM256X1S / LUTRAM)
    wire [7:0] req_word_addr    = {req_index, req_word_sel};
    wire [7:0] refill_word_addr = {miss_index, refill_cnt};
    (* ram_style = "distributed" *) reg [DATA_WIDTH-1:0] data_ram [0:255];

    // -------------------------------------------------------------------------
    // CACHE HIT / MISS DETECTION (COMBINATIONAL)
    // -------------------------------------------------------------------------
    wire line_valid = valid_ram[req_index];
    wire tag_match  = (tag_ram[req_index] == req_tag);
    wire cache_hit  = i_req && line_valid && tag_match;

    assign o_hit = cache_hit;

    // -------------------------------------------------------------------------
    // CPU OUTPUT LOGIC
    // -------------------------------------------------------------------------
    // Hit: Du lieu duoc lay truc tiep to hop tu data_ram trong chu ky hien tai (0 wait-states)
    // Refill Done: Du lieu lay tu rdata_buf da luu tru trong qua trinh nap line
    wire [DATA_WIDTH-1:0] hit_data = data_ram[req_word_addr];

    assign o_rdata = (state == STATE_IDLE) ? hit_data : rdata_buf;

    assign o_valid = (state == STATE_IDLE && cache_hit && !i_flush) ||
                     (state == STATE_REFILL_DONE && !flush_pending && !i_flush);

    // CPU chi bi stall khi:
    // 1) O trang thai IDLE ma bi Cache Miss (i_req && !cache_hit)
    // 2) Dang trong qua trinh nap line (REFILL_REQ hoac REFILL_DATA)
    // Giai phong stall ngay o STATE_REFILL_DONE hoac khi khong co req
    assign o_stall = (state == STATE_IDLE) ? (i_req && !cache_hit) :
                     (state != STATE_REFILL_DONE);

    // -------------------------------------------------------------------------
    // SYNCHRONOUS WRITE FOR DATA RAM & TAG RAM (ENABLES DISTRIBUTED LUTRAM INFERENCE)
    // -------------------------------------------------------------------------
    // Khong co asynchronous reset tren mang RAM giup Vivado tong hop thanh Distributed RAM (LUTRAM)
    always @(posedge i_clk) begin
        if (state == STATE_REFILL_DATA && i_axi_rvalid && o_axi_rready) begin
            data_ram[refill_word_addr] <= i_axi_rdata;
        end
    end

    always @(posedge i_clk) begin
        if (state == STATE_REFILL_DATA && i_axi_rvalid && o_axi_rready && (refill_cnt == (LINE_WORDS - 1))) begin
            tag_ram[miss_index] <= miss_tag;
        end
    end

    // -------------------------------------------------------------------------
    // CACHE CONTROLLER FSM & REFILL SEQUENCER
    // -------------------------------------------------------------------------
    integer idx;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state         <= STATE_IDLE;
            o_axi_araddr  <= {ADDR_WIDTH{1'b0}};
            o_axi_arvalid <= 1'b0;
            o_axi_rready  <= 1'b0;
            rdata_buf     <= {DATA_WIDTH{1'b0}};
            miss_addr     <= {ADDR_WIDTH{1'b0}};
            miss_index    <= {INDEX_BITS{1'b0}};
            miss_tag      <= {TAG_BITS{1'b0}};
            miss_word_sel <= {WORD_SEL_BITS{1'b0}};
            refill_cnt    <= {WORD_SEL_BITS{1'b0}};
            flush_pending <= 1'b0;

            for (idx = 0; idx < NUM_LINES; idx = idx + 1) begin
                valid_ram[idx] <= 1'b0;
            end
        end else begin
            // Xu ly Invalidate (FENCE.I)
            if (i_invalidate) begin
                for (idx = 0; idx < NUM_LINES; idx = idx + 1) begin
                    valid_ram[idx] <= 1'b0;
                end
            end

            // Ghi nhan co Flush do Branch Mispredict
            if (i_flush) begin
                flush_pending <= 1'b1;
            end

            case (state)
                // -------------------------------------------------------------
                // STATE_IDLE: Cache tra cuu lenh trong 1 chu ky
                // -------------------------------------------------------------
                STATE_IDLE: begin
                    flush_pending <= 1'b0;
                    if (i_req && !cache_hit) begin
                        // Bat dau chu trinh Cache Miss Refill
                        miss_addr     <= i_addr;
                        miss_index    <= req_index;
                        miss_tag      <= req_tag;
                        miss_word_sel <= req_word_sel;
                        refill_cnt    <= 2'b00;

                        // Phat yeu cau doc tu dau tien cua line tren AXI4-Lite
                        o_axi_araddr  <= {i_addr[ADDR_WIDTH-1:OFFSET_BITS], 4'b0000};
                        o_axi_arvalid <= 1'b1;
                        o_axi_rready  <= 1'b0;
                        state         <= STATE_REFILL_REQ;
                    end
                end

                // -------------------------------------------------------------
                // STATE_REFILL_REQ: Cho AXI Slave bat tay kenh dia chi doc (ARREADY)
                // -------------------------------------------------------------
                STATE_REFILL_REQ: begin
                    if (i_axi_arready && o_axi_arvalid) begin
                        o_axi_arvalid <= 1'b0;
                        o_axi_rready  <= 1'b1; // San sang don nhan du lieu doc
                        state         <= STATE_REFILL_DATA;
                    end
                end

                // -------------------------------------------------------------
                // STATE_REFILL_DATA: Nhan du lieu doc (RVALID) va ghi vao Cache Line
                // -------------------------------------------------------------
                STATE_REFILL_DATA: begin
                    if (i_axi_rvalid && o_axi_rready) begin
                        // Neu tu nay chinh la tu CPU dang doi, chot ngay vao rdata_buf
                        if (refill_cnt == miss_word_sel) begin
                            rdata_buf <= i_axi_rdata;
                        end

                        if (refill_cnt == (LINE_WORDS - 1)) begin
                            // Da nhan du 4 tu cua cache line!
                            // Bat Valid bit cho line (tag va data duoc ghi dong bo)
                            valid_ram[miss_index] <= 1'b1;
                            o_axi_rready          <= 1'b0;
                            state                 <= STATE_REFILL_DONE;
                        end else begin
                            // Chuyen sang tu ke tiep trong cache line
                            refill_cnt    <= refill_cnt + 1'b1;
                            o_axi_araddr  <= {miss_addr[ADDR_WIDTH-1:OFFSET_BITS], (refill_cnt + 1'b1), 2'b00};
                            o_axi_arvalid <= 1'b1;
                            o_axi_rready  <= 1'b0;
                            state         <= STATE_REFILL_REQ;
                        end
                    end
                end

                // -------------------------------------------------------------
                // STATE_REFILL_DONE: Cung cap lenh cho CPU va tro ve IDLE
                // -------------------------------------------------------------
                STATE_REFILL_DONE: begin
                    if (flush_pending || i_flush) begin
                        flush_pending <= 1'b0;
                        state         <= STATE_IDLE;
                    end else if (!i_pipeline_hold) begin
                        state         <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
