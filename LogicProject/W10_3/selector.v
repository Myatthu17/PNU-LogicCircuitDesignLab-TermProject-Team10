module selector (
    input RW,
    input [1:0] addr,
    output [3:0] we
);
    assign we[0] = (RW && addr == 2'b00);
    assign we[1] = (RW && addr == 2'b01);
    assign we[2] = (RW && addr == 2'b10);
    assign we[3] = (RW && addr == 2'b11);
endmodule