module calculator(
    input  wire        rst,
    input  wire        clk,
    input  wire [11:0] keypad_buttons,  // Digits 0-9, '=' on bit10, Backspace on bit11
    input  wire        dip_switch1,     // '+' DIP
    input  wire        dip_switch2,     // '-' DIP
    input  wire        dip_switch3,     // '*' DIP
    input  wire        dip_switch4,     // '/' DIP
    output wire        lcd_e,
    output reg         lcd_rs,
    output reg         lcd_rw,
    output reg [7:0]   lcd_data,
    output reg [6:0]   seven_seg,
    output reg         seven_seg_dp,
    output reg         led_plus,
    output reg         led_minus,
    output reg         led_mul,
    output reg         led_div,
    output wire        piezo
);

//////////////////////////
// Clock Divider ~100Hz //
//////////////////////////
reg [15:0] cnt_100hz = 0;
reg clk_100hz = 0;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        cnt_100hz <= 0;
        clk_100hz <= 0;
    end else begin
        if (cnt_100hz == 49999) begin   // (50 MHz / 100 Hz / 2) - 1
            cnt_100hz <= 0;
            clk_100hz <= ~clk_100hz;
        end else
            cnt_100hz <= cnt_100hz + 1;
    end
end

assign lcd_e = clk_100hz;   // LCD Enable

//////////////////////////
// Button Debouncing    //
//////////////////////////
reg [11:0] button_prev = 0;
reg [11:0] button_sync = 0;
reg       button_pressed = 0;
reg [3:0] button_digit = 0;
reg [7:0] char_to_write = "0";
reg [3:0] dip_prev = 0;
reg [3:0] op_present = 0;
reg [5:0] entry_count = 0;
reg       backspace_request = 0;
reg       backspace_in_progress = 0;
reg       backspace_line = 0;
reg [3:0] backspace_pos = 0;
reg       op_clear_request = 0;
reg [3:0] seven_seg_digit = 0;
reg       seven_seg_valid = 0;
reg       awaiting_new_entry = 0;
reg       clear_display_request = 0;
reg       clear_in_progress = 0;
reg       queued_char_pending = 0;
reg [7:0] queued_char_data = 0;
reg [3:0] queued_digit_data = 0;
reg       queued_entry_increment = 0;
reg       manual_button_press = 0;

localparam [6:0] SEG_BLANK = 7'b0000000;

function [6:0] seven_seg_decode;
    input [3:0] value;
    begin
        case (value)
            4'd0: seven_seg_decode = 7'b0111111;
            4'd1: seven_seg_decode = 7'b0000110;
            4'd2: seven_seg_decode = 7'b1011011;
            4'd3: seven_seg_decode = 7'b1001111;
            4'd4: seven_seg_decode = 7'b1100110;
            4'd5: seven_seg_decode = 7'b1101101;
            4'd6: seven_seg_decode = 7'b1111101;
            4'd7: seven_seg_decode = 7'b0000111;
            4'd8: seven_seg_decode = 7'b1111111;
            4'd9: seven_seg_decode = 7'b1101111;
            default: seven_seg_decode = SEG_BLANK;
        endcase
    end
endfunction


// Simple calculator state
reg [15:0] operand1      = 0;
reg [15:0] operand2      = 0;
reg        have_operator = 0;
reg [1:0]  op_code       = 0;  // 0:+, 1:-, 2:*, 3:/
reg        result_mode   = 0;  // when 1, automatically write result digits on line 2
reg [2:0]  result_index  = 0;
reg [2:0]  result_length = 0;
reg [15:0] result_value  = 0;
reg        result_start  = 0;  // request to move cursor to start of line 2 before writing result
reg [15:0] computed_result = 0; // temporary for '=' evaluation to avoid nonblocking read race
reg        result_is_error = 0;
reg [2:0]  result_int_digits = 0;
reg        result_has_decimal = 0;
reg [3:0]  result_decimal_digit = 0;
reg [15:0] thousands     = 0;
reg [15:0] hundreds      = 0;
reg [15:0] tens          = 0;
reg [15:0] ones          = 0;

