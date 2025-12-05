module top(
    input clk,          // 1 MHz clock from board
    input rst,          // reset switch
    input mode,         // DIP switch
    input btn,          // push button
    output [3:0] r,
    output [3:0] g,
    output [3:0] b
);

    wire pulse;

    // ?? ???
    trigger u_trigger (
        .clk(clk),
        .btn(btn),
        .pulse(pulse)
    );

    // ??? ?? FSM
    traffic_light u_traffic_light (
        .clk(clk),
        .rst(rst),
        .mode(mode),
        .pulse(pulse),
        .r(r),
        .g(g),
        .b(b)
    );

endmodule