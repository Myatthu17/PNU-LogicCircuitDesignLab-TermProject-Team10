module calculator1(
    input clk,
    input rst,
    input btn0, btn1, btn2, btn3, btn4,
    input btn5, btn6, btn7, btn8, btn9,
    output rs,
    output rw,
    output e,
    output [3:0] lcd_data,
    output [6:0] seg // 7-segment output
);

    wire [3:0] number;
    wire valid;
    wire write_text;
    wire [7:0] number_ascii;

    // Keypad decoder
    keypad_decoder u_decoder(
        .clk(clk),
        .rst(rst),
        .btn0(btn0), .btn1(btn1), .btn2(btn2), .btn3(btn3), .btn4(btn4),
        .btn5(btn5), .btn6(btn6), .btn7(btn7), .btn8(btn8), .btn9(btn9),
        .number(number),
        .valid(valid)
    );

    // ASCII conversion for LCD
    assign number_ascii = valid ? (8'h30 + number) : 8'h20; // space if no button
    assign write_text = valid;

    // LCD instance
    text_lcd lcd_inst(
        .clk(clk),
        .rst(rst),
        .write_text(write_text),
        .data_in(number_ascii),
        .data_valid(valid),
        .rs(rs),
        .rw(rw),
        .e(e),
        .data_bus(lcd_data)
    );

    // 7-segment display
    seven_seg u_seg(
        .number(number),
        .seg(seg)
    );

endmodule