wire [11:0] button_edge = button_sync & ~button_prev;  // Rising edges per button
wire [9:0] digit_edges = button_edge[9:0];
wire       digit_press_any = |digit_edges;
wire       equals_edge = button_edge[10];
wire       backspace_edge = button_edge[11];
wire [3:0] dip_state = {dip_switch4, dip_switch3, dip_switch2, dip_switch1};
wire [3:0] dip_edge = dip_state & ~dip_prev;
wire [3:0] dip_add_request = dip_edge & ~op_present;
wire       dip_request_any = |dip_add_request;
wire       ready_for_input = ~(result_mode | clear_in_progress | clear_display_request);

integer i;
integer digit_count;
integer remainder_temp;
integer decimal_calc;
integer has_decimal_flag;
integer decimal_digit_store;

//=========================
// Buzzer control with keypad beep (50MHz)
//=========================
localparam BUZZ_IDLE      = 3'd0;
localparam BUZZ_KEYPAD    = 3'd1;

reg  [2:0]  buzz_mode;
reg  [24:0] buzz_cnt;      // divider counter
reg  [24:0] total_timer;   // duration for keypad beep
reg  [15:0] cur_div;       // current frequency divider
reg         piezo_reg;
reg  [3:0]  pressed_digit; // digit that was pressed (0-9)

// Note "frequencies" (different divisors -> different pitches)
localparam [15:0] NOTE_DO   = 16'd25_000;
localparam [15:0] NOTE_RE   = 16'd22_000;
localparam [15:0] NOTE_MI   = 16'd20_000;
localparam [15:0] NOTE_FA   = 16'd18_000;
localparam [15:0] NOTE_SO   = 16'd16_000;
localparam [15:0] NOTE_LA   = 16'd14_000;
localparam [15:0] NOTE_TI   = 16'd12_000;
localparam [15:0] NOTE_DO2  = 16'd10_000;

// Short keypad click (~0.1s at 50 MHz)
localparam [24:0] KEYPAD_DUR = 25'd5_000_000;

// Map keypad key index to a note frequency
function [15:0] key_divisor;
    input [3:0] key;
    begin
        case (key)
            4'd0:  key_divisor = NOTE_DO2; // "0"
            4'd1:  key_divisor = NOTE_DO;  // "1"
            4'd2:  key_divisor = NOTE_RE;  // "2"
            4'd3:  key_divisor = NOTE_MI;  // "3"
            4'd4:  key_divisor = NOTE_FA;  // "4"
            4'd5:  key_divisor = NOTE_SO;  // "5"
            4'd6:  key_divisor = NOTE_LA;  // "6"
            4'd7:  key_divisor = NOTE_TI;  // "7"
            4'd8:  key_divisor = NOTE_DO2; // "8"
            4'd9:  key_divisor = NOTE_RE;  // "9"
            default: key_divisor = NOTE_SO;
        endcase
    end
endfunction

// Detect which digit was pressed (in clk domain for piezo)
reg [11:0] keypad_prev;
reg [11:0] keypad_sync;
reg [3:0]  detected_digit;
reg        digit_pressed_valid;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        keypad_sync <= 12'd0;
        keypad_prev <= 12'd0;
        detected_digit <= 4'd0;
        digit_pressed_valid <= 1'b0;
    end else begin
        keypad_sync <= keypad_buttons;
        keypad_prev <= keypad_sync;
        digit_pressed_valid <= 1'b0;
        
        // Detect rising edge on any digit button (0-9)
        for (i = 0; i < 10; i = i + 1) begin
            if (keypad_sync[i] && !keypad_prev[i]) begin
                detected_digit <= i[3:0];
                digit_pressed_valid <= 1'b1;
            end
        end
    end
end

