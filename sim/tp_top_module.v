// ---------------------------------------------------------
// Testbench
// ---------------------------------------------------------
module tb_top_module();

    reg clk;
    reg reset;
    reg  mode_switch;
    wire [7:0] lcd_out;

    top_module uut(
        .clk(clk),
        .reset(reset),
        .mode_switch(mode_switch),
        .lcd_out(lcd_out)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;  // 100MHz -> simulated clock
    end

    initial begin
        $display("Starting Testbench...");
        reset = 1;
        mode_switch = 1'b0;

        #20 reset = 0;

        // Test Calculator output
        #20 mode_switch = 1'b1;
        #20 $display("Mode: Calculator, Output: %c", lcd_out);

        // Test Puzzle Game output
        #20 mode_switch = 1'b0;
        #20 $display("Mode: Puzzle, Output: %c", lcd_out);

        #50;
        $finish;
    end

endmodule