module puzzle(
    input         rst,
    input         clk,
    // BTN_NUM[0]..BTN_NUM[9] = numeric buttons 0..9
    // BTN_NUM[10]            = BACKSPACE button
    input  [10:0] BTN_NUM,
    input         BTN_ENTER,

    // Text LCD
    output        lcd_e,
    output        lcd_rs,
    output        lcd_rw,
    output [7:0]  lcd_data,

    // Life LEDs
    output [2:0]  life_led,

    // Full-color LED bar (4R, 4G, 4B)
    output reg [3:0] led_r,
    output reg [3:0] led_g,
    output reg [3:0] led_b,

    // Single 7-seg (a,b,c,d,e,f,g,h), active-HIGH
    output reg [7:0] seg,

    // Buzzer
    output        piezo
);

//=========================
// State encoding
//=========================
localparam S_MODE   = 3'd0;  // choose mode
localparam S_NAME   = 3'd1;  // nickname
localparam S_GEN    = 3'd2;  // generate puzzle
localparam S_INPUT  = 3'd3;  // answer input
localparam S_CHECK  = 3'd4;  // check result
localparam S_OVER   = 3'd5;  // game over

//=========================
// LCD text lines (16 chars each)
//=========================
reg [127:0] lcd_line1_flat;
reg [127:0] lcd_line2_flat;

//=========================
// Game variables
//=========================
reg  [7:0]  nickname[0:15];    
integer     nick_index;
reg  [31:0] operandA, operandB;
// 0:+,1:-,2:*,3:/ (division only in hard mode)
reg  [1:0]  operator;          
reg  [31:0] target_answer;
reg  [31:0] user_input;
reg  [1:0]  lives;
reg  [31:0] score;
reg         enter_pressed;
reg  [3:0]  number;            // detected key index (0..10)
reg         number_valid;      // 1 when a new key press is detected
reg  [2:0]  game_state;        // S_MODE..S_OVER
reg  [31:0] rand_counter;

// extra reg for swapping A/B in subtraction
reg  [31:0] swap_tmp;

//=========================
// Nickname multi-tap input
//=========================
localparam [3:0] KEY_NEXT      = 4'd0;
localparam [3:0] KEY_BACKSPACE = 4'd10;

reg  [3:0]  name_last_btn;   // last button used for current character
reg  [1:0]  name_press_cnt;  // how many times this button pressed (0..3)
reg  [1:0]  name_next_cnt;   // helper for cycling

// Map button+press count to a letter
function [7:0] map_letter;
    input [3:0] btn;
    input [1:0] cnt;
    begin
        case (btn)
            4'd1: begin   // a,b,c
                case (cnt)
                    2'd0: map_letter = "a";
                    2'd1: map_letter = "b";
                    default: map_letter = "c";   // 2,3 -> c
                endcase
            end
            4'd2: begin   // d,e,f
                case (cnt)
                    2'd0: map_letter = "d";
                    2'd1: map_letter = "e";
                    default: map_letter = "f";   // 2,3 -> f
                endcase
            end
            4'd3: begin   // g,h,i,j (4 letters)
                case (cnt)
                    2'd0: map_letter = "g";
                    2'd1: map_letter = "h";
                    2'd2: map_letter = "i";
                    default: map_letter = "j";   // 3 -> j
                endcase
            end
            4'd4: begin   // k,l,m
                case (cnt)
                    2'd0: map_letter = "k";
                    2'd1: map_letter = "l";
                    default: map_letter = "m";   // 2,3 -> m
                endcase
            end
            4'd5: begin   // n,o,p
                case (cnt)
                    2'd0: map_letter = "n";
                    2'd1: map_letter = "o";
                    default: map_letter = "p";   // 2,3 -> p
                endcase
            end
            4'd6: begin   // q,r,s
                case (cnt)
                    2'd0: map_letter = "q";
                    2'd1: map_letter = "r";
                    default: map_letter = "s";   // 2,3 -> s
                endcase
            end
            4'd7: begin   // t,u,v
                case (cnt)
                    2'd0: map_letter = "t";
                    2'd1: map_letter = "u";
                    default: map_letter = "v";   // 2,3 -> v
                endcase
            end
            4'd8: begin   // w,x,y
                case (cnt)
                    2'd0: map_letter = "w";
                    2'd1: map_letter = "x";
                    default: map_letter = "y";   // 2,3 -> y
                endcase
            end
            4'd9: begin   // z only
                map_letter = "z";
            end
            default: map_letter = " ";
        endcase
    end
endfunction

// Returns max index (0..3) for that button's letters
function [1:0] max_index;
    input [3:0] btn;
    begin
        case (btn)
            4'd3: max_index = 2'd3;   // g,h,i,j
            4'd9: max_index = 2'd0;   // z only
            default: max_index = 2'd2; // others: 3 letters
        endcase
    end
endfunction

// Difficulty mode selected from screen
// 00=easy, 01=medium, 10=hard
reg  [1:0]  difficulty_mode;

