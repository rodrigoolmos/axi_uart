module tb_uart;

    // Parameters
    parameter CLK_FREQ = 50_000_000;
    parameter BAUD_RATE = 115200;
    parameter CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE;

    // Signals
    logic clk;
    logic nrst;
    logic rx;
    logic tx;

    logic [7:0] data_send;
    logic [7:0] data_recv;
    logic ena_tx;
    logic tx_done;
    logic new_rx;

    // Instantiate UART module
    uart #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uut (
        .clk(clk),
        .nrst(nrst),
        .rx(rx),
        .tx(tx),
        .data_send(data_send),
        .data_recv(data_recv),
        .ena_tx(ena_tx),
        .tx_done(tx_done),
        .new_rx(new_rx)
    );

    task generate_rx(input [7:0] data);
        integer i;
        begin
            // Start bit
            rx = 1'b0;
            repeat (CYCLES_PER_BIT) @(posedge clk);
            #1;

            // Data bits
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                repeat (CYCLES_PER_BIT) @(posedge clk);
                #1;
            end

            // Stop bit
            rx = 1'b1;
            repeat (CYCLES_PER_BIT) @(posedge clk);
            #1;
        end
        
    endtask

    // Clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz clock
    end

    // Test sequence
    initial begin
        // Initialize signals
        nrst = 0;
        ena_tx = 0;
        data_send = 8'h00;
        rx = 1'b1; // Idle state
        @ (posedge clk);
        nrst = 1;

        data_send = 8'hA5; // Example data
        ena_tx = 1;
        @ (posedge clk);

        // Wait for transmission to complete
        @ (posedge clk iff tx_done);
        @ (posedge clk);

        // Add more test cases as needed

        generate_rx(8'h5A); // Example received data
        // Finish simulation
        #1000;
        $finish;
    end

endmodule