module puzzle_game(
    input wire clk,
    input wire rst,
    input wire [12:1] btn,         // 12 buttons
    input wire [1:0] DIP_SW_MODE,  // 00=Easy, 01=Medium, 10=Hard
    output wire LCD_RS,
    output wire LCD_E,
    output wire [7:0] LCD_DB,
    output reg [6:0] SEG           // 7-segment countdown
);

    // -------------------
    // Debounced buttons
    // -------------------
    wire [12:1] btn_d;
    genvar i;
    generate
        for(i=1;i<=12;i=i+1) begin: debounce_loop
            button_debounce db(.clk(clk), .rst(rst), .btn_in(btn[i]), .btn_out(btn_d[i]));
        end
    endgenerate

    // -------------------
    // LCD 16x2 buffer
    // -------------------
    reg [7:0] lcd_row1[0:15];
    reg [7:0] lcd_row2[0:15];
    reg [7:0] lcd_data;
    reg lcd_start;
    lcd_controller lcd(
        .clk(clk), .rst(rst),
        .data_in(lcd_data), .start(lcd_start),
        .LCD_RS(LCD_RS), .LCD_E(LCD_E), .LCD_DB(LCD_DB)
    );

    // -------------------
    // FSM states
    // -------------------
    parameter IDLE=0, ENTER_NAME=1, SUBMIT_NAME=2, SHOW_PUZZLE=3;
    parameter WAIT_ANSWER=4, CHECK_ANSWER=5, UPDATE_SCORE_LIVES=6, GAME_OVER=7;
    reg [3:0] state, next_state;

    // -------------------
    // Nickname
    // -------------------
    reg [7:0] nickname[0:7];  
    reg [2:0] nickname_index; 
    reg [4:0] char_index;     
    reg [7:0] current_char;

    // -------------------
    // Puzzle & answer
    // -------------------
    reg [15:0] puzzle_a, puzzle_b;
    reg [31:0] correct_answer;
    reg [31:0] user_answer;
    reg [4:0] answer_digit_index;

    // -------------------
    // Score & lives
    // -------------------
    reg [7:0] score;
    reg [3:0] lives;

    // -------------------
    // Random numbers (4-bit LFSR)
    // -------------------
    wire [3:0] rand_a, rand_b;
    lfsr rand1(.clk(clk), .rst(rst), .random(rand_a));
    lfsr rand2(.clk(clk), .rst(rst), .random(rand_b));

    // -------------------
    // Loop counters
    // -------------------
    reg [4:0] j,k;
    reg [31:0] temp;

    // -------------------
    // Countdown timer
    // -------------------
    reg [25:0] clk_div;
    reg sec_clk;
    always @(posedge clk or posedge rst) begin
        if(rst) begin clk_div<=0; sec_clk<=0; end
        else if(clk_div>=26'd49_999_999) begin clk_div<=0; sec_clk<=~sec_clk; end
        else clk_div<=clk_div+1;
    end

    reg [2:0] countdown;
    always @(posedge sec_clk or posedge rst) begin
        if(rst) countdown<=3'd5;
        else if(state==SHOW_PUZZLE) countdown<=3'd5;
        else if(state==WAIT_ANSWER && countdown>0) countdown<=countdown-1;
    end

    // 7-segment mapping
    always @(*) begin
        case(countdown)
            3'd0: SEG=7'b100_0000;
            3'd1: SEG=7'b111_1001;
            3'd2: SEG=7'b010_0100;
            3'd3: SEG=7'b011_0000;
            3'd4: SEG=7'b001_1001;
            3'd5: SEG=7'b001_0010;
            default: SEG=7'b111_1111;
        endcase
    end

    // -------------------
    // FSM transitions
    // -------------------
    always @(posedge clk or posedge rst) begin
        if(rst) state<=IDLE;
        else state<=next_state;
    end

    always @(*) begin
        case(state)
            IDLE: next_state=ENTER_NAME;
            ENTER_NAME: next_state=(btn_d[12])?SUBMIT_NAME:ENTER_NAME;
            SUBMIT_NAME: next_state=SHOW_PUZZLE;
            SHOW_PUZZLE: next_state=WAIT_ANSWER;
            WAIT_ANSWER: next_state=(btn_d[12] || countdown==0)?CHECK_ANSWER:WAIT_ANSWER;
            CHECK_ANSWER: next_state=UPDATE_SCORE_LIVES;
            UPDATE_SCORE_LIVES: next_state=(lives>=4)?GAME_OVER:SHOW_PUZZLE;
            GAME_OVER: next_state=IDLE;
            default: next_state=IDLE;
        endcase
    end

    // -------------------
    // FSM actions
    // -------------------
    reg [15:0] puzzle_min, puzzle_max;
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            nickname_index<=0; char_index<=0; current_char<="A";
            user_answer<=0; answer_digit_index<=0;
            puzzle_a<=0; puzzle_b<=0; correct_answer<=0;
            score<=0; lives<=0; countdown<=3'd5;
            lcd_start<=0;
            for(j=0;j<16;j=j+1) begin lcd_row1[j]<=" "; lcd_row2[j]<=" "; end
        end else begin
            lcd_start<=0;
            case(state)
                // ------------------- Enter nickname
                ENTER_NAME: begin
                    for(j=1;j<=8;j=j+1)
                        if(btn_d[j]) begin
                            char_index<=(char_index+1)%26;
                            current_char<="A"+char_index;
                        end
                    if(btn_d[11] && nickname_index>0) begin
                        nickname_index<=nickname_index-1;
                        nickname[nickname_index-1]<=" ";
                    end
                    if(nickname_index<8) nickname[nickname_index]<=current_char;
                    for(j=0;j<8;j=j+1) lcd_row2[j]<=nickname[j];
                    lcd_start<=1;
                    if((btn_d[1]|btn_d[2]|btn_d[3]|btn_d[4]|btn_d[5]|btn_d[6]|btn_d[7]|btn_d[8]) && nickname_index<7)
                        nickname_index<=nickname_index+1;
                end

                SUBMIT_NAME: begin end

                SHOW_PUZZLE: begin
                    case(DIP_SW_MODE)
                        2'b00: begin puzzle_min=1; puzzle_max=100; end
                        2'b01: begin puzzle_min=100; puzzle_max=10000; end
                        2'b10: begin puzzle_min=10000; puzzle_max=1000000; end
                        default: begin puzzle_min=1; puzzle_max=100; end
                    endcase
                    puzzle_a <= puzzle_min + (rand_a % (puzzle_max - puzzle_min + 1));
                    puzzle_b <= puzzle_min + (rand_b % (puzzle_max - puzzle_min + 1));
                    correct_answer <= puzzle_a + puzzle_b;
                    user_answer<=0; answer_digit_index<=0; countdown<=3'd5;
                    lcd_start<=1;
                end

                WAIT_ANSWER: begin
                    for(j=1;j<=9;j=j+1)
                        if(btn_d[j]) begin user_answer<=user_answer*10+j; answer_digit_index<=answer_digit_index+1; end
                    if(btn_d[10]) begin user_answer<=user_answer*10; answer_digit_index<=answer_digit_index+1; end
                    if(btn_d[11] && answer_digit_index>0) begin user_answer<=user_answer/10; answer_digit_index<=answer_digit_index-1; end
                    temp=user_answer;
                    for(k=0;k<16;k=k+1) begin
                        if(temp>0) begin lcd_row2[15-k]<="0"+(temp%10); temp=temp/10; end
                        else lcd_row2[15-k]<=" ";
                    end
                    lcd_start<=1;
                end

                CHECK_ANSWER: begin
                    if(user_answer==correct_answer && countdown>0) score<=score+1;
                    else lives<=lives+1;
                    lcd_start<=1;
                end

                UPDATE_SCORE_LIVES: begin end

                GAME_OVER: begin
                    lcd_start<=1;
                end
            endcase
        end
    end

endmodule
