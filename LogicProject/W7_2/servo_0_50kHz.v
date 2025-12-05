module servo_5_50kHz (
    input wire clk,
    input wire resetn,
    output wire servo
);

    localparam integer FRAME_TICKS = 1000;
    localparam integer PULSE_TICKS = 34;  

    reg [9:0] cnt;

    always @(posedge clk or negedge resetn) begin
        if (resetn)
            cnt <= 10'd0;
        else if (cnt == FRAME_TICKS - 1)
            cnt <= 10'd0;
        else
            cnt <= cnt + 10'd1;
    end

    assign servo = (cnt < PULSE_TICKS);
endmodule