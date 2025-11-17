module text_lcd(
    input clk,            // System clock
    input rst,            // Reset
    input write_text,     // Trigger to write text
    input [7:0] data_in,  // ASCII data input
    input data_valid,     // High when data_in is valid
    output reg rs,        // Register Select
    output reg rw,        // Read/Write
    output reg e,         // Enable
    output reg [3:0] data_bus // 4-bit data bus
);

    // FSM states
    typedef enum reg [2:0] {
        INIT = 3'd0,
        IDLE = 3'd1,
        SEND_CMD = 3'd2,
        SEND_DATA = 3'd3,
        WAIT = 3'd4
    } state_t;

    state_t state, next_state;

    reg [7:0] command;
    reg [7:0] ascii_data;
    reg [15:0] delay_cnt;
    reg send_high_nibble;

    // Clock divider for LCD timing (~1ms pulse)
    localparam CLK_DIV = 50000; // adjust according to your clock
    reg [15:0] clk_cnt;
    wire lcd_clk;
    assign lcd_clk = (clk_cnt == CLK_DIV);

    always @(posedge clk or posedge rst) begin
        if (rst)
            clk_cnt <= 0;
        else if (clk_cnt == CLK_DIV)
            clk_cnt <= 0;
        else
            clk_cnt <= clk_cnt + 1;
    end

    // FSM
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= INIT;
            e <= 0;
            rs <= 0;
            rw <= 0;
            data_bus <= 0;
            delay_cnt <= 0;
            send_high_nibble <= 1;
        end else if (lcd_clk) begin
            state <= next_state;

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
                    if (delay_cnt == 2000) begin // small wait
                        if (write_text)
                            next_state <= SEND_DATA;
                        else
                            next_state <= IDLE;
                    end
                end

                IDLE: begin
                    e <= 0;
                    rs <= 0;
                    rw <= 0;
                    data_bus <= 0;
                    if (write_text)
                        next_state <= SEND_DATA;
                end

                SEND_DATA: begin
                    rs <= 1; // data mode
                    rw <= 0;
                    ascii_data <= data_in;
                    data_bus <= send_high_nibble ? data_in[7:4] : data_in[3:0];
                    e <= 1;
                    send_high_nibble <= ~send_high_nibble;
                    if (!send_high_nibble)
                        next_state <= WAIT;
                    else
                        next_state <= SEND_DATA;
                end
            endcase
        end
    end

endmodule
