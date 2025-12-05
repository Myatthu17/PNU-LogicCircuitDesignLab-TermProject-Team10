`timescale 10ns / 100ps

module testbench();

reg [7:0] i;

wire [2:0] a;

encoder8x3 u1(i, a);

initial begin 
        i = 8'b0000_0000;
 #10    i = 8'b1000_0000;
 #10    i = 8'b0100_0000;
 #10    i = 8'b0010_0000;
 #10    i = 8'b0001_0000;
 #10    i = 8'b0000_1000;
 #10    i = 8'b0000_0100;
 #10    i = 8'b0000_0010;
 #10    i = 8'b0000_0001;
 #10    i = 8'b0000_0000;
end
endmodule