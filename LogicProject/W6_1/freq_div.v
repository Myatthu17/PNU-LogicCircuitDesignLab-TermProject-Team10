module freq_div(
    rst, clk, o_100, o_50, o_10, o_2

);

input rst, clk;
output o_100, o_50, o_10, o_2;

reg o_50, o_10, o_2;

reg [3:0] cnt_10;
reg [5:0] cnt_2;

assign o_100 = (rst) ? 0 : clk;

always @(posedge rst or posedge clk)
    if(rst) o_50 = 0;
    else    o_50 = ! o_50;
    
always @(posedge rst or posedge clk)
    if(rst) cnt_10 = 0;
    else
        if (cnt_10 >=9) cnt_10 = 0;
        else    cnt_10 = cnt_10 + 1;
        
always @(posedge rst or posedge clk)
    if (rst)    o_10 = 1'b0;
    else if (cnt_10 >=5)    o_10 = 1'b1;
    else    o_10 = 1'b0;
    
always @(posedge rst or posedge clk)
    if (rst)
        begin
            o_2 = 1'b0; cnt_2 = 0;
        end
    else
        if (cnt_2 >= 24)
            begin
                cnt_2 = 0; o_2 = ! o_2;
            end
        else
            cnt_2 = cnt_2 + 1;
            
endmodule