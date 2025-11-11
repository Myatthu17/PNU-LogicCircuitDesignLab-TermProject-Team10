`timescale 1us/1ns   // 1 µs time unit for simulation clarity

module tb_lcd_controller;

    // --- Testbench signals ---
    reg CLK;
    reg RESET;
    reg [7:0] ASCII_DATA;
    reg START_WRITE;
    reg [3:0] DISPLAY_ADDR;
    wire LCD_RS;
    wire LCD_E;
    wire [3:0] LCD_DATA;

    // --- Instantiate DUT ---
    lcd_controller #(
        .BAUD_RATE(200)
    ) dut (
        .CLK(CLK),
        .RESET(RESET),
        .ASCII_DATA(ASCII_DATA),
        .START_WRITE(START_WRITE),
        .DISPLAY_ADDR(DISPLAY_ADDR),
        .LCD_RS(LCD_RS),
        .LCD_E(LCD_E),
        .LCD_DATA(LCD_DATA)
    );

    // --- Clock Generation ---
    always #0.5 CLK = ~CLK;  // 1 MHz clock (1 µs period)

    // --- Simulation sequence ---
    initial begin
        $dumpfile("lcd_controller_tb.vcd");
        $dumpvars(0, tb_lcd_controller);

        CLK = 0;
        RESET = 1;
        START_WRITE = 0;
        ASCII_DATA = 8'd0;
        DISPLAY_ADDR = 4'd0;

        // Reset phase
        #10;
        RESET = 0;

        // Wait for LCD initialization
        #100000;  // 100 ms (for LCD power-up simulation)

        // --- Write Sequence: "123+45=168" ---
        send_char(4'd0,  "1");
        send_char(4'd1,  "2");
        send_char(4'd2,  "3");
        send_char(4'd3,  "+");
        send_char(4'd4,  "4");
        send_char(4'd5,  "5");
        send_char(4'd6,  "=");
        send_char(4'd7,  "1");
        send_char(4'd8,  "6");
        send_char(4'd9,  "8");

        // Wait some time to finish
        #200000;
        $finish;
    end

    // --- Helper Task: Send one character to LCD ---
    task send_char(input [3:0] addr, input [7:0] char_ascii);
        begin
            DISPLAY_ADDR = addr;
            ASCII_DATA = char_ascii;
            START_WRITE = 1;
            #10;           // short pulse
            START_WRITE = 0;
            #50000;        // wait ~50 ms before next char (LCD busy delay)
        end
    endtask

endmodule
