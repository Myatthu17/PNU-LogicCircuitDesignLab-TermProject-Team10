module calculator_core (
    input CLK,
    input RESET,
    input [3:0] digit_input,
    input digit_valid,
    input [1:0] op_sel,
    input btn_confirm,
    input btn_clear,
    input btn_backspace,

    output [7:0] result_out,
    output [7:0] display_A,
    output [7:0] display_B,
    output [1:0] display_op,
    output [2:0] calc_state
);

    // --- State Machine Definition (Using localparam for states) ---
    localparam [2:0] 
        S_START = 3'd0, S_INPUT_A = 3'd1, S_WAIT_OP = 3'd2, 
        S_INPUT_B = 3'd3, S_CALCULATE = 3'd4, S_DISPLAY_RES = 3'd5;

    // State registers must be 'reg'
    reg [2:0] state;
    reg [2:0] next_state; // Combinational wire driven by always @(*)

    // Data Registers must be 'reg'
    reg [7:0] operand_A = 8'd0;
    reg [7:0] operand_B = 8'd0;
    reg [1:0] current_op = 2'b00;

    // Output registers must be 'reg'
    reg [7:0] result_out_reg;
    reg [7:0] display_A_reg, display_B_reg;
    reg [1:0] display_op_reg;
    reg [2:0] calc_state_reg;

    assign result_out = result_out_reg;
    assign display_A = display_A_reg;
    assign display_B = display_B_reg;
    assign display_op = display_op_reg;
    assign calc_state = calc_state_reg;
    
    // --- State Transition Logic (Sequential Block) ---
    always @(posedge CLK or posedge RESET) begin
        if (RESET || btn_clear) begin
            state <= S_START;
            operand_A <= 8'd0; operand_B <= 8'd0;
            current_op <= 2'b00;
            result_out_reg <= 8'd0;
        end else begin
            state <= next_state;
            calc_state_reg <= next_state;

            // Handle Backspace and Digit Input logic (omitted for brevity, assume 'reg's are used)
            // ...
        end
    end

    // --- Next State Logic and Calculation (Combinational Block) ---
    always @(*) begin
        next_state = state;
        display_A_reg = operand_A;
        // ... (Combinational assignments for next_state and outputs based on 'state') ...
    end
endmodule
