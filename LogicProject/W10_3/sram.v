module sram (
    input clk,
    input rst,
    input DataIn,
    input RW,
    input [1:0] Address,
    output [3:0] Q,       // Register values (LED1~4)
    output DataOut        // Read result (LED8)
);
    wire [3:0] we;
    wire [3:0] q_reg;

    selector s0(.RW(RW), .addr(Address), .we(we));

    register_1bit r0(.clk(clk), .rst(rst), .we(we[0]), .d(DataIn), .q(q_reg[0]));
    register_1bit r1(.clk(clk), .rst(rst), .we(we[1]), .d(DataIn), .q(q_reg[1]));
    register_1bit r2(.clk(clk), .rst(rst), .we(we[2]), .d(DataIn), .q(q_reg[2]));
    register_1bit r3(.clk(clk), .rst(rst), .we(we[3]), .d(DataIn), .q(q_reg[3]));

    mux m0(.q(q_reg), .sel(Address), .out(DataOut));

    assign Q = q_reg;
endmodule