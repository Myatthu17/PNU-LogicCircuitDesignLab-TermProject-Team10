module shift_register(clk, rst, d_in, q);

input clk, rst, d_in;
output reg[3:0] q;

always @(posedge clk or posedge rst) begin
    if (rst)
        q <= 4'b0000;
    else
        q <= {q[2:0], d_in};

end

endmodule