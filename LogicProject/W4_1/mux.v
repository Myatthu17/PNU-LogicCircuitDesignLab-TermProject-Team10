module mux(i, sel, z);

input [3:0] i;
input [1:0] sel;
output z;

reg z;

always @(i, sel)
    case(sel)
        2'b00 : z <= i[3];
        2'b01 : z <= i[2];
        2'b10 : z <= i[1];
        2'b11 : z <= i[0];
    endcase
    
endmodule
    