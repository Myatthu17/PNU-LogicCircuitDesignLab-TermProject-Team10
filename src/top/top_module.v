// top_module.v
module top_module(
    input  mode_switch,
    input        clk,
    input        reset,
    output reg [7:0] lcd_out
);

    wire [7:0] calc_out;
    wire [7:0] puzzle_out;

    // Dummy calculator module
    calculator calc_inst(
        .clk(clk),
        .reset(reset),
        .out(calc_out)
    );

    // Dummy puzzle game module
    puzzle_game puzzle_inst(
        .clk(clk),
        .reset(reset),
        .out(puzzle_out)
    );

    always @(*) begin
        case(mode_switch)
            1'b0: $display("Mode: Calculator, Output: %c", calc_out);
            1'b1: $display("Mode: Puzzle, Output: %c", puzzle_out);
            default: lcd_out = 8'h00;
        endcase
    end

endmodule

// module top_module(
//     input        clk,
//     input        rst,
//     input        mode_switch,        // 0 = calculator, 1 = puzzle game
//     input  [9:0] btn,               // keypad buttons for calculator
//     output       rs,
//     output       rw,
//     output       e,
//     output [3:0] lcd_data,          // 4-bit LCD data bus
//     output [6:0] seg                // 7-segment display
// );

//     // -----------------------------
//     // Calculator signals
//     // -----------------------------
//     wire [3:0] calc_number;
//     wire        calc_valid;
//     wire        calc_write;
//     wire [7:0] calc_ascii;

//     calculator1 calc_inst(
//         .clk(clk),
//         .rst(rst),
//         .btn0(btn[0]), .btn1(btn[1]), .btn2(btn[2]), .btn3(btn[3]), .btn4(btn[4]),
//         .btn5(btn[5]), .btn6(btn[6]), .btn7(btn[7]), .btn8(btn[8]), .btn9(btn[9]),
//         .rs(rs),
//         .rw(rw),
//         .e(e),
//         .lcd_data(lcd_data)
//     );

//     // 7-segment for calculator
//     seven_seg seg_inst(
//         .number(calc_number),
//         .seg(seg)
//     );

//     // -----------------------------
//     // Puzzle game signals
//     // -----------------------------
//     wire [7:0] puzzle_ascii;
//     wire        puzzle_write;

//     // Dummy puzzle game module
//     puzzle_game puzzle_inst(
//         .clk(clk),
//         .reset(reset),
//         .out(puzzle_out)
//     );

//     // -----------------------------
//     // LCD control logic
//     // -----------------------------
//     // Only one module drives LCD at a time
//     assign calc_write   = (mode_switch == 1'b0) ? calc_valid : 1'b0;
//     assign puzzle_write = (mode_switch == 1'b1) ? puzzle_write : 1'b0;

//     // 7-segment only shows calculator in calculator mode
//     assign seg = (mode_switch == 1'b0) ? seg : 7'b0000000;

// endmodule
