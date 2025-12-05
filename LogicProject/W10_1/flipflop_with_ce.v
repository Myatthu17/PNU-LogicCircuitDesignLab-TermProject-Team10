module flipflop_with_ce(clk, rst, d_in, c_e, q_out);

input clk, rst, d_in, c_e;
output reg q_out;

always @(posedge clk or posedge rst) begin

    if(rst)
        q_out <= 1'b0;
    else if (c_e)
        q_out <= d_in;
    else
        q_out <= q_out;
end

endmodule