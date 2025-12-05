`timescale 1ns / 1ps

// Test bench module declaration
module testbench;

// 1. Declarations for DUT Ports
reg clk;
reg rst;
reg [2:0] dip;
wire [3:0] stepmotor;
wire [1:0] state;

// Clock period definition (e.g., 50 MHz clock)
parameter CLK_PERIOD = 20; 

// 2. Instantiate the DUT (Device Under Test)
// The DUT should be the 'stepper_control' module you wrote based on Lab 2 requirements.
stepper_control DUT (
    .clk(clk),
    .rst(rst),
    .dip(dip),
    .stepmotor(stepmotor),
    .state(state)
);

// 3. Clock Generation
initial begin
    clk = 1'b0; // Initialize clock to 0
    // Generate a continuous clock signal (toggle every 10 ns)
    forever #(CLK_PERIOD / 2) clk = ~clk; 
end

// 4. Stimulus Generation
initial begin
    // Initialize inputs
    rst = 1'b1;  // Start with Reset active
    dip = 3'b000;
    
    // ----------------------------------------------------
    // Phase 1: Reset and Initialization
    // ----------------------------------------------------
    $display("T=%0t: Initializing, applying reset (rst=1)", $time);
    #50; // Hold reset for a short time
    
    // Release reset (rst=0) to begin clocked operation
    rst = 1'b0; 
    
    // ----------------------------------------------------
    // Phase 2: Right Rotation Test (dip >= 4)
    // Motor sequence should be 1010 -> 0110 -> 0101 -> 1001 -> 1010...
    // LED (state) should be 11
    // ----------------------------------------------------
    #10; // Wait for the clock edge to pass
    dip = 3'd5; // Set DIP input to 5 (5 >= 4, Right Rotation)
    $display("T=%0t: Starting RIGHT rotation (dip=5). Expected state=11.", $time);
    
    // Run for 10 clock cycles (200 ns total) to complete 2.5 cycles of the motor sequence
    #200; 

    // ----------------------------------------------------
    // Phase 3: Left Rotation Test (dip < 4)
    // Motor sequence should be 1010 -> 1001 -> 0101 -> 0110 -> 1010...
    // LED (state) should be 00
    // ----------------------------------------------------
    dip = 3'd2; // Set DIP input to 2 (2 < 4, Left Rotation)
    $display("T=%0t: Starting LEFT rotation (dip=2). Expected state=00.", $time);
    
    // Run for another 10 clock cycles
    #200; 
    
    // ----------------------------------------------------
    // Phase 4: Re-apply Reset
    // ----------------------------------------------------
    rst = 1'b1;
    $display("T=%0t: Re-applying reset (rst=1).", $time);
    #50; 
    
    // End simulation
    $display("T=%0t: Simulation finished.", $time);
    $stop; 
end

endmodule
