module keypad_decoder(
    input clk,
    input rst,
    input btn0, btn1, btn2, btn3, btn4,
    input btn5, btn6, btn7, btn8, btn9,
    output reg [3:0] number,   // 0~9
    output reg valid            // high if any button is pressed
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            number <= 4'd0;
            valid <= 0;
        end else begin
            valid <= 0;
            number <= 4'd0;
            if (btn0) begin number <= 4'd0; valid <= 1; end
            else if (btn1) begin number <= 4'd1; valid <= 1; end
            else if (btn2) begin number <= 4'd2; valid <= 1; end
            else if (btn3) begin number <= 4'd3; valid <= 1; end
            else if (btn4) begin number <= 4'd4; valid <= 1; end
            else if (btn5) begin number <= 4'd5; valid <= 1; end
            else if (btn6) begin number <= 4'd6; valid <= 1; end
            else if (btn7) begin number <= 4'd7; valid <= 1; end
            else if (btn8) begin number <= 4'd8; valid <= 1; end
            else if (btn9) begin number <= 4'd9; valid <= 1; end
        end
    end

endmodule
