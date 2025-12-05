`timescale 1us / 1us   // 1µs resolution for simulation clarity

module tb_servo_ctrl;

    // DUT signals
    reg clk;
    reg rst;
    reg l_ctrl;
    reg r_ctrl;
    wire servo;

    // Instantiate DUT
    servo_ctrl uut (
        .clk(clk),
        .rst(rst),
        .l_ctrl(l_ctrl),
        .r_ctrl(r_ctrl),
        .servo(servo)
    );

    // 10kHz clock generation: period = 100us
    initial begin
        clk = 0;
        forever #50 clk = ~clk;  // 50us high + 50us low = 100us period
    end

    // Stimulus
    initial begin
        // Initialize
        rst = 1;
        l_ctrl = 0;
        r_ctrl = 0;
        #500;  // hold reset for 500us
        rst = 0;

        // Move to LEFT (0°)
        l_ctrl = 1;
        #100000; // wait 100ms (5 servo cycles)
        l_ctrl = 0;

        // Move to CENTER (90°)
        #100000;

        // Move to RIGHT (180°)
        r_ctrl = 1;
        #100000;
        r_ctrl = 0;

        // Both pressed (right has priority)
        l_ctrl = 1;
        r_ctrl = 1;
        #100000;

        // Return to center
        l_ctrl = 0;
        r_ctrl = 0;
        #100000;

        $stop; // end simulation
    end

endmodule