`timescale 1ns / 1ps

module axi_lite_master_i #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                  i_clk,
    input  wire                  i_rst_n,

    // Giao tiep voi Pipeline CPU (IF Stage)
    input  wire                  i_req,           // Yeu cau lay lenh tu CPU
    input  wire [ADDR_WIDTH-1:0] i_addr,          // Dia chi PC
    input  wire                  i_pipeline_hold, // 1: Pipeline dang bi stall boi D-Bus
    input  wire                  i_flush,         // 1: Control Hazard flush (Branch/Jump)
    output reg  [DATA_WIDTH-1:0] o_rdata,         // Cau lenh doc ve
    output reg                   o_valid,       // Du lieu doc hop le
    output reg                   o_stall,       // 1: Bao CPU dong bang Pipeline

    // AXI4-Lite Read Address Channel (AR)
    output reg  [ADDR_WIDTH-1:0] o_axi_araddr,  // Da duoc chot thanh ghi dam bao chuan AMBA
    output reg                   o_axi_arvalid,
    input  wire                  i_axi_arready,
    output wire [2:0]            o_axi_prot,

    // AXI4-Lite Read Data Channel (R)
    input  wire [DATA_WIDTH-1:0] i_axi_rdata,
    input  wire [1:0]            i_axi_rresp,
    input  wire                  i_axi_rvalid,
    output reg                   o_axi_rready
);

    assign o_axi_prot = 3'b000;

    localparam STATE_IDLE      = 2'b00;
    localparam STATE_READ_WAIT = 2'b01;
    localparam STATE_DONE      = 2'b10;

    reg [1:0] state;
    reg       flush_pending;

    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            state         <= STATE_IDLE;
            o_axi_araddr  <= {ADDR_WIDTH{1'b0}};
            o_axi_arvalid <= 1'b0;
            o_axi_rready  <= 1'b0;
            o_rdata       <= {DATA_WIDTH{1'b0}};
            o_valid       <= 1'b0;
            o_stall       <= 1'b0;
            flush_pending <= 1'b0;
        end else begin
            if (i_flush) begin
                flush_pending <= 1'b1;
            end

            case (state)
                STATE_IDLE: begin
                    o_valid       <= 1'b0;
                    flush_pending <= 1'b0;
                    if (i_req && !i_flush) begin
                        o_axi_araddr  <= i_addr; // Chot dia chi on dinh
                        o_axi_arvalid <= 1'b1;
                        o_axi_rready  <= 1'b1;
                        o_stall       <= 1'b1;
                        state         <= STATE_READ_WAIT;
                    end else begin
                        o_stall <= 1'b0;
                    end
                end

                STATE_READ_WAIT: begin
                    o_stall <= 1'b1;
                    // Address Handshake
                    if (i_axi_arready && o_axi_arvalid) begin
                        o_axi_arvalid <= 1'b0;
                    end

                    // Data Handshake
                    if (i_axi_rvalid && o_axi_rready) begin
                        o_axi_rready  <= 1'b0;
                        o_axi_arvalid <= 1'b0;
                        if (flush_pending || i_flush) begin
                            // In-flight instruction thuoc nhanh cu, huy bo va fetch dia chi moi ngay lap tuc
                            flush_pending <= 1'b0;
                            o_valid       <= 1'b0;
                            o_stall       <= 1'b0;
                            state         <= STATE_IDLE;
                        end else begin
                            o_rdata <= i_axi_rdata;
                            o_valid <= 1'b1;
                            o_stall <= 1'b0; // Giai phong stall cho chu ky DONE
                            state   <= STATE_DONE;
                        end
                    end
                end

                STATE_DONE: begin
                    if (flush_pending || i_flush) begin
                        flush_pending <= 1'b0;
                        o_valid       <= 1'b0;
                        o_stall       <= 1'b0;
                        state         <= STATE_IDLE;
                    end else if (!i_pipeline_hold) begin
                        o_valid <= 1'b0;
                        o_stall <= 1'b0;
                        state   <= STATE_IDLE;
                    end else begin
                        o_valid <= 1'b1;
                        o_stall <= 1'b0;
                        state   <= STATE_DONE;
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
