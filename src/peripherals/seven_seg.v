module seven_seg(
    input [3:0] number,  // 0-9
    output reg [6:0] seg // {a,b,c,d,e,f,g}
);

    always @(*) begin
        case(number)
            4'd0: seg = 7'b1111110;
            4'd1: seg = 7'b0110000;
            4'd2: seg = 7'b1101101;
            4'd3: seg = 7'b1111001;
            4'd4: seg = 7'b0110011;
            4'd5: seg = 7'b1011011;
            4'd6: seg = 7'b1011111;
            4'd7: seg = 7'b1110000;
            4'd8: seg = 7'b1111111;
            4'd9: seg = 7'b1111011;
            default: seg = 7'b0000000; // off
        endcase
    end

endmodule
