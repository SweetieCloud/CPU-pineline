`timescale 1ns / 1ps
`include "defines.vh"

module axi_lite_master_d #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,

    // Giao tiep voi CPU MEM Stage
    input  wire                  i_req_read,
    input  wire                  i_req_write,
    input  wire [ADDR_WIDTH-1:0] i_addr,
    input  wire [DATA_WIDTH-1:0] i_wdata,
    input  wire [2:0]            i_funct3,
    input  wire                  i_pipeline_hold, // 1: Pipeline dang bi stall boi I-Bus
    output reg  [DATA_WIDTH-1:0] o_rdata,
    output wire                  o_stall,

    // AXI4-Lite Write Address Channel (AW)
    output reg  [ADDR_WIDTH-1:0] o_axi_awaddr,  // Chot thanh ghi
    output reg                   o_axi_awvalid,
    input  wire                  i_axi_awready,

    // AXI4-Lite Write Data Channel (W)
    output reg  [DATA_WIDTH-1:0] o_axi_wdata,
    output reg  [3:0]            o_axi_wstrb,
    output reg                   o_axi_wvalid,
    input  wire                  i_axi_wready,

    // AXI4-Lite Write Response Channel (B)
    input  wire [1:0]            i_axi_bresp,
    input  wire                  i_axi_bvalid,
    output reg                   o_axi_bready,

    // AXI4-Lite Read Address Channel (AR)
    output reg  [ADDR_WIDTH-1:0] o_axi_araddr,  // Chot thanh ghi
    output reg                   o_axi_arvalid,
    input  wire                  i_axi_arready,

    // AXI4-Lite Read Data Channel (R)
    input  wire [DATA_WIDTH-1:0] i_axi_rdata,
    input  wire [1:0]            i_axi_rresp,
    input  wire                  i_axi_rvalid,
    output reg                   o_axi_rready
);

    localparam STATE_IDLE       = 2'b00;
    localparam STATE_WRITE_WAIT = 2'b01;
    localparam STATE_READ_WAIT  = 2'b10;
    localparam STATE_DONE       = 2'b11;

    reg [1:0] state;
    reg [2:0] funct3_reg;
    reg [1:0] addr_offset_reg;

    reg [3:0]            wstrb_calculated;
    reg [DATA_WIDTH-1:0] wdata_aligned;

    always @(*) begin
        case (i_funct3)
            `FUNCT3_SB: begin
                wstrb_calculated = 4'b0001 << i_addr[1:0];
                wdata_aligned    = i_wdata << (i_addr[1:0] * 8);
            end
            `FUNCT3_SH: begin
                wstrb_calculated = i_addr[1] ? 4'b1100 : 4'b0011;
                wdata_aligned    = i_addr[1] ? (i_wdata << 16) : i_wdata;
            end
            `FUNCT3_SW: begin
                wstrb_calculated = 4'b1111;
                wdata_aligned    = i_wdata;
            end
            default: begin
                wstrb_calculated = 4'b1111;
                wdata_aligned    = i_wdata;
            end
        endcase
    end

    // Phat tin hieu stall to hop lap tuc khi co request o IDLE hoac dang cho AXI phan hoi
    assign o_stall = (state == STATE_READ_WAIT)  ? 1'b1 :
                     (state == STATE_WRITE_WAIT) ? 1'b1 :
                     (state == STATE_IDLE && (i_req_read || i_req_write)) ? 1'b1 :
                     1'b0;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state           <= STATE_IDLE;
            o_axi_awaddr    <= {ADDR_WIDTH{1'b0}};
            o_axi_awvalid   <= 1'b0;
            o_axi_wdata     <= {DATA_WIDTH{1'b0}};
            o_axi_wstrb     <= 4'b0000;
            o_axi_wvalid    <= 1'b0;
            o_axi_bready    <= 1'b0;
            o_axi_araddr    <= {ADDR_WIDTH{1'b0}};
            o_axi_arvalid   <= 1'b0;
            o_axi_rready    <= 1'b0;
            o_rdata         <= {DATA_WIDTH{1'b0}};
            funct3_reg      <= 3'b0;
            addr_offset_reg <= 2'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (i_req_write) begin
                        o_axi_awaddr    <= i_addr;
                        o_axi_awvalid   <= 1'b1;
                        o_axi_wdata     <= wdata_aligned;
                        o_axi_wstrb     <= wstrb_calculated;
                        o_axi_wvalid    <= 1'b1;
                        o_axi_bready    <= 1'b1;
                        state           <= STATE_WRITE_WAIT;
                    end else if (i_req_read) begin
                        o_axi_araddr    <= i_addr;
                        o_axi_arvalid   <= 1'b1;
                        o_axi_rready    <= 1'b1;
                        funct3_reg      <= i_funct3;
                        addr_offset_reg <= i_addr[1:0];
                        state           <= STATE_READ_WAIT;
                    end
                end

                STATE_WRITE_WAIT: begin
                    if (i_axi_awready && o_axi_awvalid) o_axi_awvalid <= 1'b0;
                    if (i_axi_wready  && o_axi_wvalid)  o_axi_wvalid  <= 1'b0;

                    if (i_axi_bvalid && o_axi_bready) begin
                        o_axi_bready  <= 1'b0;
                        o_axi_awvalid <= 1'b0;
                        o_axi_wvalid  <= 1'b0;
                        state         <= STATE_DONE;
                    end
                end

                STATE_READ_WAIT: begin
                    if (i_axi_arready && o_axi_arvalid) o_axi_arvalid <= 1'b0;

                    if (i_axi_rvalid && o_axi_rready) begin
                        o_axi_rready  <= 1'b0;
                        o_axi_arvalid <= 1'b0;
                        state         <= STATE_DONE;

                        case (funct3_reg)
                            `FUNCT3_LB: begin
                                case (addr_offset_reg)
                                    2'b00: o_rdata <= {{24{i_axi_rdata[7]}},   i_axi_rdata[7:0]};
                                    2'b01: o_rdata <= {{24{i_axi_rdata[15]}},  i_axi_rdata[15:8]};
                                    2'b10: o_rdata <= {{24{i_axi_rdata[23]}},  i_axi_rdata[23:16]};
                                    2'b11: o_rdata <= {{24{i_axi_rdata[31]}},  i_axi_rdata[31:24]};
                                endcase
                            end
                            `FUNCT3_LBU: begin
                                case (addr_offset_reg)
                                    2'b00: o_rdata <= {24'b0, i_axi_rdata[7:0]};
                                    2'b01: o_rdata <= {24'b0, i_axi_rdata[15:8]};
                                    2'b10: o_rdata <= {24'b0, i_axi_rdata[23:16]};
                                    2'b11: o_rdata <= {24'b0, i_axi_rdata[31:24]};
                                endcase
                            end
                            `FUNCT3_LH: begin
                                o_rdata <= addr_offset_reg[1] ? {{16{i_axi_rdata[31]}}, i_axi_rdata[31:16]} :
                                                               {{16{i_axi_rdata[15]}}, i_axi_rdata[15:0]};
                            end
                            `FUNCT3_LHU: begin
                                o_rdata <= addr_offset_reg[1] ? {16'b0, i_axi_rdata[31:16]} :
                                                               {16'b0, i_axi_rdata[15:0]};
                            end
                            `FUNCT3_LW: begin
                                o_rdata <= i_axi_rdata;
                            end
                            default: o_rdata <= i_axi_rdata;
                        endcase
                    end
                end

                STATE_DONE: begin
                    // Cho pipeline capture o clock edge nay (khi khong bi I-Bus hold), sau do ve IDLE
                    if (!i_pipeline_hold) begin
                        state <= STATE_IDLE;
                    end else begin
                        state <= STATE_DONE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
