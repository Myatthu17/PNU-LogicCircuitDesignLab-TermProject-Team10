module button_debounce(
    input wire clk,
    input wire rst,
    input wire btn_in,
    output reg btn_out
);
    reg [15:0] cnt;
    reg btn_sync, btn_prev;

    always @(posedge clk) begin
        if(rst) begin
            cnt <= 0;
            btn_sync <= 0;
            btn_prev <= 0;
            btn_out <= 0;
        end else begin
            btn_sync <= btn_in;
            btn_prev <= btn_sync;
            if(btn_sync == btn_prev) begin
                if(cnt < 16'hFFFF) cnt <= cnt + 1;
                else btn_out <= btn_sync;
            end else cnt <= 0;
        end
    end
endmodule
