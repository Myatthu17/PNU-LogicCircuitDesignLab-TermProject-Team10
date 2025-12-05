`timescale 1ns / 1ps

module tb_3;

    // Inputs
    reg clk;
    reg rst;
    reg [7:0] btn;

    // Output
    wire piezo;

    // Instantiate the Unit Under Test (UUT)
    piezo uut (
        .clk(clk),
        .rst(rst),
        .btn(btn),
        .piezo(piezo)
    );

    // Clock generation: 50 MHz clock (~20 ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk; // toggle every 10 ns
    end

    // Test sequence
    initial begin
        // Initialize inputs
        rst = 1;
        btn = 8'b00000000;

        // Wait 100 ns for global reset
        #100;
        rst = 0;

        // Press each button for 1 ms (simulation time)
        btn = 8'b00000001; #1000_000; // C4
        btn = 8'b00000010; #1000_000; // D4
        btn = 8'b00000100; #1000_000; // E4
        btn = 8'b00001000; #1000_000; // F4
        btn = 8'b00010000; #1000_000; // G4
        btn = 8'b00100000; #1000_000; // A4
        btn = 8'b01000000; #1000_000; // B4
        btn = 8'b10000000; #1000_000; // C5

        // Release all buttons
        btn = 8'b00000000;
        #1000_000;

        // Finish simulation
        $stop;
    end

endmodule
