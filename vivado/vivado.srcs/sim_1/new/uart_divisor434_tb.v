`timescale 1ns / 1ps

// =============================================================================
// VERIFICATION TESTBENCH: AXI UART LITE WITH HARDWARE DIVISOR 434 (115200 BAUD)
// =============================================================================
// Target:
//   - Clock Frequency: 50.0 MHz (Period: 20 ns)
//   - Baud Rate: 115200 bps
//   - Hardware Divisor: 50,000,000 / 115,200 = 434 clock cycles per bit
//   - Total bit duration: 434 * 20 ns = 8,680 ns per bit
//   - Full 10-bit frame (1 start, 8 data, 1 stop): 86,800 ns (86.8 us)
// =============================================================================

module uart_divisor434_tb;

    localparam CLK_PERIOD  = 20;            // 50 MHz
    localparam CLK_FREQ_HZ = 50_000_000;
    localparam BAUD_RATE   = 115_200;
    localparam HW_DIV      = 434;           // 50MHz / 115200
    localparam BIT_PERIOD  = HW_DIV * CLK_PERIOD; // 8,680 ns

    reg        clk;
    reg        rst_n;

    wire       uart_tx;
    wire       uart_rx;
    wire       uart_irq;

    // AXI signals
    reg  [31:0] awaddr;
    reg         awvalid;
    wire        awready;
    reg  [31:0] wdata;
    reg  [3:0]  wstrb;
    reg         wvalid;
    wire        wready;
    wire [1:0]  bresp;
    wire        bvalid;
    reg         bready;
    reg  [31:0] araddr;
    reg         arvalid;
    wire        arready;
    wire [31:0] rdata;
    wire [1:0]  rresp;
    wire        rvalid;
    reg         rready;

    // External Mock Serial Line
    reg         mock_rx;
    reg         loopback_mode;
    assign uart_rx = loopback_mode ? uart_tx : mock_rx;

    integer pass_count = 0;
    integer fail_count = 0;

    // DUT: axi_uart_lite with default parameters (50MHz, 115200 Baud -> Divisor 434)
    axi_uart_lite #(
        .ADDR_WIDTH (32),
        .DATA_WIDTH (32),
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) dut (
        .i_clk        (clk),
        .i_rst_n      (rst_n),
        .o_uart_tx    (uart_tx),
        .i_uart_rx    (uart_rx),
        .o_uart_irq   (uart_irq),
        .s_axi_awaddr (awaddr),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata  (wdata),
        .s_axi_wstrb  (wstrb),
        .s_axi_wvalid (wvalid),
        .s_axi_wready (wready),
        .s_axi_bresp  (bresp),
        .s_axi_bvalid (bvalid),
        .s_axi_bready (bready),
        .s_axi_araddr (araddr),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_rdata  (rdata),
        .s_axi_rresp  (rresp),
        .s_axi_rvalid (rvalid),
        .s_axi_rready (rready)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    // AXI Write Task
    task axi_write;
        input [31:0] addr;
        input [31:0] data;
        begin
            @(posedge clk);
            awaddr  <= addr;
            awvalid <= 1'b1;
            wdata   <= data;
            wstrb   <= 4'hF;
            wvalid  <= 1'b1;
            bready  <= 1'b1;

            fork
                begin
                    wait(awready);
                    @(posedge clk);
                    awvalid <= 1'b0;
                end
                begin
                    wait(wready);
                    @(posedge clk);
                    wvalid <= 1'b0;
                end
            join

            wait(bvalid);
            @(posedge clk);
            bready <= 1'b0;
            @(posedge clk);
        end
    endtask

    // AXI Read Task
    task axi_read;
        input  [31:0] addr;
        output [31:0] data;
        begin
            @(posedge clk);
            araddr  <= addr;
            arvalid <= 1'b1;
            rready  <= 1'b1;

            wait(arready);
            @(posedge clk);
            arvalid <= 1'b0;

            wait(rvalid);
            data = rdata;
            @(posedge clk);
            rready <= 1'b0;
            @(posedge clk);
        end
    endtask

    // Send serial byte from testbench to DUT RX at 115200 baud
    task send_uart_byte;
        input [7:0] byte_val;
        integer i;
        begin
            // Start bit
            mock_rx <= 1'b0;
            #(BIT_PERIOD);

            // 8 Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                mock_rx <= byte_val[i];
                #(BIT_PERIOD);
            end

            // Stop bit
            mock_rx <= 1'b1;
            #(BIT_PERIOD);
        end
    endtask

    // Monitor TX bit timing
    task verify_tx_frame;
        input [7:0] expected_byte;
        realtime t_start, t_bit;
        integer i;
        reg [7:0] captured_byte;
        begin
            // Wait for falling edge of start bit
            wait(uart_tx === 1'b0);
            t_start = $realtime;

            // Sample in the middle of each data bit
            #(BIT_PERIOD + (BIT_PERIOD / 2)); // Skip start bit to mid of bit 0
            for (i = 0; i < 8; i = i + 1) begin
                captured_byte[i] = uart_tx;
                #(BIT_PERIOD);
            end

            // Check stop bit
            if (uart_tx === 1'b1) begin
                $display("[PASS] [UART TX STOP BIT] Stop bit is 1'b1 as expected.");
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [UART TX STOP BIT] Stop bit is 1'b0 (Framing error)!");
                fail_count = fail_count + 1;
            end

            if (captured_byte === expected_byte) begin
                $display("[PASS] [UART TX BYTE] Transmitted byte matches: 0x%02X ('%c')", captured_byte, captured_byte);
                pass_count = pass_count + 1;
            end else begin
                $error("[FAIL] [UART TX BYTE] Expected 0x%02X, Got 0x%02X", expected_byte, captured_byte);
                fail_count = fail_count + 1;
            end
        end
    endtask

    reg [31:0] read_val;

    initial begin
        $display("\n===============================================================================");
        $display("   STARTING HARDWARE DIVISOR 434 (115200 BAUD @ 50MHz) UART VERIFICATION");
        $display("===============================================================================\n");

        clk = 0;
        rst_n = 0;
        awaddr = 0; awvalid = 0; wdata = 0; wstrb = 0; wvalid = 0; bready = 0;
        araddr = 0; arvalid = 0; rready = 0;
        mock_rx = 1'b1;
        loopback_mode = 1'b0;

        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);

        // 1. Verify default baud divisor register (0x08)
        axi_read(32'h00000008, read_val);
        if (read_val[15:0] === 16'd434) begin
            $display("[PASS] [BAUD_DIV] Default hardware divisor is 434 (115200 Baud @ 50MHz)");
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [BAUD_DIV] Expected 434, Got %0d", read_val[15:0]);
            fail_count = fail_count + 1;
        end

        // 2. Transmit byte 0x55 ('U' - alternating bit pattern 01010101) at 115200 Baud
        $display("\n---> Test 1: Transmitting 0x55 ('U') at hardware divisor 434...");
        fork
            verify_tx_frame(8'h55);
            begin
                #(CLK_PERIOD * 5);
                axi_write(32'h00000000, 32'h00000055);
            end
        join

        // 3. Receive byte 0xA5 over RX line at 115200 Baud
        $display("\n---> Test 2: Injecting byte 0xA5 into RX at 115200 Baud...");
        send_uart_byte(8'hA5);

        // Check STATUS register (0x04) for rx_valid (bit 0)
        axi_read(32'h00000004, read_val);
        if (read_val[0] === 1'b1) begin
            $display("[PASS] [RX STATUS] rx_valid flag asserted after receiving frame.");
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [RX STATUS] rx_valid is not asserted!");
            fail_count = fail_count + 1;
        end

        // Read RX DATA register (0x00)
        axi_read(32'h00000000, read_val);
        if (read_val[7:0] === 8'hA5) begin
            $display("[PASS] [RX DATA] Received byte matches: 0x%02X", read_val[7:0]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [RX DATA] Expected 0xA5, Got 0x%02X", read_val[7:0]);
            fail_count = fail_count + 1;
        end

        // 4. Test Glitch Rejection at Divisor 434
        // Inject false start bit shorter than half baud period (< 217 cycles = 4.34 us)
        $display("\n---> Test 3: Injecting false start glitch (100 cycles = 2 us < 4.34 us)...");
        mock_rx <= 1'b0;
        #(CLK_PERIOD * 100); // 2000 ns glitch
        mock_rx <= 1'b1;
        #(BIT_PERIOD * 2);

        axi_read(32'h00000004, read_val);
        if (read_val[0] === 1'b0) begin
            $display("[PASS] [GLITCH REJECTION] Glitch successfully ignored by hardware filter.");
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [GLITCH REJECTION] Glitch incorrectly accepted as valid frame!");
            fail_count = fail_count + 1;
        end

        // 5. Test Full-Duplex Loopback at 115200 Baud
        $display("\n---> Test 4: Full-Duplex Hardware Loopback (TX -> RX) with 0x4B ('K')...");
        loopback_mode = 1'b1;
        axi_write(32'h00000000, 32'h0000004B);

        // Wait for full frame transmission (86.8 us) + margin
        #(BIT_PERIOD * 12);

        axi_read(32'h00000000, read_val);
        if (read_val[7:0] === 8'h4B) begin
            $display("[PASS] [LOOPBACK] Received looped-back byte: 0x%02X ('%c')", read_val[7:0], read_val[7:0]);
            pass_count = pass_count + 1;
        end else begin
            $error("[FAIL] [LOOPBACK] Expected 0x4B, Got 0x%02X", read_val[7:0]);
            fail_count = fail_count + 1;
        end

        $display("\n===============================================================================");
        $display("   UART HARDWARE DIVISOR 434 VERIFICATION: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("===============================================================================\n");

        if (fail_count == 0)
            $finish;
        else
            $fatal(1, "UART DIVISOR 434 VERIFICATION FAILED!");
    end

endmodule
