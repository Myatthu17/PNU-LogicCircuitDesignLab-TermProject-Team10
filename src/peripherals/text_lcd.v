module text_lcd(
    input clk,
    input rst,
    input write_text,
    input [7:0] data_in,
    input data_valid,
    output reg rs,
    output reg rw,
    output reg e,
    output reg [3:0] data_bus
);

    // -----------------------------
    // State machine states
    // -----------------------------
    localparam INIT       = 3'd0;
    localparam IDLE       = 3'd1;
    localparam SEND_DATA  = 3'd2;
    localparam WAIT       = 3'd3;

    reg [2:0] state;
    reg [2:0] next_state;

    reg [7:0] command;
    reg send_high_nibble;
    reg [15:0] delay_cnt;

    // -----------------------------
    // Clock divider for ~1ms pulses
    // -----------------------------
    localparam CLK_DIV = 50000;  
    reg [15:0] clk_cnt;
    wire lcd_clk;

    assign lcd_clk = (clk_cnt == CLK_DIV);

    always @(posedge clk or posedge rst) begin
        if (rst)
            clk_cnt <= 16'd0;
        else if (clk_cnt == CLK_DIV)
            clk_cnt <= 16'd0;
        else
            clk_cnt <= clk_cnt + 1;
    end

    // -----------------------------
    // Main FSM
    // -----------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= INIT;
            next_state <= INIT;

            e <= 0;
            rs <= 0;
            rw <= 0;
            data_bus <= 4'd0;

            delay_cnt <= 16'd0;
            send_high_nibble <= 1'b1;
            command <= 8'd0;
        end else if (lcd_clk) begin
            state <= next_state;   // update state
            next_state = state;    // default

            case (state)

                // -----------------------------
                // LCD Initialization
                // -----------------------------
                INIT: begin
                    command <= 8'b00101000; // 4-bit, 2-line, 5x8 dots
                    rs <= 1'b0;
                    rw <= 1'b0;

                    if (send_high_nibble)
                        data_bus <= command[7:4];
                    else
                        data_bus <= command[3:0];

                    e <= 1'b1;
                    send_high_nibble <= ~send_high_nibble;

                    if (!send_high_nibble) begin
                        next_state <= WAIT;
                        delay_cnt <= 16'd0;
                    end
                end

                // -----------------------------
                // Delay between operations
                // -----------------------------
                WAIT: begin
                    e <= 1'b0;

                    delay_cnt <= delay_cnt + 1;

                    if (delay_cnt >= 16'd2000) begin
                        if (write_text)
                            next_state <= SEND_DATA;
                        else
                            next_state <= IDLE;
                    end
                end

                // -----------------------------
                // Do nothing
                // -----------------------------
                IDLE: begin
                    e <= 0;
                    rs <= 0;
                    rw <= 0;
                    data_bus <= 4'd0;

                    if (write_text)
                        next_state <= SEND_DATA;
                end

                // -----------------------------
                // Send 1 character to LCD
                // -----------------------------
                SEND_DATA: begin
                    rs <= 1;
                    rw <= 0;

                    if (send_high_nibble)
                        data_bus <= data_in[7:4];
                    else
                        data_bus <= data_in[3:0];

                    e <= 1;
                    send_high_nibble <= ~send_high_nibble;

                    if (!send_high_nibble)
                        next_state <= WAIT;
                end

            endcase
        end
    end

endmodule
