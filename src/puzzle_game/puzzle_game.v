// ---------------------------------------------------------
// Dummy puzzle game module (prints its name)
// ---------------------------------------------------------
module puzzle_game(
    input clk,
    input reset,
    output reg [7:0] out
);
    always @(posedge clk or posedge reset) begin
        if(reset)
            out <= "P";  // ASCII P
        else
            out <= "P";
    end
endmodule