`timescale 10ns / 100ps

module testbench();

reg i;
reg [2:0] s;

wire [7:0] o;

demux u1(i, s, o);

initial begin
     i = 0; s = 0;
     
     #10 s = 3'b001;
     #10 s = 3'b010;
     #10 s = 3'b011;
     #10 s = 3'b100;
     #10 s = 3'b101;
     #10 s = 3'b110;
     #10 s = 3'b111;
     #10 s = 3'b000;
end

always #1 i=~i;

endmodule