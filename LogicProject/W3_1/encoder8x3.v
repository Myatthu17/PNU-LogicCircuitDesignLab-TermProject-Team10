module encoder8x3(i, a);

input [7:0] i;
output [2:0] a;

wire [2:0] a;

assign a[0] = i[1] | i[3] | i[5] | i[7];
assign a[1] = i[2] | i[3] | i[6] | i[7];
assign a[2] = i[4] | i[5] | i[6] | i[7];

endmodule