module comparator_3bit_seg(
    input  [2:0] A, B,
    input        sel,
    output [2:0] O,
    output [7:0] seg_data,
    output [7:0] seg_com
);

    // Comparator output
    assign O = (A > B) ? 3'b100 :
               (A == B) ? 3'b010 :
                          3'b001;

    // 7-segment decoder function
    function [7:0] seg_decoder;
        input [2:0] val;
        case(val)
            3'd0: seg_decoder = 8'b00111111; // 0
            3'd1: seg_decoder = 8'b00000110; // 1
            3'd2: seg_decoder = 8'b01011011; // 2
            3'd3: seg_decoder = 8'b01001111; // 3
            3'd4: seg_decoder = 8'b01100110; // 4
            3'd5: seg_decoder = 8'b01101101; // 5
            3'd6: seg_decoder = 8'b01111101; // 6
            3'd7: seg_decoder = 8'b00000111; // 7
            default: seg_decoder = 8'b11111111; // Off
        endcase
    endfunction

    // Segment display
    assign seg_data = (sel == 0) ? seg_decoder(A) : seg_decoder(B);
    assign seg_com  = (sel == 0) ? 8'b01111111 : 8'b11110111;

endmodule