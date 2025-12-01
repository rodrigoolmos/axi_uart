module top_uart #(
    parameter FIFO_DEPTH = 32,
    parameter C_DATA_WIDTH = 32,
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200

) (
    input  logic                     clk,
    input  logic                     nrst,

    // AXI4-Lite SLAVE
    input  logic [31:0]  awaddr,
    input  logic [3:0]               awprot,
    input  logic                     awvalid,
    output logic                     awready,

    input  logic [C_DATA_WIDTH-1:0]  wdata,
    input  logic [C_DATA_WIDTH/8-1:0] wstrb,
    input  logic                     wvalid,
    output logic                     wready,

    output logic [1:0]               bresp,
    output logic                     bvalid,
    input  logic                     bready,

    input  logic [31:0]  araddr,
    input  logic [3:0]               arprot,
    input  logic                     arvalid,
    output logic                     arready,

    output logic [C_DATA_WIDTH-1:0]  rdata,
    output logic [1:0]               rresp,
    output logic                     rvalid,
    input  logic                     rready,

    // UART interface
    input  logic                     rx,
    output logic                     tx

);

    // Internal signals
    logic [7:0] uart_data_recv;
    logic fifo_empty;

    logic [7:0] uart_data_send;
    logic uart_tx_done;
    logic uart_new_rx;

    // Instantiate AXI to FIFOs module
    axi_s_to_fifos #(
        .FIFO_DEPTH(FIFO_DEPTH),
        .C_DATA_WIDTH(C_DATA_WIDTH)
    ) axi_to_fifos_inst (
        .clk(clk),
        .nrst(nrst),

        .awaddr(awaddr),
        .awprot(awprot),
        .awvalid(awvalid),
        .awready(awready),

        .wdata(wdata),
        .wstrb(wstrb),
        .wvalid(wvalid),
        .wready(wready),

        .bresp(bresp),
        .bvalid(bvalid),
        .bready(bready),

        .araddr(araddr),
        .arprot(arprot),
        .arvalid(arvalid),
        .arready(arready),

        .rdata(rdata),
        .rresp(rresp),
        .rvalid(rvalid),
        .rready(rready),

        .fifo_wdata(uart_data_recv),
        .fifo_full(),
        .fifo_almost_full(),
        .fifo_wena(uart_new_rx),

        .fifo_rdata(uart_data_send),
        .fifo_empty(fifo_empty),
        .fifo_almost_empty(),
        .fifo_rena(uart_tx_done)
    );

    // Instantiate UART module
    uart #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uart_inst (
        .clk(clk),
        .nrst(nrst),
        .rx(rx),
        .tx(tx),

        .data_send(uart_data_send),
        .data_recv(uart_data_recv),
        .ena_tx(!fifo_empty),
        .tx_done(uart_tx_done),
        .error_rx(),
        .new_rx(uart_new_rx)
    );
    
endmodule