module piezo(clk, rst, btn, piezo);
    input clk, rst;
    input [7:0] btn;
    output reg piezo;

    reg [15:0] cnt;
    reg [15:0] limit;

    always @(*) begin
        case (btn)
            8'b00000001: limit = 3830; // C4
            8'b00000010: limit = 3400; // D4
            8'b00000100: limit = 3030; // E4
            8'b00001000: limit = 2860; // F4
            8'b00010000: limit = 2550; // G4
            8'b00100000: limit = 2270; // A4
            8'b01000000: limit = 2020; // B4
            8'b10000000: limit = 1910; // C5
            default:     limit = 0;    // no sound
        endcase
    end

    always @(posedge clk) begin
        if (rst || limit == 0) begin
            cnt   <= 0;
            piezo <= 0;
        end else if (cnt >= (limit/2)) begin
            piezo <= ~piezo;
            cnt   <= 0;
        end else begin
            cnt <= cnt + 1;
        end
    end
endmodule
