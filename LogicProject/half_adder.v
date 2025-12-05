module half_adder(
    input a,
    input b,
    output s,
    output c);
    
    xor u_xor (s, a, b);
    
    and u_and (c, a, b);

endmodule