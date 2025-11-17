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
            1'b0: lcd_out = calc_out;
            1'b1: lcd_out = puzzle_out;
            default: lcd_out = 8'h00;
        endcase
    end

endmodule