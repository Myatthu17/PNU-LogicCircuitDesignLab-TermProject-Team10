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

parameter CLK_PERIOD = 20;

initial begin
    clk = 1'b0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
end

initial begin
    rst = 1'b1;
    updn = 1'b0;
    #50;
    
    rst = 1'b0;
    updn = 1'b0;
    #200;
    
    updn = 1'b1;
    #200;
    
    rst = 1'b1;
    #50;
    
    $stop;
end

endmodule