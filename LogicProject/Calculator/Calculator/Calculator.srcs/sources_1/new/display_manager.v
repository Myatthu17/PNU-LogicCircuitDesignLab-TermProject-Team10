module display_manager (
    input CLK,
    input RESET,
    
    // Inputs from Calculator Core
    input [7:0] display_A,
    input [7:0] display_B,
    input [7:0] result_out,
    input [1:0] display_op,
    input [2:0] calc_state,

    // Outputs to Physical LCD Pins
    output LCD_RS,
    output LCD_E,
    output [3:0] LCD_DATA
);
    
    // --- State Machine Registers ---
    localparam [3:0] S_IDLE=0, S_CLEAR_INIT=1, S_CONV_START=2, S_DISP_A=3, S_DISP_OP=4, S_DISP_B=5, S_DISP_EQ=6, S_CONV_RES=7, S_DISP_RES=8;
    reg [3:0] disp_state;
    wire [3:0] next_disp_state;

    // --- BCD Wires and Control ---
    wire [3:0] bcd_A_H, bcd_A_T, bcd_A_U;
    // ... (bcd_B and bcd_R wires declared here) ...
    reg start_conv_A, start_conv_B, start_conv_R;
    wire done_A, done_B, done_R;

    // --- LCD Controller Wires/Registers ---
    reg [7:0] ascii_char;
    reg char_ready_pulse;
    reg [3:0] current_addr;
    reg [3:0] char_index = 4'd0;

    // --- 1. Instantiate BCD Converters (Use wire/reg ports) ---
    // ... (Instantiations of i_conv_A, i_conv_B, i_conv_R) ...

    // --- 2. Instantiate LCD Controller (Use wire/reg ports) ---
    // ... (Instantiation of i_lcd_ctrl) ...
    
    // --- 3. Sequential and Combinational Logic (FSM & Output Setup) ---
    // ... (FSM logic remains the same, using 'reg' for state and 'always @(*)' for next_state) ...

endmodule