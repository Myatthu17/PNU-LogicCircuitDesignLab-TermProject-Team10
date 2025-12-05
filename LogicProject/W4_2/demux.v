module demux(i, sel, o);

input i;
input [2:0] sel;

output [7:0] o;

wire [7:0] o;

assign o[7] = (sel == 3'b000) ? i : 1'b0;
assign o[6] = (sel == 3'b001) ? i : 1'b0;
assign o[5] = (sel == 3'b010) ? i : 1'b0;
assign o[4] = (sel == 3'b011) ? i : 1'b0;
assign o[3] = (sel == 3'b100) ? i : 1'b0;
assign o[2] = (sel == 3'b101) ? i : 1'b0;
assign o[1] = (sel == 3'b110) ? i : 1'b0;
assign o[0] = (sel == 3'b111) ? i : 1'b0;

endmodule
