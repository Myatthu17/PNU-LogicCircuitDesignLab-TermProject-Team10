module led_pwm (
    input wire  clk,
    input wire  rst,
    input wire  sw,
    output wire [7:0] led
);

    reg[1:0] sw_sync;
    always @(posedge clk or posedge rst) begin
        if (rst) sw_sync <= 2'b00;
        else sw_sync <= {sw_sync[0], sw};
    end
    wire sw_rise = sw_sync[1] & ~sw_sync[0];

    reg [3:0] cnt;
    always @(posedge clk or posedge rst) begin
        if (rst) cnt <= 4'd0;
        else if (sw_rise) begin
            if (cnt >= 4'd9) cnt <= 4'd0;
            else cnt <= cnt + 1'b1;
        end
    end

    reg [3:0] cnt_disp;
    always @(posedge clk or posedge rst) begin
        if (rst) cnt_disp <= 4'd0;
        else if (cnt_disp >= 4'd9) cnt_disp <= 4'd0;
        else cnt_disp <= cnt_disp + 1'b1;
    end

    reg reg_led;
    always @(posedge clk or posedge rst) begin
        if (rst) reg_led <= 1'b0;
        else reg_led <= (cnt_disp < cnt);
    end

    assign led = {8{reg_led}};
endmodule