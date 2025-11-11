module lcd_controller(
    input wire clk,
    input wire rst,
    input wire [7:0] data_in,
    input wire start,
    output reg LCD_RS,
    output reg LCD_E,
    output reg [7:0] LCD_DB
);
    reg [19:0] cnt;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            LCD_RS <= 0;
            LCD_E <= 0;
            LCD_DB <= 0;
            cnt <= 0;
        end else begin
            cnt <= cnt + 1;
            if(cnt == 50000) begin
                cnt <= 0;
                LCD_E <= ~LCD_E;
            end
            if(start) begin
                LCD_RS <= 1;
                LCD_DB <= data_in;
            end else LCD_RS <= 0;
        end
    end
endmodule
