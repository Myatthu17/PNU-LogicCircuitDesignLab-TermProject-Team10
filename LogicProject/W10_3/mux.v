module mux (
    input [3:0] q,
    input [1:0] sel,
    output reg out
);
    always @(*) begin
        case(sel)
            2'b00: out = q[0];
            2'b01: out = q[1];
            2'b10: out = q[2];
            2'b11: out = q[3];
        endcase
    end
endmodule