// Difficulty ranges
reg  [31:0] min_value, max_value;

// For display (show last two digits of operands)
reg  [31:0] a_tmp, b_tmp;
reg  [31:0] span;
reg  [31:0] diff_min;
reg  [1:0]  op_tmp;
reg  [3:0]  a_tens, a_ones, b_tens, b_ones;

// Loop counters
integer     lcd_index1;
integer     i;
integer     j;
integer     new_lives;         // for check state
reg  [31:0] disp_score;        // score shown on LCD in S_CHECK

//=========================
// Timer for countdown (5 seconds)
//=========================
reg  [5:0]  time_left;         // 0..59
reg  [25:0] sec_div;           // divider for 1 second
reg         timeout;           // 1-cycle pulse when time_left hits 0
reg         is_timeout;        // latched flag for state S_CHECK

localparam SEC_TICKS = 26'd50_000_000; // ~1s at 50 MHz

//=========================
// Buzzer control with melody (50MHz)
//=========================
reg  [2:0]  prev_state;

// 0 = idle, 1 = correct melody, 2 = wrong tone, 3 = timeout tone
// 4 = keypad beep, 5 = countdown 3-2-1 long beep
localparam BUZZ_IDLE      = 3'd0;
localparam BUZZ_CORRECT   = 3'd1;
localparam BUZZ_WRONG     = 3'd2;
localparam BUZZ_TIMEOUT   = 3'd3;
localparam BUZZ_KEYPAD    = 3'd4;
localparam BUZZ_COUNT321  = 3'd5;

reg  [2:0]  buzz_mode;
reg  [2:0]  melody_step;   // 0..7 for do-re-mi-fa-so-la-ti-do
reg  [24:0] buzz_cnt;      // divider counter
reg  [24:0] dur_cnt;       // duration for correct notes
reg  [24:0] total_timer;   // generic duration
reg  [15:0] cur_div;       // current frequency divider
reg         piezo_reg;

// Note "frequencies" (just different divisors -> different pitches)
localparam [15:0] NOTE_DO   = 16'd25_000;
localparam [15:0] NOTE_RE   = 16'd22_000;
localparam [15:0] NOTE_MI   = 16'd20_000;
localparam [15:0] NOTE_FA   = 16'd18_000;
localparam [15:0] NOTE_SO   = 16'd16_000;
localparam [15:0] NOTE_LA   = 16'd14_000;
localparam [15:0] NOTE_TI   = 16'd12_000;
localparam [15:0] NOTE_DO2  = 16'd10_000;

// Duration settings (~rough, at 50MHz clock)
localparam [24:0] CORRECT_NOTE_DUR    = 25'd3_000_000;    // per note
localparam [24:0] WRONG_TOTAL_DUR     = 25'd25_000_000;   // whole DDDDD...
localparam [24:0] TIMEOUT_TOTAL_DUR   = 25'd40_000_000;   // longer tone

// Short keypad click (~0.1s at 50 MHz)
localparam [24:0] KEYPAD_DUR          = 25'd5_000_000;

// Long DDDDD for 3 / 2 / 1 (~0.8s at 50 MHz)
localparam [24:0] COUNT321_TOTAL_DUR  = 25'd40_000_000;

// map keypad key index to a note frequency
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
            4'd10: key_divisor = NOTE_FA;  // BACKSPACE
            default: key_divisor = NOTE_SO; // ENTER / others
        endcase
    end
endfunction

// For keypad + countdown
reg  [5:0]  prev_time_left;
reg         prev_btn_enter;

//=========================
// Feedback hold after S_CHECK
//=========================
localparam [31:0] FEEDBACK_WAIT_TICKS = 32'd100_000_000; // ~2s at 50 MHz
reg        [31:0] feedback_cnt;
reg               check_done;

//=========================
// Pseudo-random counter
//=========================
always @(posedge clk or posedge rst) begin
    if (rst) rand_counter <= 0;
    else     rand_counter <= rand_counter + 1;
end

// random 1..max
function [31:0] rand_num(input [31:0] max);
    begin
        if (max == 0)
            rand_num = 0;
        else
            rand_num = (rand_counter % max) + 1;
    end
endfunction

// random in [min..max]
function [31:0] rand_range(input [31:0] min, input [31:0] max);
    reg [31:0] span_local;
    begin
        if (max <= min)
            rand_range = min;
        else begin
            span_local = max - min + 1;
            rand_range = min + (rand_counter % span_local);
        end
    end
endfunction

//=========================
// Rising-edge detector for BTN_NUM -> number + number_valid
//=========================
reg [10:0] btn_num_prev;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        btn_num_prev <= 11'b0;
        number       <= 4'd15;
        number_valid <= 1'b0;
    end else begin
        btn_num_prev <= BTN_NUM;
        number_valid <= 1'b0;     // default: no new press this cycle

        // detect any rising edge (0..10)
        for (j = 0; j < 11; j = j + 1) begin
            if (BTN_NUM[j] && !btn_num_prev[j]) begin
                number       <= j[3:0];  // new key index 0..10
                number_valid <= 1'b1;    // one-shot pulse
            end
        end
    end
