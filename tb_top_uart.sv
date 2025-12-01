`timescale 1ns/1ps
`include "axi_s_to_fifos/axi_lite_template/agent_axi_lite.sv"
`include "axi_s_to_fifos/axi_s_to_fifos.sv"
`include "agent_uart.sv"

module tb_top_uart;

    // Parameters
    localparam FIFO_DEPTH = 32;
    localparam C_DATA_WIDTH = 32;
    localparam CLK_FREQ = 50_000_000;
    localparam BAUD_RATE = 115200;
    const integer CLK_PERIOD = 1_000_000_000 / CLK_FREQ; // in ns

    localparam ADDR_STATUS  = 0;
    localparam ADDR_WRITE   = 1;
    localparam ADDR_READ    = 2;

    // Instantiate uart interface agent
    uart_if #(
        .BAUD_RATE(BAUD_RATE)
    ) uart_if();

    uart_agent uart;

    // Instantiate AXI4-Lite interface agent
    axi_if #(
        .DATA_WIDTH(C_DATA_WIDTH),
        .ADDR_WIDTH(4)
    ) axi_if();

    axi_lite_master #(
        .DATA_WIDTH(C_DATA_WIDTH),
        .ADDR_WIDTH(4)
    ) axi_m;

    // Instantiate the top_uart module
    top_uart #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .C_DATA_WIDTH(C_DATA_WIDTH),
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(axi_if.clk),
        .nrst(axi_if.nrst),

        .awaddr (axi_if.awaddr),
        .awprot (axi_if.awprot),
        .awvalid(axi_if.awvalid),
        .awready(axi_if.awready),
        .wdata  (axi_if.wdata),
        .wstrb  (axi_if.wstrb),
        .wvalid (axi_if.wvalid),
        .wready (axi_if.wready),
        .bresp  (axi_if.bresp),
        .bvalid (axi_if.bvalid),
        .bready (axi_if.bready),
        .araddr (axi_if.araddr),
        .arprot (axi_if.arprot),
        .arvalid(axi_if.arvalid),
        .arready(axi_if.arready),
        .rdata  (axi_if.rdata),
        .rresp  (axi_if.rresp),
        .rvalid (axi_if.rvalid),
        .rready (axi_if.rready),

        .rx(uart_if.rx),
        .tx(uart_if.tx)
    );

    // Clock generation
    initial begin
        axi_if.clk = 0;
        forever #(CLK_PERIOD/2) axi_if.clk = ~axi_if.clk; // 50 MHz clock
    end


    // Reset generation
    initial begin
        axi_if.nrst = 0;
        #100;
        axi_if.nrst = 1;
    end

    // Test stimulus
    logic [31:0] temp_data;
    initial begin
        axi_m = new(axi_if);
        uart = new(uart_if);
        axi_m.reset_if();

        // Write to AXI4-Lite
        @(posedge axi_if.nrst);
        repeat (10) @(posedge axi_if.clk);

        axi_m.write(32'h0000_0001, ADDR_WRITE * 4, 4'hF);
        axi_m.write(32'h0000_0002, ADDR_WRITE * 4, 4'hF);
        axi_m.write(32'h0000_0003, ADDR_WRITE * 4, 4'hF);
        axi_m.write(32'h0000_0004, ADDR_WRITE * 4, 4'hF);
        axi_m.write(32'h0000_0005, ADDR_WRITE * 4, 4'hF);

        uart.send_byte(8'h11);
        uart.send_byte(8'h12);
        uart.send_byte(8'h13);
        uart.send_byte(8'h14);
        uart.send_byte(8'h15);

        axi_m.read(temp_data, ADDR_READ * 4);
        $display("Read from AXI: 0x%0h", temp_data);
        axi_m.read(temp_data, ADDR_READ * 4);
        $display("Read from AXI: 0x%0h", temp_data);
        axi_m.read(temp_data, ADDR_READ * 4);
        $display("Read from AXI: 0x%0h", temp_data);
        axi_m.read(temp_data, ADDR_READ * 4);
        $display("Read from AXI: 0x%0h", temp_data);
        axi_m.read(temp_data, ADDR_READ * 4);
        $display("Read from AXI: 0x%0h", temp_data);

        repeat (1000) @(posedge axi_if.clk);
        $finish;
    end

endmodule