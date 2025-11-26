module uart #(
    parameter CLK_FREQ = 50_000_000,
    parameter BAUD_RATE = 115200
) (
    input  logic clk,
    input  logic nrst,
    input  logic rx,
    output logic tx,

    input  logic [7:0] data_send,
    output logic [7:0] data_recv,
    input  logic ena_tx,
    output logic tx_done,
    output logic new_rx

);

    // Calculate the number of clock cycles per bit
    localparam integer CYCLES_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam integer SAMPLE_BIT = CYCLES_PER_BIT / 2;

    // Transmitter state machine
    typedef enum logic [1:0] {
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT
    } uart_state_t;
    uart_state_t tx_state, rx_state;
    logic [3:0] tx_bit_cnt;
    logic [3:0] rx_bit_cnt;
    logic [1:0] rx_ff; // For synchronizing rx input

    logic [$clog2(CYCLES_PER_BIT):0] clk_div1;
    logic [$clog2(CYCLES_PER_BIT):0] clk_div2;
    logic tick_tx;

    // Transmitter logic
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            clk_div1 <= 0;
            tick_tx <= 0;
        end else begin
            if (clk_div1 == CYCLES_PER_BIT - 1) begin
                clk_div1 <= 0;
                tick_tx <= 1;
            end else begin
                clk_div1 <= clk_div1 + 1;
                tick_tx <= 0;
            end
        end
    end
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            tx_state <= IDLE;
            tx_bit_cnt <= 0;
            tx_done <= 0;
        end else if (tick_tx) begin
            case (tx_state)
                IDLE: begin
                    tx_done <= 0;
                    if (ena_tx && tick_tx) begin
                        tx_state <= START_BIT;
                    end
                end
                START_BIT: begin
                    if (tick_tx) begin
                        tx_state <= DATA_BITS;
                        tx_bit_cnt <= 0;
                    end
                end
                DATA_BITS: begin
                    if (tick_tx) begin
                        if (tx_bit_cnt == 7) begin
                            tx_state <= STOP_BIT;
                        end else begin
                            tx_bit_cnt <= tx_bit_cnt + 1;
                        end
                    end
                end
                STOP_BIT: begin
                    if (tick_tx) begin
                        tx_state <= IDLE;
                        tx_done <= 1;
                    end
                end
            endcase
        end
    end

    always_comb begin
        if (tx_state == DATA_BITS)
            tx <= data_send[tx_bit_cnt]; // Data bits
        else if (tx_state == STOP_BIT)
            tx <= 1'b1; // Stop bit
        else if (tx_state == START_BIT)
            tx <= 1'b0; // Start bit
        else
            tx <= 1'b1; // Idle state
    end

    // Receiver logic
    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            rx_ff <= 2'b11;
        end else begin
            rx_ff <= {rx_ff[0], rx};
        end
    end

    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            clk_div2 <= 0;
        end else begin
            if (clk_div2 == CYCLES_PER_BIT - 1 || rx_state == IDLE) begin
                clk_div2 <= 0;
            end else begin
                clk_div2 <= clk_div2 + 1;
            end
        end
    end

    always_ff @(posedge clk or negedge nrst) begin
        if (!nrst) begin
            rx_state <= IDLE;
            data_recv <= 8'b0;
            rx_bit_cnt <= 0;
            new_rx <= 0;
        end else begin
            case (rx_state)
                IDLE: begin
                    new_rx <= 0;
                    if (rx_ff[1] == 1'b0) begin // Start bit detected
                        rx_state <= START_BIT;
                    end
                end
                START_BIT: begin
                    if (clk_div2 == SAMPLE_BIT) begin
                        rx_state <= DATA_BITS;
                        rx_bit_cnt <= 0;
                    end
                end
                DATA_BITS: begin
                    if (clk_div2 == SAMPLE_BIT) begin
                        data_recv[rx_bit_cnt] <= rx_ff[1];
                        if (rx_bit_cnt == 7) begin
                            rx_state <= STOP_BIT;
                        end else begin
                            rx_bit_cnt <= rx_bit_cnt + 1;
                        end
                    end
                end
                STOP_BIT: begin
                    if (clk_div2 == SAMPLE_BIT) begin
                        rx_state <= IDLE;
                        new_rx <= 1;
                    end
                end
            endcase
        end
    end

endmodule