end

//=========================
// Difficulty ranges based on difficulty_mode
// Easy:   0..9   (single-digit)
// Medium: 10..99
// Hard:   100..999 (for +,-,*) and div operands around this range
//=========================
always @(*) begin
    case (difficulty_mode)
        2'b00: begin   // EASY -> only 0~9
            min_value = 0;
            max_value = 9;
        end
        2'b01: begin   // MEDIUM
            min_value = 10;
            max_value = 99;
        end
        default: begin // HARD
            min_value = 100;
            max_value = 999;
        end
    endcase
end

//=========================
// Main FSM
//=========================
always @(posedge clk or posedge rst) begin
    if (rst) begin
        user_input      <= 0;
        score           <= 0;
        lives           <= 3;
        game_state      <= S_MODE;     // start at mode select
        difficulty_mode <= 2'b00;      // default EASY
        nick_index      <= 0;
        lcd_index1      <= 0;
        enter_pressed   <= 0;
        is_timeout      <= 0;
        lcd_line1_flat  <= 128'h20202020202020202020202020202020;
        lcd_line2_flat  <= 128'h20202020202020202020202020202020;
        name_last_btn   <= 4'd15;
        name_press_cnt  <= 2'd0;
        name_next_cnt   <= 2'd0;
        check_done      <= 1'b0;
        feedback_cnt    <= 32'd0;
        for (i = 0; i < 16; i = i + 1)
            nickname[i] <= 8'h20;
    end else begin
        case (game_state)
            //--------------------------------------
            // S_MODE: Mode Selection
            //--------------------------------------
            S_MODE: begin
                // "Select Mode:"
                lcd_line1_flat <= { "Select Mode:    " };
                // "0:E 1:M 2:H   "
                lcd_line2_flat <= { "0:E 1:M 2:H    " };

                // reset name input each time we're in mode select
                nick_index      <= 0;
                name_last_btn   <= 4'd15;
                name_press_cnt  <= 2'd0;
                check_done      <= 1'b0;
                feedback_cnt    <= 32'd0;
                for (i = 0; i < 16; i = i + 1)
                    nickname[i] <= 8'h20;

                // pick mode with buttons (only on new key press)
                if (number_valid) begin
                    if (number == 0) begin
                        difficulty_mode <= 2'b00;   // EASY
                        game_state      <= S_NAME;
                    end else if (number == 1) begin
                        difficulty_mode <= 2'b01;   // MEDIUM
                        game_state      <= S_NAME;
                    end else if (number == 2) begin
                        difficulty_mode <= 2'b10;   // HARD
                        game_state      <= S_NAME;
                    end
                end
            end

            //--------------------------------------
            // S_NAME: Nickname Input
            //--------------------------------------
            S_NAME: begin
                lcd_line1_flat <= { "Enter Name:     " };

                // show current nickname on line2
                for (i = 0; i < 16; i = i + 1) begin
                    if (i < nick_index)
                        lcd_line2_flat[127-8*i -: 8] <= nickname[i];
                    else
                        lcd_line2_flat[127-8*i -: 8] <= 8'h20;
                end

                if (number_valid) begin
                    // BACKSPACE (button index 10)
                    if (number == KEY_BACKSPACE) begin
                        if (nick_index > 0) begin
                            nick_index <= nick_index - 1;
                            nickname[nick_index-1] <= 8'h20; // clear last char
                            name_last_btn  <= 4'd15;         // reset multi-tap
                            name_press_cnt <= 2'd0;
                        end
                    end
                    // NEXT: commit current letter, start new
                    else if (number == KEY_NEXT) begin
                        if (nick_index > 0) begin
                            // finish current letter: next press starts a new char
                            name_last_btn  <= 4'd15;   // invalid -> forces new char
                            name_press_cnt <= 2'd0;
                        end
                    end
                    // BUTTONS 1..9: multi-tap letters (9 has only 'z')
                    else if (number >= 1 && number <= 9) begin
                        // First character
                        if (nick_index == 0) begin
                            nick_index      <= 1;
                            name_last_btn   <= number;
                            name_press_cnt  <= 2'd0;
                            nickname[0]     <= map_letter(number, 2'd0);
                        end
                        else if (number == name_last_btn) begin
                            // Same button: cycle current character
                            name_next_cnt = (name_press_cnt == max_index(name_last_btn))
                                            ? 2'd0
                                            : (name_press_cnt + 1'b1);

                            name_press_cnt          <= name_next_cnt;
                            nickname[nick_index-1]  <= map_letter(number, name_next_cnt);
                        end
                        else begin
                            // New button: move to next character
                            if (nick_index < 16) begin
                                name_last_btn              <= number;
                                name_press_cnt             <= 2'd0;
                                nickname[nick_index]       <= map_letter(number, 2'd0);
                                nick_index                 <= nick_index + 1;
                            end
                        end
                    end
                end

                // ENTER -> start game
                if (BTN_ENTER && !enter_pressed) begin
                    enter_pressed <= 1;
                    game_state    <= S_GEN;  // generate puzzle
                end else if (!BTN_ENTER) begin
                    enter_pressed <= 0;
                end
            end

            //--------------------------------------
            // S_GEN: Generate Puzzle
            // Easy: +, - with 0~9 operands
            // Medium: +, -, *
            // Hard: +, -, *, / (division gives integer result)
            //--------------------------------------
            S_GEN: begin
                check_done   <= 1'b0;
                feedback_cnt <= 32'd0;

                // span of allowed values
                span = max_value - min_value + 1;
                if (span < 2)
                    span = 2;

                // minimum difference between A and B (for +,-,*, not strictly needed for easy)
                if (span >= 20)
                    diff_min = 10;
                else if (span >= 10)
                    diff_min = 5;
                else
                    diff_min = 1;

                // Base random values
                a_tmp = min_value + (rand_counter        % span);
                b_tmp = min_value + ((rand_counter >> 7) % span);

                // Enforce minimum difference |A - B| >= diff_min (for + and -)
                if ( (a_tmp > b_tmp ? (a_tmp - b_tmp) : (b_tmp - a_tmp)) < diff_min ) begin
                    if (a_tmp + diff_min <= max_value)
                        b_tmp = a_tmp + diff_min;
                    else if (a_tmp >= min_value + diff_min)
                        b_tmp = a_tmp - diff_min;
                    else
                        // fallback: place B roughly in middle of range
                        b_tmp = min_value + (span >> 1);
                end

                // Choose operator depending on difficulty
                // 00: 0..1 => +, -
                // 01: 0..2 => +, -, *
                // 10: 0..3 => +, -, *, /
                if (difficulty_mode == 2'b00)
                    op_tmp = rand_num(2) - 1;   // 0..1
                else if (difficulty_mode == 2'b01)
                    op_tmp = rand_num(3) - 1;   // 0..2
                else
                    op_tmp = rand_num(4) - 1;   // 0..3 (adds division)

                // For subtraction, ensure A >= B so result is not negative
                if (op_tmp == 2'd1 && a_tmp < b_tmp) begin
                    swap_tmp = a_tmp;
                    a_tmp    = b_tmp;
                    b_tmp    = swap_tmp;
                end

                // Special handling for division in HARD mode
                if (difficulty_mode == 2'b10 && op_tmp == 2'd3) begin
                    // generate divisor 2..9
                    b_tmp = rand_range(2, 9);
                    // generate quotient 5..30
                    a_tmp = rand_range(5, 30);
                    // make A a multiple of divisor
                    a_tmp = a_tmp * b_tmp;

                    // A might be < min_value, so bump if needed
                    if (a_tmp < min_value) begin
                        a_tmp = min_value + ((rand_counter % 10) * b_tmp);
                    end

                    // clamp to max_value if too big
                    if (a_tmp > max_value)
                        a_tmp = max_value - (max_value % b_tmp);

                    // just in case, avoid zero
                    if (a_tmp == 0)
                        a_tmp = b_tmp;
                end

                // Store operands & operator
                operandA <= a_tmp;
                operandB <= b_tmp;
                operator <= op_tmp;

                // Positive numeric result
                case (op_tmp)
                    2'd0: target_answer <= a_tmp + b_tmp;      // +
                    2'd1: target_answer <= a_tmp - b_tmp;      // -
                    2'd2: target_answer <= a_tmp * b_tmp;      // *
                    2'd3: target_answer <= (b_tmp != 0) ? (a_tmp / b_tmp) : 0; // /
                    default: target_answer <= 0;
                endcase

                // Precompute last two digits for display
                a_ones = a_tmp % 10;
                a_tens = (a_tmp / 10) % 10;
                b_ones = b_tmp % 10;
                b_tens = (b_tmp / 10) % 10;

                // Clear line1 then build "AA op BB = ?"
                lcd_line1_flat <= 128'h20202020202020202020202020202020;

                // A (2 digits)
                lcd_line1_flat[127-:8] <= a_tens + 8'd48;
                lcd_line1_flat[119-:8] <= a_ones + 8'd48;

                // operator
                case (op_tmp)
                    2'd0: lcd_line1_flat[111-:8] <= "+";  // +
                    2'd1: lcd_line1_flat[111-:8] <= "-";  // -
                    2'd2: lcd_line1_flat[111-:8] <= "*";  // *
                    2'd3: lcd_line1_flat[111-:8] <= "/";  // /
                    default: lcd_line1_flat[111-:8] <= " "; 
                endcase

                // B (2 digits)
                lcd_line1_flat[103-:8] <= b_tens + 8'd48;
                lcd_line1_flat[95-:8]  <= b_ones + 8'd48;

                // = ?
                lcd_line1_flat[87-:8]  <= "=";
                lcd_line1_flat[79-:8]  <= "?";

                // Clear line2, go to input
                lcd_index1 <= 0;
                user_input <= 0;
                for (i = 0; i < 16; i = i + 1)
                    lcd_line2_flat[127-8*i -: 8] <= 8'h20;

                game_state <= S_INPUT;
            end

            //--------------------------------------
            // S_INPUT: Answer Input (with timeout + BACKSPACE)
            //--------------------------------------
            S_INPUT: begin
                if (timeout) begin
                    // time is up -> treat as timeout check
                    is_timeout    <= 1'b1;
                    enter_pressed <= 1'b0;
                    game_state    <= S_CHECK;
                end else begin
                    if (number_valid) begin
                        // NUMERIC digit 0..9
                        if (number <= 4'd9 && lcd_index1 < 16) begin
                            user_input <= user_input * 10 + number;
                            lcd_line2_flat[127-8*lcd_index1 -: 8] <= 8'd48 + number;
                            lcd_index1 <= lcd_index1 + 1;
                        end
                        // BACKSPACE (button index 10)
                        else if (number == KEY_BACKSPACE && lcd_index1 > 0) begin
                            user_input <= user_input / 10;
                            lcd_index1 <= lcd_index1 - 1;
                            lcd_line2_flat[127-8*(lcd_index1-1) -: 8] <= 8'h20;
                        end
                    end

                    // ENTER = check answer (not timeout)
                    if (BTN_ENTER && !enter_pressed) begin
                        enter_pressed <= 1;
                        is_timeout    <= 1'b0;
                        game_state    <= S_CHECK;
                    end else if (!BTN_ENTER) begin
                        enter_pressed <= 0;
                    end
                end
            end

            //--------------------------------------
            // S_CHECK: Check Answer + HOLD message
            //--------------------------------------
            S_CHECK: begin
                if (!check_done) begin
                    // first cycle in S_CHECK: compute result & set messages
                    new_lives  = lives;
                    disp_score = score;   // default: current score

                    if (user_input == target_answer && !is_timeout) begin
                        // Correct
                        disp_score = score + 1;
                        score      <= disp_score;
                        lcd_line1_flat <= { "Correct!        " };
                    end else begin
                        // Wrong OR Timeout
                        if (new_lives > 0)
                            new_lives = new_lives - 1;

                        if (is_timeout)
                            lcd_line1_flat <= { "Timeout!        " };
                        else
                            lcd_line1_flat <= { "Wrong!          " };
                    end

                    lives <= new_lives;

                    // Row2: "Score: X"
                    lcd_line2_flat <= { "Score:          " };
                    lcd_line2_flat[71-:8] <= (disp_score % 10) + 8'd48;  // last digit

                    // Reset answer buffer for next puzzle
                    lcd_index1  <= 0;
                    user_input  <= 0;
                    is_timeout  <= 0;

                    // start feedback hold
                    check_done   <= 1'b1;
                    feedback_cnt <= 32'd0;
                end else begin
                    // hold the "Correct!/Wrong!/Timeout!" screen
                    if (feedback_cnt < FEEDBACK_WAIT_TICKS)
                        feedback_cnt <= feedback_cnt + 1'b1;
                    else begin
                        // feedback done -> next state
                        check_done   <= 1'b0;
                        feedback_cnt <= 32'd0;
                        if (lives == 0)
                            game_state <= S_OVER;
                        else
                            game_state <= S_GEN;
                    end
                end
            end

            //--------------------------------------
            // S_OVER: Game Over
            //--------------------------------------
            S_OVER: begin
                lcd_line1_flat <= { "Game Over       " };
                for (i = 0; i < 16; i = i + 1) begin
                    if (i < nick_index)
                        lcd_line2_flat[127-8*i -: 8] <= nickname[i];
                    else if (i == nick_index)
                        lcd_line2_flat[127-8*i -: 8] <= " ";
                    else if (i == nick_index+1)
                        lcd_line2_flat[127-8*i -: 8] <= "S";
                    else if (i == nick_index+2)
                        lcd_line2_flat[127-8*i -: 8] <= "c";
                    else if (i == nick_index+3)
                        lcd_line2_flat[127-8*i -: 8] <= "o";
                    else if (i == nick_index+4)
                        lcd_line2_flat[127-8*i -: 8] <= "r";
                    else if (i == nick_index+5)
                        lcd_line2_flat[127-8*i -: 8] <= "e";
                    else if (i == nick_index+6)
                        lcd_line2_flat[127-8*i -: 8] <= ":";
                    else if (i == nick_index+7)
                        lcd_line2_flat[127-8*i -: 8] <= (score % 10) + 8'd48;
                    else
                        lcd_line2_flat[127-8*i -: 8] <= 8'h20;
                end
            end

            default: begin
                game_state <= S_MODE;
            end
        endcase
    end
end

//=========================
// Countdown timer (time_left) + timeout pulse
//=========================
always @(posedge clk or posedge rst) begin
    if (rst) begin
        time_left <= 6'd5;
        sec_div   <= 26'd0;
        timeout   <= 1'b0;
    end else begin
        timeout <= 1'b0;  // default

        // reset timer on new puzzle
        if (game_state == S_GEN) begin
            time_left <= 6'd5;
            sec_div   <= 26'd0;
        end
        // count only while waiting for answer
        else if (game_state == S_INPUT) begin
            if (time_left > 0) begin
                sec_div <= sec_div + 1'b1;

                if (sec_div == SEC_TICKS - 1) begin
                    sec_div <= 26'd0;

                    if (time_left > 0) begin
                        time_left <= time_left - 1'b1;
                        // when 1 -> 0, assert timeout
                        if (time_left == 6'd1)
                            timeout <= 1'b1;
                    end
                end
            end
        end else begin
            sec_div <= 26'd0;
        end
    end
end

//=========================
// Life LEDs: show number of lives
//=========================
assign life_led =
    (lives == 2'd3) ? 3'b111 :
    (lives == 2'd2) ? 3'b011 :
    (lives == 2'd1) ? 3'b001 :
                      3'b000;  // 0 lives

//=========================
// Buzzer: melody + keypad + countdown
//=========================
always @(posedge clk or posedge rst) begin
    if (rst) begin
        prev_state      <= S_MODE;
        buzz_mode       <= BUZZ_IDLE;
        melody_step     <= 3'd0;
        buzz_cnt        <= 25'd0;
        dur_cnt         <= 25'd0;
        total_timer     <= 25'd0;
        cur_div         <= NOTE_DO;
        piezo_reg       <= 1'b0;
        prev_time_left  <= 6'd5;
        prev_btn_enter  <= 1'b0;
    end else begin
        // remember previous state / time / enter
        prev_state      <= game_state;
        prev_time_left  <= time_left;
        prev_btn_enter  <= BTN_ENTER;

        // 1) Enter S_CHECK -> Correct/Wrong/Timeout sounds (highest priority)
        if (prev_state != S_CHECK && game_state == S_CHECK) begin
            piezo_reg   <= 1'b0;
            buzz_cnt    <= 25'd0;
            dur_cnt     <= 25'd0;
            total_timer <= 25'd0;

            if (is_timeout) begin
                // Timeout: long single tone
                buzz_mode   <= BUZZ_TIMEOUT;
                cur_div     <= NOTE_SO;
                total_timer <= TIMEOUT_TOTAL_DUR;
            end else if (user_input == target_answer) begin
                // Correct: do-re-mi-fa-so-la-ti-do
                buzz_mode   <= BUZZ_CORRECT;
                melody_step <= 3'd0;
                cur_div     <= NOTE_DO;
            end else begin
                // Wrong: DDDDD...
                buzz_mode   <= BUZZ_WRONG;
                cur_div     <= NOTE_DO;
                total_timer <= WRONG_TOTAL_DUR;
            end
        end else begin
            // 2) Keypad click + 3/2/1 countdown beeps (only when not playing result sounds)
            if (buzz_mode == BUZZ_IDLE ||
                buzz_mode == BUZZ_KEYPAD ||
                buzz_mode == BUZZ_COUNT321) begin

                // Keypad / ENTER sound (like phone keypad)
                if (number_valid || (BTN_ENTER && !prev_btn_enter)) begin
                    buzz_mode   <= BUZZ_KEYPAD;
                    buzz_cnt    <= 25'd0;
                    total_timer <= KEYPAD_DUR;
                    dur_cnt     <= 25'd0;
                    piezo_reg   <= 1'b0;

                    if (number_valid)
                        cur_div <= key_divisor(number);   // 0..10
                    else
                        cur_div <= key_divisor(4'd11);    // ENTER -> default tone
                end
                // Timer 3 / 2 / 1 -> long DDDDD beep
                else if (game_state == S_INPUT &&
                         (time_left == 6'd3 || time_left == 6'd2 || time_left == 6'd1) &&
                         (time_left != prev_time_left)) begin
                    buzz_mode   <= BUZZ_COUNT321;
                    buzz_cnt    <= 25'd0;
                    total_timer <= COUNT321_TOTAL_DUR;
                    dur_cnt     <= 25'd0;
                    cur_div     <= NOTE_DO;   // long D tone
                    piezo_reg   <= 1'b0;
                end
            end

            // 3) Sound generation for each mode
            case (buzz_mode)
                BUZZ_IDLE: begin
                    piezo_reg <= 1'b0;
                end

                BUZZ_CORRECT: begin
                    // Play 8 ascending notes, each CORRECT_NOTE_DUR
                    buzz_cnt <= buzz_cnt + 1'b1;
                    if (buzz_cnt >= cur_div) begin
                        buzz_cnt  <= 25'd0;
                        piezo_reg <= ~piezo_reg;
                    end

                    dur_cnt <= dur_cnt + 1'b1;
                    if (dur_cnt >= CORRECT_NOTE_DUR) begin
                        dur_cnt <= 25'd0;
                        melody_step <= melody_step + 1'b1;

                        case (melody_step)
                            3'd0: cur_div <= NOTE_RE;
                            3'd1: cur_div <= NOTE_MI;
                            3'd2: cur_div <= NOTE_FA;
                            3'd3: cur_div <= NOTE_SO;
                            3'd4: cur_div <= NOTE_LA;
                            3'd5: cur_div <= NOTE_TI;
                            3'd6: cur_div <= NOTE_DO2;
                            default: begin
                                // finished do-re-mi-fa-so-la-ti-do
                                buzz_mode <= BUZZ_IDLE;
                                piezo_reg <= 1'b0;
                            end
                        endcase
                    end
                end

                BUZZ_WRONG: begin
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

                BUZZ_TIMEOUT: begin
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

                BUZZ_COUNT321: begin
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
end

assign piezo = piezo_reg;

//=========================
// RGB LED bar color control (4R, 4G, 4B)
// Correct  -> Green ON
// Wrong    -> Red ON
// Timeout  -> Red ON
// Idle     -> All OFF
//=========================
// Assumes active-HIGH LEDs. If active-LOW, invert patterns.
always @(*) begin
    case (buzz_mode)
        BUZZ_CORRECT: begin
            led_r = 4'b0000;
            led_g = 4'b1111;
            led_b = 4'b0000;
        end
        BUZZ_WRONG,
        BUZZ_TIMEOUT: begin
            led_r = 4'b1111;
            led_g = 4'b0000;
            led_b = 4'b0000;
        end
        default: begin
            led_r = 4'b0000;
            led_g = 4'b0000;
            led_b = 4'b0000;
        end
    endcase
end

//=========================
// Single 7-seg timer display
// a,b,c,d,e,f,g,h, active-HIGH
//=========================
reg [3:0] seg_num;

always @(*) begin
    // choose which digit to show
    if (game_state == S_INPUT)
        seg_num = (time_left > 9) ? 4'd9 : time_left[3:0];
    else
        seg_num = 4'd0;   // show 0 when not in input

    case (seg_num)
        // a b c d e f g h  (1 = segment ON)
        4'd0: seg = 8'b00111111; // 0 : a,b,c,d,e,f
        4'd1: seg = 8'b00000110; // 1 : b,c
        4'd2: seg = 8'b01011011; // 2 : a,b,d,e,g
        4'd3: seg = 8'b01001111; // 3 : a,b,c,d,g
        4'd4: seg = 8'b01100110; // 4 : b,c,f,g
        4'd5: seg = 8'b01101101; // 5 : a,c,d,f,g
        4'd6: seg = 8'b10111110; // 6 : a,c,d,e,f,g
        4'd7: seg = 8'b00000111; // 7 : a,b,c
        4'd8: seg = 8'b01111111; // 8 : a,b,c,d,e,f,g
        4'd9: seg = 8'b01100111; // 9 : a,b,c,d,f,g
        default: seg = 8'b00000000;// all OFF
    endcase
end

//=========================
// Instantiate LCD driver
//=========================
textlcd_flat u_lcd (
    .rst        (rst),
    .clk        (clk),
    .lcd_e      (lcd_e),
    .lcd_rs     (lcd_rs),
    .lcd_rw     (lcd_rw),
    .lcd_data   (lcd_data),
    .line1_flat (lcd_line1_flat),
    .line2_flat (lcd_line2_flat)
);

endmodule


//============================================================
// Simple 8-bit HD44780 text LCD driver
//============================================================
module textlcd_flat(
    input         rst,
    input         clk,

    output reg    lcd_e,
    output reg    lcd_rs,
    output reg    lcd_rw,
    output reg [7:0] lcd_data,

    input  [127:0] line1_flat,
    input  [127:0] line2_flat
);

//--------------------------------------------------
// Clock divider ~1 kHz tick
//--------------------------------------------------
reg [15:0] div_cnt;
reg        tick_1k;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        div_cnt <= 0;
        tick_1k <= 0;
    end else begin
        if (div_cnt == 16'd49_999) begin
            div_cnt <= 0;
            tick_1k <= 1;
        end else begin
            div_cnt <= div_cnt + 1;
            tick_1k <= 0;
        end
    end
end

//--------------------------------------------------
// LCD FSM states
//--------------------------------------------------
localparam ST_POWON       = 4'd0;
localparam ST_FUNC_HIGH   = 4'd1;
localparam ST_FUNC_LOW    = 4'd2;
localparam ST_DISPON_HIGH = 4'd3;
localparam ST_DISPON_LOW  = 4'd4;
localparam ST_ENTRY_HIGH  = 4'd5;
localparam ST_ENTRY_LOW   = 4'd6;
localparam ST_CLEAR_HIGH  = 4'd7;
localparam ST_CLEAR_LOW   = 4'd8;
localparam ST_IDLE        = 4'd9;
localparam ST_SETADDR_H   = 4'd10;
localparam ST_SETADDR_L   = 4'd11;
localparam ST_WRITE_H     = 4'd12;
localparam ST_WRITE_L     = 4'd13;

reg [3:0] state;
reg [9:0] pow_cnt;
reg [5:0] char_pos; // 0..31

//--------------------------------------------------
// FUNCTION: get character from flattened 128-bit line
//--------------------------------------------------
function [7:0] get_char;
    input [5:0] pos;
    integer base;
begin
    if (pos < 16) begin
        base     = 127 - pos*8;
        get_char = line1_flat[base -: 8];
    end else begin
        base     = 127 - (pos-16)*8;
        get_char = line2_flat[base -: 8];
    end
end
endfunction

//--------------------------------------------------
// FUNCTION: return DDRAM address based on pos
// 0..15  -> 0x80..0x8F (line 1)
// 16..31 -> 0xC0..0xCF (line 2)
//--------------------------------------------------
function [7:0] get_addr;
    input [5:0] pos;
    reg [3:0] col;
begin
    if (pos < 16) begin
        col      = pos[3:0];
        get_addr = 8'h80 + col;
    end else begin
        col      = (pos - 6'd16);
        get_addr = 8'hC0 + col;
    end
end
endfunction

//--------------------------------------------------
// MAIN FSM (runs at 1 kHz tick)
//--------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state    <= ST_POWON;
        pow_cnt  <= 0;
        char_pos <= 0;

        lcd_e    <= 0;
        lcd_rs   <= 0;
        lcd_rw   <= 0;
        lcd_data <= 0;
    end
    else if (tick_1k) begin
        case(state)

            //===========================
            // 50 ms power-on delay
            //===========================
            ST_POWON: begin
                lcd_e <= 0;
                if (pow_cnt < 50)
                    pow_cnt <= pow_cnt + 1;
                else
                    state <= ST_FUNC_HIGH;
            end

            //---------------------------
            // FUNCTION SET (0x38)
            //---------------------------
            ST_FUNC_HIGH: begin
                lcd_rs <= 0;
                lcd_rw <= 0;
                lcd_data <= 8'h38;
                lcd_e <= 1;
                state <= ST_FUNC_LOW;
            end
            ST_FUNC_LOW: begin
                lcd_e <= 0;
                state <= ST_DISPON_HIGH;
            end

            //---------------------------
            // DISPLAY ON (0x0C)
            //---------------------------
            ST_DISPON_HIGH: begin
                lcd_rs <= 0;
                lcd_rw <= 0;
                lcd_data <= 8'h0C;
                lcd_e <= 1;
                state <= ST_DISPON_LOW;
            end
            ST_DISPON_LOW: begin
                lcd_e <= 0;
                state <= ST_ENTRY_HIGH;
            end

            //---------------------------
            // ENTRY MODE SET (0x06)
            //---------------------------
            ST_ENTRY_HIGH: begin
                lcd_rs <= 0;
                lcd_rw <= 0;
                lcd_data <= 8'h06;
                lcd_e <= 1;
                state <= ST_ENTRY_LOW;
            end
            ST_ENTRY_LOW: begin
                lcd_e <= 0;
                state <= ST_CLEAR_HIGH;
            end

            //---------------------------
            // CLEAR DISPLAY (0x01)
            //---------------------------
            ST_CLEAR_HIGH: begin
                lcd_rs <= 0;
                lcd_rw <= 0;
                lcd_data <= 8'h01;
                lcd_e <= 1;
                state <= ST_CLEAR_LOW;
            end
            ST_CLEAR_LOW: begin
                lcd_e <= 0;
                char_pos <= 0;
                state <= ST_IDLE;
            end

            //---------------------------
            // IDLE ? next character
            //---------------------------
            ST_IDLE: begin
                state <= ST_SETADDR_H;
            end

            //---------------------------
            // SET DDRAM ADDRESS
            //---------------------------
            ST_SETADDR_H: begin
                lcd_rs <= 0;
                lcd_rw <= 0;
                lcd_data <= get_addr(char_pos);
                lcd_e <= 1;
                state <= ST_SETADDR_L;
            end
            ST_SETADDR_L: begin
                lcd_e <= 0;
                state <= ST_WRITE_H;
            end

            //---------------------------
            // WRITE CHARACTER
            //---------------------------
            ST_WRITE_H: begin
                lcd_rs <= 1;
                lcd_rw <= 0;
                lcd_data <= get_char(char_pos);
                lcd_e <= 1;
                state <= ST_WRITE_L;
            end
            ST_WRITE_L: begin
                lcd_e <= 0;
                if (char_pos == 31)
                    char_pos <= 0;
                else
                    char_pos <= char_pos + 1;
                state <= ST_IDLE;
            end

            default: state <= ST_POWON;

        endcase
    end
end

endmodule


