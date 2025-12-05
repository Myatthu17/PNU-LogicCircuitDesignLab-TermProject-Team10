`timescale 1us/1us
// -------------------------------------------------------------
// Fast Simulation Testbench for Traffic Light FSM
// -------------------------------------------------------------
module tb_traffic_light();

    reg clk;
    reg rst;
    reg mode;
    reg btn;
    wire [3:0] r;
    wire [3:0] g;
    wire [3:0] b;

    // Instantiate top-level module
    top DUT (
        .clk(clk),
        .rst(rst),
        .mode(mode),
        .btn(btn),
        .r(r),
        .g(g),
        .b(b)
    );

    // 1 MHz clock → still fine for simulation
    always #0.5 clk = ~clk; // 1 MHz (period = 1 µs)

    initial begin
        $display("=== FAST TRAFFIC LIGHT TEST START ===");
        clk = 0; rst = 1; mode = 0; btn = 0;

        // Reset
        #5; rst = 0;

        // --- Test 1: Automatic mode (fast 1-sec intervals = 10 cycles) ---
        $display("[AUTO MODE]");
        mode = 0;
        #200; // Wait 200 µs total (~20 "seconds")

        // --- Test 2: Manual mode ---
        $display("[MANUAL MODE]");
        mode = 1;

        // Simulate button presses
        #10; btn = 1; #1; btn = 0; // R→G
        #20; btn = 1; #1; btn = 0; // G→Y
        #20; btn = 1; #1; btn = 0; // Y→R

        // Reset test
        #10; rst = 1; #5; rst = 0;

        $display("=== TEST COMPLETE ===");
        #20;
        $stop;
    end

    // Print signal changes
    initial begin
        $monitor("[%0t us] mode=%b btn=%b rst=%b | r=%b g=%b b=%b",
                 $time, mode, btn, rst, r, g, b);
    end

endmodule