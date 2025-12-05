module stepper_control (
    input clk,
    input rst,
    input [2:0] dip,
    output reg [3:0] stepmotor, // Must be 'reg' as it holds state
    output reg [1:0] state       // Must be 'reg' as it holds state
);

// ----------------------------------------------
// Internal state register for the motor sequence
// We can use a 2-bit counter (0 to 3) to track the 4 steps
// ----------------------------------------------
reg [1:0] current_step; 

always @(posedge clk or posedge rst) begin
    if (rst) begin
        // Reset condition
        current_step <= 2'b00;
        stepmotor    <= 4'b0000; // Initialize stepmotor to 0
        state        <= 2'b00;   // Initialize LED state to 0
    end
    else begin
        // Clocked operation
        
        // 1. Determine next 'current_step' based on 'dip'
        if (dip >= 3'd4) begin
            // Right Rotation (Up-count the step)
            current_step <= current_step + 1;
            state        <= 2'b11; // LED ON
        end
        else begin
            // Left Rotation (Down-count the step)
            current_step <= current_step - 1;
            state        <= 2'b00; // LED OFF
        end

        // 2. Map 'current_step' to 'stepmotor' output
        // (Use a combinational block or 'case' statement outside this block 
        //  for synthesis-friendly code, but for simplicity, we keep it here)
        case (current_step)
            2'b00: stepmotor <= 4'b1010; // Step 0 (A, /A)
            2'b01: stepmotor <= 4'b0110; // Step 1 (B, /A)
            2'b10: stepmotor <= 4'b0101; // Step 2 (B, /B)
            2'b11: stepmotor <= 4'b1001; // Step 3 (A, /B)
            default: stepmotor <= 4'b1010; // Failsafe
        endcase
    end
end

endmodule