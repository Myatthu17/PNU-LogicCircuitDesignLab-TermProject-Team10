module piezo(clk, rst, piezo);

input clk, rst;
output piezo;

reg piezo;
reg [11:0] cnt;

always @(posedge clk)
    if (rst)    cnt = 0;
    else if (cnt >= 3830 / 2)
        begin
            piezo = !piezo;
            cnt = 0;
        end
    else
        cnt = cnt + 1;
    
endmodule