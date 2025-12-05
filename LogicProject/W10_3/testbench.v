`timescale 1ns/1ps

module testbench;
    // Testbench signals
    reg clk;
    reg rst;
    reg DataIn;
    reg RW;
    reg [1:0] Address;
    wire [3:0] Q;
    wire DataOut;

    // Instantiate the SRAM module
    sram uut (
        .clk(clk),
        .rst(rst),
        .DataIn(DataIn),
        .RW(RW),
        .Address(Address),
        .Q(Q),
        .DataOut(DataOut)
    );

    // Clock generation (period = 10 ns)
    always #5 clk = ~clk;

    initial begin
        // Initialize signals
        clk = 0;
        rst = 1;
        DataIn = 0;
        RW = 0;
        Address = 2'b00;

        // Apply reset
        #10;
        rst = 0;
        $display("=== Starting SRAM Test ===");

        // ---- Write phase ----
        RW = 1;  // write mode

        // Write 1 to register 0
        Address = 2'b00; DataIn = 1; #10;
        // Write 0 to register 1
        Address = 2'b01; DataIn = 0; #10;
        // Write 1 to register 2
        Address = 2'b10; DataIn = 1; #10;
        // Write 0 to register 3
        Address = 2'b11; DataIn = 0; #10;

        // ---- Read phase ----
        RW = 0;  // read mode

        Address = 2'b00; #10;
        $display("Read from reg0: %b (DataOut=%b, Q=%b)", Address, DataOut, Q);
        Address = 2'b01; #10;
        $display("Read from reg1: %b (DataOut=%b, Q=%b)", Address, DataOut, Q);
        Address = 2'b10; #10;
        $display("Read from reg2: %b (DataOut=%b, Q=%b)", Address, DataOut, Q);
        Address = 2'b11; #10;
        $display("Read from reg3: %b (DataOut=%b, Q=%b)", Address, DataOut, Q);

        // ---- Reset again ----
        rst = 1; #10; rst = 0; #10;
        $display("After reset: Q = %b, DataOut = %b", Q, DataOut);

        $display("=== SRAM Test Finished ===");
        $stop;
    end
endmodule