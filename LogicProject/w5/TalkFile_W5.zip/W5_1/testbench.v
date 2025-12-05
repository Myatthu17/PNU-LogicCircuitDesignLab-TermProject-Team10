`timescale  1ns / 1ps

module testbench;

reg rst;
reg updn;
reg clk;
wire [3:0] q;

counter_dnup DUT (
    .rst (rst),
    .updn (updn),
    .clk (clk),
    .q (q)
);
always #5 clk = ~clk;

initial begin
    // ??? ??
    clk = 0;
    rst = 1;
    updn = 0;

    // ?? ?? ? ??
    #10 rst = 0;

    // ???? (updn = 1)
    updn = 1;
    #100;

    // ????? (updn = 0)
    updn = 0;
    #100;

    // ?? ??
    rst = 1;
    #10;
    rst = 0;

    // ??
    #50;
    $finish;
end

// ?? ????
initial begin
    $monitor("Time=%0t | rst=%b | updn=%b | q=%b", $time, rst, updn, q);
end

endmodule