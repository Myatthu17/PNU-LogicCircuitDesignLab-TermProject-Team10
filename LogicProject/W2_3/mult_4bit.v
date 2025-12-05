module mult_4bit(a,b,m);

input [3:0] a,b;
output [7:0] m;

assign m = a*b;

endmodule