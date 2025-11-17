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

    typedef enum reg [2:0] {
        INIT = 3'd0,
        IDLE = 3'd1,
        SEND_DATA = 3'd2,
        WAIT = 3'd3
    } state_t;

    state_t state, next_state;
    reg [7:0] command;
    reg send_high_nibble;
    reg [15:0] delay_cnt;

    // Clock divider for LCD timing (~1ms)
    localparam CLK_DIV = 50000;
    reg [15:0] clk_cnt;
    wire lcd_clk;
    assign lcd_clk = (clk_cnt == CLK_DIV);

    always @(posedge clk or posedge rst) begin
        if (rst) clk_cnt <= 0;
        else if (clk_cnt == CLK_DIV) clk_cnt <= 0;
        else clk_cnt <= clk_cnt + 1;
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= INIT;
            next_state <= INIT;
            e <= 0; rs <= 0; rw <= 0; data_bus <= 0;
            delay_cnt <= 0;
            send_high_nibble <= 1;
        end else if (lcd_clk) begin
            state <= next_state;
            next_state = state; // default

            case (state)
                INIT: begin
                    command <= 8'b00101000; // 4-bit, 2 lines, 5x8 font
                    rs <= 0; rw <= 0;
                    data_bus <= send_high_nibble ? command[7:4] : command[3:0];
                    e <= 1;
                    send_high_nibble <= ~send_high_nibble;
                    if (!send_high_nibble) begin
                        next_state <= WAIT;
                        delay_cnt <= 0;
                    end
                end

                WAIT: begin
                    e <= 0;
                    delay_cnt <= delay_cnt + 1;
                    if (delay_cnt >= 2000) begin
                        if (write_text)
                            next_state <= SEND_DATA;
                        else
                            next_state <= IDLE;
                    end
                end

                IDLE: begin
                    e <= 0; rs <= 0; rw <= 0; data_bus <= 0;
                    if (write_text)
                        next_state <= SEND_DATA;
                end

                SEND_DATA: begin
                    rs <= 1; rw <= 0;
                    data_bus <= send_high_nibble ? data_in[7:4] : data_in[3:0];
                    e <= 1;
                    send_high_nibble <= ~send_high_nibble;
                    if (!send_high_nibble)
                        next_state <= WAIT;
                end
            endcase
        end
    end
endmodule
