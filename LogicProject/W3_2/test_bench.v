`timescale 10ns / 100ps

module testbench();

reg [3:0] O;
reg [3:0] T;
wire [6:0] B;

decimal_to_binary u1(O, T, B);

initial begin
        O = 4'b0000; T = 4'b0000;
 #10    O = 4'b0001; T = 4'b0010;   
 #10    O = 4'b1000; T = 4'b0001;   
 #10    O = 4'b0010; T = 4'b0110;   
 #10    O = 4'b0000; T = 4'b0000;
end
endmodule
