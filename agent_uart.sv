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

    // helper signal for property checking

    typedef enum logic[1:0] { 
        IDLE,
        START,
        DATA,
        STOP
    } uart_rx_state_t;

    logic internal_clk;
    int bit_index = 0;
    uart_rx_state_t rx_state = IDLE;
    logic ward = 0;
    time ward_value = BIT_TIME_INT/20;
    time bit_value = BIT_TIME_INT - BIT_TIME_INT/10;


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

    task automatic assert_receive_byte();
        rx_state = IDLE;
        bit_index = 0;
        @ (negedge tx);
        rx_state = START;
        #(BIT_TIME);

        for (int i=0; i<8; ++i) begin
            rx_state = DATA;
            bit_index = i;
            #(BIT_TIME);
        end

        rx_state = STOP;
        #(9*BIT_TIME/10);
    endtask

    task automatic ward_receive_byte();

        ward = 1;
        @ (negedge tx);
        for (int i=0; i<9; ++i) begin
            ward = 0;
            #(ward_value);
            ward = 1;
            #(bit_value);
            ward = 0;
            #(ward_value);
        end
        ward = 0;
        #(ward_value);
        ward = 1;
        #(bit_value);
        ward = 0;
        #(ward_value/2);

    endtask

    start_bit: assert property (
        @(posedge internal_clk)
        (rx_state == START && ward == 1) |-> (tx == 1'b0)
    ) else $error("Start bit failed: tx != 0");

    data_bit: assert property (
        @(posedge internal_clk)
        (rx_state == DATA && ward == 1) |=> $stable(tx)
    ) else $error("Data bit failed: tx not stable");

    stop_bit: assert property (
        @(posedge internal_clk)
        (rx_state == STOP && ward == 1) |-> (tx == 1'b1)
    ) else $error("Stop bit failed: tx != 1");

    cover_start: cover property (
        @(posedge internal_clk)
        rx_state == START && ward && tx == 1'b0
    );

    idle_line_high: assert property (
        @(posedge internal_clk)
        (rx_state == IDLE && ward) |-> (tx == 1'b1)
    );


    cover_data_0: cover property (
        @(posedge internal_clk)
        rx_state == DATA && ward && tx == 1'b0
    );

    cover_data_1: cover property (
        @(posedge internal_clk)
        rx_state == DATA && ward && tx == 1'b1
    );

    cover_stop: cover property (
        @(posedge internal_clk)
        rx_state == STOP && ward && tx == 1'b1
    );

    initial begin
        internal_clk = 0;
        forever #5ns internal_clk = ~internal_clk;
    end

endinterface


class uart_agent;

    virtual uart_if.tb vif;

    logic [7:0] rx_data_list[$];
    logic [7:0] expected_tx_list[$];
    bit stop_listen;

    function new(virtual uart_if.tb vif);
        this.vif = vif;
        vif.rx = 1'b1;
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
                fork
                    begin
                        vif.ward_receive_byte();
                    end
                    begin
                        vif.assert_receive_byte();
                    end
                    begin
                        vif.receive_byte(b);
                        rx_data_list.push_back(b);
                        score_tx_byte(b);
                    end
                join
                
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
