module lfsr(
    input wire clk,
    input wire rst,
    output reg [3:0] random
);
    reg [3:0] lfsr_reg;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            lfsr_reg <= 4'b1010;
            random <= 4'b1010;
        end else begin
            lfsr_reg <= {lfsr_reg[2:0], lfsr_reg[3] ^ lfsr_reg[2]};
            random <= lfsr_reg;
        end
    end
endmodule
