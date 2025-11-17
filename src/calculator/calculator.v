// ---------------------------------------------------------
// Dummy calculator module (prints its name)
// ---------------------------------------------------------
module calculator(
    input clk,
    input reset,
    output reg [7:0] out
);
    always @(posedge clk or posedge reset) begin
        if(reset)
            out <= "C";  // ASCII C
        else
            out <= "C";
    end
endmodule