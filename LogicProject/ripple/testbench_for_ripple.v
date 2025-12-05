`timescale 10ns / 100ps

module testbench();

reg[3:0] a, b;

wire [3:0] s;

ripple_carry_adder u1(a, b, s);

initial begin
    a = 4'b0000; b = 4'b0000;
    #20 a = 4'b1010; b = 4'b0111;
    #20 a = 4'b0110; b = 4'b1011;
    #20 a = 4'b0101; b = 4'b0101;
    #20 a = 4'b0010; b = 4'b1001;

end
endmodule