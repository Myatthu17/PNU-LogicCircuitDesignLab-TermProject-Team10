module counter_dnup (rst, updn, clk, q);

input rst, updn, clk;
output [3:0]    q;

reg [3:0]   q;

always  @(posedge rst   or  posedge clk)
begin
    if (rst)    q=0;
    else
        if (updn)
            q = q + 1;
        else
            q = q - 1;
        
end

endmodule