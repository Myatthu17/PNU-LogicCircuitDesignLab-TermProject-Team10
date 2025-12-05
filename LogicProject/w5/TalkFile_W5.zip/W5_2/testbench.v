`timescale 1ns/1ps

module tb_stepmotor_ctrl;

//-------------------------------------
// Signal Declarations
//-------------------------------------
reg clk;
reg rst;
reg [2:0] dip;
wire [3:0] stepmotor;
wire [1:0] state;

//-------------------------------------
// DUT Instantiation
//-------------------------------------
stepmotor_ctrl uut (
    .clk(clk),
    .rst(rst),
    .dip(dip),
    .stepmotor(stepmotor),
    .state(state)
);

//-------------------------------------
// Clock Generation (10ns period)
//-------------------------------------
always #5 clk = ~clk;  // 5ns high + 5ns low = 10ns total period

//-------------------------------------
// Test Scenario
//-------------------------------------
initial begin
    // Initialize signals
    clk = 0;
    rst = 1;
    dip = 3'b000; // start with 0 (CCW mode)

    // Hold reset
    #10 rst = 0;

    // Case 1: dip < 4 ? Left rotation (CCW)
    dip = 3'b010; // 2 (left rotation)
    #80;          // Run for several clock cycles

    // Case 2: dip >= 4 ? Right rotation (CW)
    dip = 3'b101; // 5 (right rotation)
    #80;

    // Case 3: Reset again
    rst = 1;
    #10;
    rst = 0;

    // Case 4: dip = 7 (still right rotation)
    dip = 3'b111;
    #80;

    // Finish simulation
    $finish;
end

//-------------------------------------
// Monitor outputs
//-------------------------------------
initial begin
    $monitor("Time=%0t | rst=%b | dip=%b | state=%b | stepmotor=%b",
              $time, rst, dip, state, stepmotor);
end

endmodule