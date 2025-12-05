module register_1bit (
    input clk,
    input rst,
    input we,         // write enable
    input d,          // data input
    output reg q      // stored data
);
    always @(posedge clk or posedge rst) begin
        if (rst)
            q <= 1'b0;
        else if (we)
            q <= d;
    end
endmodule