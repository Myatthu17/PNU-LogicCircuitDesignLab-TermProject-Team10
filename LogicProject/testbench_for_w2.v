`timescale 10ns / 100ps

module testbench();

reg a, b, cin;

wire s, cout;

full_adder u1(a, b, cin, s, cout);

initial begin
    a = 0; b = 0; cin = 0;
    #10 a = 1; b = 0; cin = 0;
    #10 a = 0; b = 1; cin = 0;
    #10 a = 1; b = 1; cin = 0;
    #10 a = 0; b = 0; cin = 1;
    #10 a = 1; b = 0; cin = 1;
    #10 a = 0; b = 1; cin = 1;
    #10 a = 1; b = 1; cin = 1;

end

endmodule    