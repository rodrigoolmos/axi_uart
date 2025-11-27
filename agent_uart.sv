interface uart_if #(
    parameter int unsigned BAUD_RATE = 115_200
);
    timeunit      1ns;
    timeprecision 1ps;

    localparam time BIT_TIME  = 1s / BAUD_RATE;
    localparam int BIT_TIME_INT  = 1_000_000_000 / BAUD_RATE;
    localparam int MAX_JITTER = BIT_TIME_INT / 10;

    logic tx;
    logic rx;

    task automatic send_byte(input logic [7:0] data);
        int  i;
        int  jitter_steps;
        time bit_delay;

        // IDLE
        rx = 1'b1;
        jitter_steps = $urandom_range(0, integer'(2*MAX_JITTER)) - MAX_JITTER;
        bit_delay    = BIT_TIME_INT + jitter_steps;
        #(bit_delay);

        // START
        rx = 1'b0;
        jitter_steps = $urandom_range(0, integer'(2*MAX_JITTER)) - MAX_JITTER;
        bit_delay    = BIT_TIME_INT + jitter_steps;
        #(bit_delay);

        // DATA
        for (i = 0; i < 8; i++) begin
            rx = data[i];
            jitter_steps = $urandom_range(0, integer'(2*MAX_JITTER)) - MAX_JITTER;
            bit_delay    = BIT_TIME_INT + jitter_steps;
            #(bit_delay);
        end

        // STOP
        rx = 1'b1;
        jitter_steps = $urandom_range(0, integer'(2*MAX_JITTER)) - MAX_JITTER;
        bit_delay    = BIT_TIME_INT + jitter_steps;
        #(bit_delay);
    endtask


    task automatic receive_byte(output logic [7:0] data);
        int i;

        @(negedge tx);

        #(BIT_TIME / 2);

        for (i = 0; i < 8; i++) begin
            #(BIT_TIME);
            data[i] = tx;
        end

        #(BIT_TIME);
    endtask

    typedef enum logic[1:0] { 
        IDLE,
        START,
        DATA,
        STOP
    } uart_rx_state_t;

    // int bit_index = 0;

    // uart_rx_state_t rx_state = IDLE;

    // task automatic assert_receive_byte();
    //     rx_state = IDLE;
    //     bit_index = 0;
    //     @ (negedge tx);
    //     rx_state = START;

    //     for (int i=0; i<8; ++i) begin
    //         #(BIT_TIME);
    //         rx_state = DATA;
    //         bit_index = i;
    //     end

    //     #(BIT_TIME);
    //     rx_state = STOP;

    // endtask


endinterface


class uart_agent;

    virtual uart_if.tb vif;

    logic [7:0] rx_data_list[$];
    logic [7:0] expected_tx_list[$];
    bit stop_listen;

    function new(virtual uart_if.tb vif);
        this.vif = vif;
    endfunction

    function void expect_tx_byte(input logic [7:0] data);
        expected_tx_list.push_back(data);
    endfunction

    task send_byte(input logic [7:0] data);
        vif.send_byte(data);
    endtask

    logic [7:0] b = 0;
    task start_listening();
        stop_listen = 0;
        fork
            forever begin
                if (stop_listen) break;
                vif.receive_byte(b);
                //assert_receive_byte();
                rx_data_list.push_back(b);
                score_tx_byte(b);
            end
        join_none
    endtask

    task automatic score_tx_byte(input logic [7:0] actual_data);
        logic [7:0] expected;

        TX_received_unexpected: assert (expected_tx_list.size() != 0) begin
            expected = expected_tx_list.pop_front();
            TX_data_mismatch: assert (expected === actual_data)
                else $error("TX Data mismatch: expected 0x%0h, received 0x%0h"
                    , expected, actual_data);
        end
            else $error("TX received unexpected byte 0x%0h (queue empty)", actual_data);
    
    endtask

    task stop_listening();
        stop_listen = 1;
    endtask

endclass
