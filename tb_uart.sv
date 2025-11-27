`include "agent_uart.sv"


module tb_uart;

    timeunit      1ns;
    timeprecision 1ps;

    // Parameters
    parameter CLK_FREQ = 50_000_000;
    parameter BAUD_RATE = 115200;
    parameter CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE;
    parameter NUM_ITERATIONS = 100;

    // Signals
    logic clk;
    logic nrst;

    logic [7:0] data_send;
    logic [7:0] data_recv;
    logic ena_tx;
    logic tx_done;
    logic new_rx;

    logic [7:0] sending_data_tx[$];
    logic [7:0] sending_data_rx[$];
    logic [7:0] receiving_data_rx[$];

    // Instantiate UART interface
    uart_if #(
        .BAUD_RATE(BAUD_RATE)
    ) uart_if_inst ();

    // Agente
    uart_agent uart_ag;

    // Instantiate UART module
    uart #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uut (
        .clk(clk),
        .nrst(nrst),
        .rx(uart_if_inst.rx),
        .tx(uart_if_inst.tx),
        .data_send(data_send),
        .data_recv(data_recv),
        .ena_tx(ena_tx),
        .tx_done(tx_done),
        .new_rx(new_rx)
    );

    // Task send byte via tx line
    task automatic generate_tx(input logic [7:0] data);
        data_send = data;
        if (uart_ag != null) begin
            uart_ag.expect_tx_byte(data);
        end
        ena_tx = 1;
        @ (posedge clk iff tx_done);
        ena_tx = 0;
    endtask

    task automatic store_received_byte_rx();
        logic [7:0] expected;
        @ (posedge clk iff new_rx);
        receiving_data_rx.push_back(data_recv);

        RX_received_unexpected: assert (receiving_data_rx.size() != 0) begin
            expected = sending_data_rx.pop_front();
            RX_data_mismatch: assert (expected === data_recv)
                else $error("RX Data mismatch: expected 0x%0h, received 0x%0h",
                     expected, data_recv);
        end
            else $error("RX received unexpected byte 0x%0h (queue empty)", data_recv);

    endtask

    logic [7:0] b = 0;
    bit stop_listen;
    task start_listening();
        stop_listen = 0;
        fork
            forever begin
                if (stop_listen) break;
                store_received_byte_rx();
            end
        join_none
    endtask

    task stop_listening();
        stop_listen = 1;
    endtask

    task automatic init();
        nrst = 0;
        uart_ag = new(uart_if_inst);
        ena_tx = 0;
        data_send = 8'h00;
        uart_if_inst.rx = 1'b1; // Idle state
        @ (posedge clk);
        nrst = 1;
    endtask

    task send_some_bytes(input int num_bytes);
        logic [7:0] b;
        for (int i=0; i<num_bytes; ++i) begin
            b = $urandom_range(0, 255);
            generate_tx(b);
            sending_data_tx.push_back(b);
        end
    endtask

    task automatic recive_some_bytes(input int num_bytes);
        logic [7:0] b;
        for (int i=0; i<num_bytes; ++i) begin
            b = $urandom_range(0, 255);
            sending_data_rx.push_back(b);
            uart_ag.send_byte(b);
        end
    endtask

    // Clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // 50 MHz clock
    end

    int bytes_sent = 0;
    int bytes_received = 0;
    // Test sequence
    initial begin
        init();
        uart_ag.start_listening();
        start_listening();

        for (int i=0; i<NUM_ITERATIONS; ++i) begin
            
            fork
                begin
                    if ($urandom_range(0, 1)) begin
                        bytes_sent = $urandom_range(0, 10);
                        send_some_bytes(bytes_sent);
                    end else begin
                        repeat($urandom_range(0, 1000)) @ (posedge clk);
                    end
                end
    
                begin
                    if ($urandom_range(0, 1)) begin
                        bytes_received = $urandom_range(0, 10);
                        recive_some_bytes(bytes_received);
                    end else begin
                        repeat($urandom_range(0, 1000)) @ (posedge clk);
                    end
                end
            join

        end

        uart_ag.stop_listening();
        stop_listening();
        $finish;
    end

endmodule
