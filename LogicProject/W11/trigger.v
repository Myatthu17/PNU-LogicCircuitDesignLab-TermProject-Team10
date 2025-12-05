module trigger(
    input clk,
    input btn,
    output reg pulse
);
    reg btn_d;

    always @(posedge clk) begin
        btn_d <= btn;
        pulse <= btn & ~btn_d;  // ???? ??
    end
endmodule