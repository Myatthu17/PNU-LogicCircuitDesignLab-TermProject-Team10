module calculator_top (
    // System Inputs
    input  CLK,
    input  RESET,
    
    // Dip Switches (Only 4 relevant for Calculator Mode)
    input  [3:0] DIP_SW_OP,  // [3:2] = Mode (00 for Calc), [1:0] = Operation (+,-,*,/)
    
    // Raw Button Inputs (Active Low assumed for physical board)
    input  [11:0] BTN_RAW,   // [0]=Confirm, [1..10]=0-9, [11]=Clear/Backspace
    
    // Outputs to Physical LCD Pins
    output LCD_RS,
    output LCD_E,
    output [3:0] LCD_DATA,
    
    // LED Outputs for Operation Indicator
    output reg [3:0] LED_OP,   // LED[0]=+, LED[1]=-, LED[2]=*, LED[3]=/
    
    // 7-Segment Display Outputs
    output reg [6:0] SEG       // a-g segments
);

    // --- Internal Wires/Logic Declarations ---
    // Signals from button_manager
    wire [3:0] digit_in;
    wire digit_valid;
    wire btn_confirm_vld;
    wire btn_clear_vld;
    wire btn_backspace_vld;
    
    // Signals from calculator_core
    wire [7:0] display_A; 
    wire [7:0] display_B; 
    wire [7:0] result_out;
    wire [1:0] display_op;
    wire [2:0] calc_state; // FSM state for the Display Manager

    // Wires from display_manager to connect to final outputs
    wire lcd_rs_w;
    wire lcd_e_w;
    wire [3:0] lcd_data_w;

    // --- 1. Button Manager (Debounce + Decode) ---
    button_manager i_btn_manager (
        .CLK(CLK),
        .RESET(RESET),
        .BTN_RAW_DIGITS(BTN_RAW[10:1]),   
        .BTN_RAW_CONFIRM(BTN_RAW[0]),
        .BTN_RAW_MISC(BTN_RAW[11]),
        .digit_input(digit_in),
        .digit_valid(digit_valid),
        .btn_confirm_vld(btn_confirm_vld),
        .btn_clear_vld(btn_clear_vld),
        .btn_backspace_vld(btn_backspace_vld)
    );

    // --- 2. Calculator Core (FSM + ALU) ---
    calculator_core i_calc_core (
        .CLK(CLK),
        .RESET(RESET),
        .digit_input(digit_in),
        .digit_valid(digit_valid),
        .op_sel(DIP_SW_OP[1:0]),
        .btn_confirm(btn_confirm_vld),
        .btn_clear(btn_clear_vld),
        .btn_backspace(btn_backspace_vld),
        .result_out(result_out),
        .display_A(display_A),
        .display_B(display_B),
        .display_op(display_op),
        .calc_state(calc_state)
    );

    // --- 3. Display Manager (LCD Driver) ---
    display_manager i_disp_manager (
        .CLK(CLK),
        .RESET(RESET),
        .display_A(display_A),
        .display_B(display_B),
        .result_out(result_out),
        .display_op(display_op),
        .calc_state(calc_state),
        .LCD_RS(lcd_rs_w),
        .LCD_E(lcd_e_w),
        .LCD_DATA(lcd_data_w)
    );
    
    // --- 4. Physical Output Connections ---
    assign LCD_RS   = lcd_rs_w;
    assign LCD_E    = lcd_e_w;
    assign LCD_DATA = lcd_data_w;

    // --- 5. LED Operation Indicator ---
    always @(*) begin
        case(DIP_SW_OP[1:0])
            2'b00: LED_OP = 4'b0001; // LED1 ON for '+'
            2'b01: LED_OP = 4'b0010; // LED2 ON for '-'
            2'b10: LED_OP = 4'b0100; // LED3 ON for '*'
            2'b11: LED_OP = 4'b1000; // LED4 ON for '/'
            default: LED_OP = 4'b0000; // All OFF
        endcase
    end

    // --- 6. 7-Segment Display Decoder (single-digit, no AN) ---
    always @(*) begin
        case(digit_in)
            4'd0: SEG = 7'b1000000;
            4'd1: SEG = 7'b1111001;
            4'd2: SEG = 7'b0100100;
            4'd3: SEG = 7'b0110000;
            4'd4: SEG = 7'b0011001;
            4'd5: SEG = 7'b0010010;
            4'd6: SEG = 7'b0000010;
            4'd7: SEG = 7'b1111000;
            4'd8: SEG = 7'b0000000;
            4'd9: SEG = 7'b0010000;
            default: SEG = 7'b1111111; // blank
        endcase
    end

endmodule
