interface uart_if #(
    parameter int unsigned BAUD_RATE = 115_200
);
    timeunit      1ns;
    timeprecision 1ps;

    localparam time BIT_TIME = 1s / BAUD_RATE;

    logic tx;
    logic rx;

    task automatic send_byte(input logic [7:0] data);
        int i;

        rx = 1'b1;
        #(BIT_TIME);

        rx = 1'b0;
        #(BIT_TIME);

        for (i = 0; i < 8; i++) begin
            rx = data[i];
            #(BIT_TIME);
        end

        rx = 1'b1;
        #(BIT_TIME);
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
                rx_data_list.push_back(b);
                score_tx_byte(b);
            end
        join_none
    endtask

    task automatic score_tx_byte(input logic [7:0] actual_data);
        logic [7:0] expected;

        if (expected_tx_list.size() == 0) begin
            $error("TX received unexpected byte 0x%0h (queue empty)", actual_data);
        end else begin
            expected = expected_tx_list.pop_front();
            if (expected !== actual_data) begin
                $error("TX Data mismatch: expected 0x%0h, received 0x%0h", expected, actual_data);
            end
        end
    endtask

    task stop_listening();
        stop_listen = 1;
    endtask

    task check_integrity(input logic [7:0] expected_data[$]);
        int n_exp  = expected_data.size();
        int n_recv = rx_data_list.size();

        n_recv_dif_n_exp: assert (n_recv == n_exp)
            else $error("TX Received %0d bytes, expected %0d bytes", n_recv, n_exp);

        if (expected_tx_list.size() != 0) begin
            $error("TX Scoreboard pending %0d expected bytes", expected_tx_list.size());
        end

        for (int i = 0; i < n_exp; i++) begin
            data_match: assert (rx_data_list[i] == expected_data[i])
                else $error("TX Data mismatch at index %0d: received 0x%0h, expected 0x%0h",
                            i, rx_data_list[i], expected_data[i]);
        end
    endtask


endclass
