module decimal_to_binary(O, T, B);

input [3:0] O;
input [3:0] T;
output [6:0] B;

wire [6:0] B;
wire [6:0] T_ext, O_ext, T_mul8, T_mul2;

assign T_ext = {3'b000, T};
assign O_ext = {3'b000, O};
assign T_mul8 = T_ext << 3;
assign T_mul2 = T_ext << 1;
assign B = T_mul8 + T_mul2 + O_ext;

endmodule
