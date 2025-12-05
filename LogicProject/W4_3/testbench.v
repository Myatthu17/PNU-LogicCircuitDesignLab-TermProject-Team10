`timescale 10ns / 100ps

module testbench();

    // Inputs
    reg [2:0] A;
    reg [2:0] B;
    reg sel;

    // Outputs
    wire [2:0] O;
    wire [7:0] seg_data;
    wire [7:0] seg_com;

    // Instantiate the DUT
    comparator_3bit_seg uut (
        .A(A),
        .B(B),
        .sel(sel),
        .O(O),
        .seg_data(seg_data),
        .seg_com(seg_com)
    );

    // Stimulus
    initial begin
        // Test 1: A > B
        A = 3'd5; B = 3'd2; sel = 0; #10;
        A = 3'd5; B = 3'd2; sel = 1; #10;

        // Test 2: A = B
        A = 3'd3; B = 3'd3; sel = 0; #10;
        A = 3'd3; B = 3'd3; sel = 1; #10;

        // Test 3: A < B
        A = 3'd1; B = 3'd6; sel = 0; #10;
        A = 3'd1; B = 3'd6; sel = 1; #10;

        // Test 4: Random values
        A = 3'd7; B = 3'd0; sel = 0; #10;
        A = 3'd7; B = 3'd0; sel = 1; #10;

        $finish;
    end

    // Optional: monitor outputs
    initial begin
        $monitor("Time=%0t | sel=%b | A=%d B=%d | O=%b | seg_data=%b seg_com=%b",
                  $time, sel, A, B, O, seg_data, seg_com);
    end

endmodule