// Piezo buzzer control
always @(posedge clk or posedge rst) begin
    if (rst) begin
        buzz_mode   <= BUZZ_IDLE;
        buzz_cnt    <= 25'd0;
        total_timer <= 25'd0;
        cur_div     <= NOTE_DO;
        piezo_reg   <= 1'b0;
        pressed_digit <= 4'd0;
    end else begin
        // Keypad sound trigger (only when not playing another sound)
        if (buzz_mode == BUZZ_IDLE && digit_pressed_valid) begin
            buzz_mode   <= BUZZ_KEYPAD;
            buzz_cnt    <= 25'd0;
            total_timer <= KEYPAD_DUR;
            pressed_digit <= detected_digit;
            cur_div     <= key_divisor(detected_digit);
            piezo_reg   <= 1'b0;
        end

        // Sound generation
        case (buzz_mode)
            BUZZ_IDLE: begin
                piezo_reg <= 1'b0;
            end

            BUZZ_KEYPAD: begin
                if (total_timer == 0) begin
                    buzz_mode <= BUZZ_IDLE;
                    piezo_reg <= 1'b0;
                end else begin
                    total_timer <= total_timer - 1'b1;

                    buzz_cnt <= buzz_cnt + 1'b1;
                    if (buzz_cnt >= cur_div) begin
                        buzz_cnt  <= 25'd0;
                        piezo_reg <= ~piezo_reg;
                    end
                end
            end

            default: begin
                buzz_mode <= BUZZ_IDLE;
                piezo_reg <= 1'b0;
            end
        endcase
    end
end

assign piezo = piezo_reg;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        seven_seg    <= SEG_BLANK;
        seven_seg_dp <= 1'b0;
    end else begin
        if (seven_seg_valid) begin
            seven_seg <= seven_seg_decode(seven_seg_digit);
        end else begin
            seven_seg <= SEG_BLANK;
        end
        seven_seg_dp <= 1'b0;  // decimal point stays off
    end
end

always @(posedge clk_100hz or posedge rst) begin
    if (rst) begin
        button_sync    <= 0;
        button_prev    <= 0;
        button_pressed <= 0;
        button_digit   <= 0;
        char_to_write  <= "0";
        seven_seg_digit <= 0;
        seven_seg_valid <= 0;
        operand1       <= 0;
        operand2       <= 0;
        have_operator  <= 0;
        op_code        <= 0;
        result_mode    <= 0;
        result_index   <= 0;
        result_length  <= 0;
        result_value   <= 0;
        result_start   <= 0;
        entry_count    <= 0;
        backspace_request <= 0;
        backspace_in_progress <= 0;
        backspace_line <= 0;
        backspace_pos  <= 0;
        op_clear_request <= 0;
        awaiting_new_entry <= 0;
        clear_display_request <= 0;
        clear_in_progress <= 0;
        queued_char_pending <= 0;
        queued_char_data <= 0;
        queued_digit_data <= 0;
        queued_entry_increment <= 0;
        manual_button_press <= 0;
    end else begin
        button_sync <= keypad_buttons;
        button_prev <= button_sync;
        dip_prev    <= dip_state;

        // Button press occurs on digit keypad edges or DIP add requests.
        // Ignore user input while a result is streaming.
        if (manual_button_press) begin
            button_pressed <= 1'b1;
            manual_button_press <= 0;
        end else begin
            button_pressed <= ready_for_input & ((digit_press_any & ~awaiting_new_entry) | dip_request_any);
        end

        if (backspace_in_progress && state == S_WRITE_CHAR && write_char_done) begin
            backspace_in_progress <= 0;
            backspace_request    <= 0;
            op_clear_request     <= 0;
        end

        // Result display sequencing
        if (result_mode && state == S_WRITE_CHAR && write_char_done) begin
                // Move to next digit of the computed result (or next error char)
                if (result_index + 1 < result_length) begin
                    // Prepare next character based on the display length and current index
                    // Use (result_index + 1) which is evaluated from the OLD result_index
                    // (nonblocking increment happens after the clock edge)
                    if (result_is_error) begin
                        // Sequence for "Err": index0='E' already written, then 'r','r'
                        case (result_index + 1)
                            3'd1: char_to_write <= "r";
                            3'd2: char_to_write <= "r";
                            default: char_to_write <= 8'h20;
                        endcase
                    end else begin
                        if (result_index + 1 < result_int_digits) begin
                            case (result_int_digits)
                                3'd4: begin
                                    case (result_index + 1)
                                        3'd1: char_to_write <= hundreds[3:0] + 8'h30;
                                        3'd2: char_to_write <= tens[3:0]     + 8'h30;
                                        3'd3: char_to_write <= ones[3:0]     + 8'h30;
                                        default: char_to_write <= 8'h20;
                                    endcase
                                end
                                3'd3: begin
                                    case (result_index + 1)
                                        3'd1: char_to_write <= tens[3:0]     + 8'h30;
                                        3'd2: char_to_write <= ones[3:0]     + 8'h30;
                                        default: char_to_write <= 8'h20;
                                    endcase
                                end
                                3'd2: begin
                                    case (result_index + 1)
                                        3'd1: char_to_write <= ones[3:0]     + 8'h30;
                                        default: char_to_write <= 8'h20;
                                    endcase
                                end
                                3'd1: begin
                                    char_to_write <= 8'h20;
                                end
                                default: char_to_write <= 8'h20;
                            endcase
                        end else if (result_has_decimal) begin
                            if (result_index + 1 == result_int_digits) begin
                                char_to_write <= 8'h2E; // '.'
                            end else if (result_index + 1 == (result_int_digits + 1)) begin
                                char_to_write <= result_decimal_digit[3:0] + 8'h30;
                            end else begin
                                char_to_write <= 8'h20;
                            end
                        end else begin
                            char_to_write <= 8'h20;
                        end
                    end

                    result_index <= result_index + 1;
                end else begin
                    // Finished writing result (or Err sequence)
                    result_mode   <= 0;
                    result_index  <= 0;
                    result_length <= 0;
                    result_is_error <= 0;
                    result_start  <= 0;  // Clear cursor-move flag after sequence done
                    // Clear calculator state so the next expression can be entered
                    operand1      <= 0;
                    operand2      <= 0;
                    have_operator <= 0;
                    op_code       <= 0;
                    awaiting_new_entry <= 1;
                    entry_count   <= 0;
                    seven_seg_valid <= 0;
                    result_int_digits <= 0;
                    result_has_decimal <= 0;
                    result_decimal_digit <= 0;
                end

        end else if (!result_mode) begin
            // Normal digit / operator / '=' handling

            // Handle digit keypresses (0-9). Bit 10 is reserved for '='.
            if (digit_press_any && ready_for_input) begin
                for (i = 0; i < 10; i = i + 1) begin
                    if (digit_edges[i]) begin
                        seven_seg_digit <= i[3:0];
                        seven_seg_valid <= 1;

                        if (awaiting_new_entry) begin
                            if (!clear_display_request && !clear_in_progress) begin
                                clear_display_request <= 1;
                                clear_in_progress <= 1;
                            end
                            queued_char_data    <= 8'h30 + i[3:0];
                            queued_digit_data   <= i[3:0];
                            queued_char_pending <= 1;
                            queued_entry_increment <= 1;
                            awaiting_new_entry  <= 0;
                        end else begin
                            button_digit  <= i[3:0];
                            char_to_write <= 8'h30 + i[3:0];  // ASCII '0' + digit
                            entry_count   <= entry_count + 1;
                        end

                        if (!have_operator) begin
                            operand1 <= (operand1 * 10) + i[3:0];
                        end else begin
                            operand2 <= (operand2 * 10) + i[3:0];
                        end
                    end
                end

            end else if (dip_request_any && ready_for_input) begin
                // Operator from DIP switches (only if one is not yet present)
                casex (dip_add_request)
                    4'bxxx1: begin
                        char_to_write <= 8'h2B;  // '+'
                        op_code       <= 2'd0;
                    end
                    4'bxx10: begin
                        char_to_write <= 8'h2D;  // '-'
                        op_code       <= 2'd1;
                    end
                    4'bx100: begin
                        char_to_write <= 8'h2A;  // '*'
                        op_code       <= 2'd2;
                    end
                    4'b1000: begin
                        char_to_write <= 8'h2F;  // '/'
                        op_code       <= 2'd3;
                    end
                    default: begin
                        char_to_write <= char_to_write;
                    end
                endcase
                // Mark that an operator is now present
                have_operator <= 1;
                entry_count   <= entry_count + 1;

            end else if (equals_edge) begin
                // '=' pressed: evaluate expression into a temporary `computed_result`
                // Use a blocking temporary so we can inspect and derive digits
                // in the same cycle without relying on nonblocking update timing.

                if (!have_operator) begin
                    computed_result = operand1;
                end else begin
                    case (op_code)
                        2'd0: computed_result = operand1 + operand2;                     // +
                        2'd1: computed_result = (operand1 >= operand2) ?                  // -
                                          (operand1 - operand2) : 16'hFFFF;
                        2'd2: computed_result = operand1 * operand2;                      // *
                        2'd3: computed_result = (operand2 != 0) ? (operand1 / operand2)   // /
                                                         : 16'hFFFF;
                        default: computed_result = 16'hFFFF;
                    endcase
                end

                // Commit computed result to state (nonblocking) for later use
                result_value <= computed_result;

                // Check for error sentinel 0xFFFF using the computed value
                if (computed_result == 16'hFFFF) begin
                    // Show "Err" on line 2
                    result_mode   <= 1;
                    result_length <= 3;
                    result_index  <= 0;
                    result_is_error <= 1;
                    result_int_digits <= 0;
                    result_has_decimal <= 0;
                    result_decimal_digit <= 0;
                    char_to_write <= "E";
                    result_start  <= 1;
                end else begin
                    // Prepare decimal digits (0 to 9999) from computed_result
                    thousands = computed_result / 1000;
                    hundreds  = (computed_result % 1000) / 100;
                    tens      = (computed_result % 100) / 10;
                    ones      = computed_result % 10;

                    // Decide how many integer digits to show (no leading zeros)
                    if (computed_result >= 1000) begin
                        digit_count = 4;
                        char_to_write <= thousands[3:0] + 8'h30;
                    end else if (computed_result >= 100) begin
                        digit_count = 3;
                        char_to_write <= hundreds[3:0] + 8'h30;
                    end else if (computed_result >= 10) begin
                        digit_count = 2;
                        char_to_write <= tens[3:0] + 8'h30;
                    end else begin
                        digit_count = 1;
                        char_to_write <= ones[3:0] + 8'h30;
                    end

                    // Determine if a fractional digit should be displayed for division
                    remainder_temp = 0;
                    decimal_calc = 0;
                    has_decimal_flag = 0;
                    decimal_digit_store = 0;
                    if (op_code == 2'd3 && operand2 != 0) begin
                        remainder_temp = operand1 % operand2;
                        if (remainder_temp != 0) begin
                            decimal_calc = (remainder_temp * 10) / operand2;
                            if (decimal_calc > 9) begin
                                decimal_calc = 9;
                            end
                            has_decimal_flag = 1;
                            decimal_digit_store = decimal_calc;
                        end
                    end

                    result_int_digits <= digit_count[2:0];
                    result_has_decimal <= has_decimal_flag ? 1'b1 : 1'b0;
                    result_decimal_digit <= decimal_digit_store[3:0];
                    result_length <= digit_count[2:0] + (has_decimal_flag ? 3'd2 : 3'd0);
                    result_index  <= 0;

                    result_is_error <= 0;
                    result_mode  <= 1;
                    result_start <= 1;
                end
            end else if (backspace_edge && !result_mode && !backspace_in_progress) begin
                // Remove the most recently entered character (digit or operator)
                if (entry_count != 0) begin
                    backspace_in_progress <= 1;
                    backspace_request    <= 1;
                    char_to_write        <= 8'h20;   // overwrite with space

                    if (cursor_pos > 0) begin
                        backspace_pos  <= cursor_pos - 1;
                        backspace_line <= cursor_line;
                    end else if (cursor_line == 1) begin
                        backspace_pos  <= 4'd15;
                        backspace_line <= 0;
                    end else begin
                        backspace_pos  <= 4'd15;
                        backspace_line <= 1;
                    end

                    if (!have_operator) begin
                        operand1 <= operand1 / 10;
                    end else if (operand2 != 0) begin
                        operand2 <= operand2 / 10;
                    end else begin
                        have_operator    <= 0;
                        op_code          <= 0;
                        op_clear_request <= 1;
                    end

                    entry_count <= entry_count - 1;

                    if (entry_count == 1) begin
                        seven_seg_valid <= 0;  // cleared the final digit/operator
                    end
                end
            end
        end

        if (clear_display_request && state == S_CLEAR) begin
            clear_display_request <= 0;
        end

        if (clear_in_progress && state == S_IDLE && !clear_display_request) begin
            clear_in_progress <= 0;
            if (queued_char_pending) begin
                char_to_write <= queued_char_data;
                button_digit  <= queued_digit_data;
                queued_char_pending <= 0;
                manual_button_press <= 1;
                seven_seg_digit <= queued_digit_data;
                seven_seg_valid <= 1;
                if (queued_entry_increment) begin
                    entry_count <= entry_count + 1;
                    queued_entry_increment <= 0;
                end
            end
        end
    end
end

// Track whether operators have already been written to prevent duplicates
always @(posedge clk_100hz or posedge rst) begin
    if (rst) begin
        op_present <= 0;
    end else begin
        if ((state == S_CLEAR && cnt == 0) || op_clear_request) begin
            op_present <= 0;
        end else if (state == S_WRITE_CHAR && write_char_done) begin
            case (char_to_write)
                8'h2B: op_present[0] <= 1;  // '+'
                8'h2D: op_present[1] <= 1;  // '-'
                8'h2A: op_present[2] <= 1;  // '*'
                8'h2F: op_present[3] <= 1;  // '/'
                default: op_present <= op_present;
            endcase
        end
    end
end

// Light dedicated LEDs for the active operation (+, -, *, /)
always @(posedge clk_100hz or posedge rst) begin
    if (rst) begin
        led_plus  <= 0;
        led_minus <= 0;
        led_mul   <= 0;
        led_div   <= 0;
    end else begin
        if (dip_request_any) begin
            {led_div, led_mul, led_minus, led_plus} <= 4'b0000;
            casex (dip_add_request)
                4'bxxx1: led_plus  <= 1;
                4'bxx10: led_minus <= 1;
                4'bx100: led_mul   <= 1;
                4'b1000: led_div   <= 1;
                default: begin end
            endcase
        end else if (!have_operator) begin
            led_plus  <= 0;
            led_minus <= 0;
            led_mul   <= 0;
            led_div   <= 0;
        end
    end
end

//////////////////////////
// Cursor Position      //
//////////////////////////
reg [3:0] cursor_pos = 0;  // Position 0-15 (16 characters per line)
reg cursor_line = 0;        // 0 = line 1, 1 = line 2

//////////////////////////
// State Machine        //
//////////////////////////
reg [3:0] state;
reg [9:0] cnt;
reg write_char_done;
reg cursor_hold;

localparam S_DELAY        = 4'd0,
           S_FUNCTION_SET = 4'd1,
           S_DISPLAY_ON   = 4'd2,
           S_ENTRY_MODE   = 4'd3,
           S_CLEAR        = 4'd4,
           S_HOME         = 4'd5,
           S_IDLE         = 4'd6,
           S_WRITE_CHAR   = 4'd7,
           S_RESULT       = 4'd8;


////////////////////////////////////////
// FSM STATE TRANSITION
////////////////////////////////////////
always @(posedge clk_100hz or posedge rst) begin
    if (rst) begin
        state <= S_DELAY;
        cnt <= 0;
        cursor_pos <= 0;
        cursor_line <= 0;
        write_char_done <= 0;
        cursor_hold <= 0;
    end else begin
        case(state)

        S_DELAY: begin
            if (cnt == 70) begin state <= S_FUNCTION_SET; cnt <= 0; end
            else cnt <= cnt + 1;
        end

        S_FUNCTION_SET: begin
            if (cnt == 30) begin state <= S_DISPLAY_ON; cnt <= 0; end
            else cnt <= cnt + 1;
        end

        S_DISPLAY_ON: begin
            if (cnt == 30) begin state <= S_ENTRY_MODE; cnt <= 0; end
            else cnt <= cnt + 1;
        end

        S_ENTRY_MODE: begin
            if (cnt == 30) begin state <= S_CLEAR; cnt <= 0; end
            else cnt <= cnt + 1;
        end

        S_CLEAR: begin
            if (cnt == 200) begin state <= S_HOME; cnt <= 0; end
            else cnt <= cnt + 1;
        end

        S_HOME: begin
            if (cnt == 50) begin state <= S_IDLE; cnt <= 0; end
            else cnt <= cnt + 1;
        end

        S_IDLE: begin
            // If a result has just been prepared, move cursor to start of line 2
            if (result_start) begin
                cursor_line  <= 1;
                cursor_pos   <= 0;
            end
            if (result_mode) begin
                state <= S_RESULT;
                cnt <= 0;
                write_char_done <= 0;
            end else if (clear_display_request) begin
                state <= S_CLEAR;
                cnt <= 0;
                write_char_done <= 0;
                cursor_line <= 0;
                cursor_pos <= 0;
            end else if (backspace_request) begin
                cursor_line <= backspace_line;
                cursor_pos  <= backspace_pos;
                cursor_hold <= 1;
                state <= S_WRITE_CHAR;
                cnt <= 0;
                write_char_done <= 0;
            end else if (button_pressed) begin
                state <= S_WRITE_CHAR;
                cnt <= 0;
                write_char_done <= 0;
            end
        end

        S_WRITE_CHAR: begin
            if (write_char_done) begin
                state <= (result_mode ? S_RESULT : S_IDLE);
                write_char_done <= 0;
                // Advance cursor position for next write
                if (cursor_hold) begin
                    cursor_hold <= 0;
                end else if (cursor_pos == 15) begin
                    // Move to next line if available
                    if (cursor_line == 0) begin
                        cursor_line <= 1;
                        cursor_pos <= 0;
                    end else begin
                        // Both lines full, wrap to line 1 position 0
                        cursor_line <= 0;
                        cursor_pos <= 0;
                    end
                end else begin
                    cursor_pos <= cursor_pos + 1;
                end
            end else begin
                if (cnt == 30) begin  // Wait for address set + character write to complete
                    write_char_done <= 1;
                    cnt <= 0;
                end else begin
                    cnt <= cnt + 1;
                end
            end
        end

        S_RESULT: begin
            if (!result_mode) begin
                state <= S_IDLE;
            end else begin
                state <= S_WRITE_CHAR;
                cnt <= 0;
                write_char_done <= 0;
            end
        end

        endcase
    end
end



////////////////////////////////////////
// LCD OUTPUT LOGIC
////////////////////////////////////////
always @(posedge clk_100hz or posedge rst) begin
    if (rst) begin
        lcd_rs   <= 1;
        lcd_rw   <= 1;
        lcd_data <= 8'h00;
    end else begin
        case(state)

        ///////////////////////////////////
        // Commands
        ///////////////////////////////////
        S_FUNCTION_SET: begin
            lcd_rs   <= 0;
            lcd_rw   <= (cnt == 0) ? 0 : 1;
            lcd_data <= 8'b0011_1100;   // 2 lines, 5x8 dots
        end

        S_DISPLAY_ON: begin
            lcd_rs   <= 0;
            lcd_rw   <= (cnt == 0) ? 0 : 1;
            lcd_data <= 8'b0000_1100;   // Display ON, Cursor OFF
        end

        S_ENTRY_MODE: begin
            lcd_rs   <= 0;
            lcd_rw   <= (cnt == 0) ? 0 : 1;
            lcd_data <= 8'b0000_0110;   // Increment, no shift
        end

        S_CLEAR: begin
            lcd_rs   <= 0;
            lcd_rw   <= (cnt == 0) ? 0 : 1;
            lcd_data <= 8'b0000_0001;   // Clear display
        end

        S_HOME: begin
            lcd_rs   <= 0;
            lcd_rw   <= (cnt == 0) ? 0 : 1;
            lcd_data <= 8'b0000_0010;   // Return home
        end

        ///////////////////////////////////
        // IDLE - Wait for button press
        ///////////////////////////////////
        S_IDLE: begin
            // Keep LCD in ready state, do nothing
            lcd_rs   <= 1;
            lcd_rw   <= 1;
            lcd_data <= 8'h00;
        end

        ///////////////////////////////////
        // WRITE_CHAR - Write "1" to LCD
        ///////////////////////////////////
        S_WRITE_CHAR: begin
            if (cnt < 10) begin
                // Set DDRAM address based on cursor position
                lcd_rs <= 0;
                if (cursor_line == 0) begin
                    lcd_data <= 8'h80 + cursor_pos;  // Line 1: 0x80-0x8F
                end else begin
                    lcd_data <= 8'hC0 + cursor_pos;  // Line 2: 0xC0-0xCF
                end
                lcd_rw <= (cnt == 0) ? 0 : 1;        // Pulse only on first cycle
            end else begin
                // Write selected character
                lcd_rs <= 1;
                lcd_data <= char_to_write;
                lcd_rw <= (cnt == 10) ? 0 : 1;       // Single write pulse
            end
        end

        ///////////////////////////////////
        // DEFAULT
        ///////////////////////////////////
        default: begin
            lcd_rs   <= 1;
            lcd_rw   <= 1;
            lcd_data <= 8'h00;
        end

        endcase
    end
end

endmodule
