module top(
    input         clk,
    input         rst,

    // Numeric keypad buttons (shared between puzzle & calculator)
    input  [10:0] BTN_NUM,
    input         BTN_ENTER,

    // Mode select switch and calculator operation DIP switches
    // mode_switch = 0 → Calculator, 1 → Puzzle
    input         mode_switch,
    input         dip_switch1,
    input         dip_switch2,
    input         dip_switch3,
    input         dip_switch4,

    // Text LCD
    output        lcd_e,
    output        lcd_rs,
    output        lcd_rw,
    output [7:0]  lcd_data,

    // Life LEDs (3 bits)
    output [2:0]  life_led,

    output led4,

    // Full-color LED bar (4R, 4G, 4B)
    output [3:0]  led_r,
    output [3:0]  led_g,
    output [3:0]  led_b,

    // Single 7‑seg (a,b,c,d,e,f,g,dp), active-HIGH
    output [7:0]  seg,

    // Buzzer
    output        piezo
);

    // Internally, mode_sel = 1 → calculator, 0 → puzzle
    // (mode_switch = 0 → calculator, 1 → puzzle)
    wire mode_sel = ~mode_switch;

    // Separate resets so only the selected mode runs.
    // - When mode_sel = 1 (calculator active), puzzle is held in reset.
    // - When mode_sel = 0 (puzzle active), calculator is held in reset.
    // This makes each mode start from the beginning whenever the
    // mode switch is toggled.
    wire rst_calculator = rst | ~mode_sel;
    wire rst_puzzle     = rst |  mode_sel;

    // Map button inputs to calculator keypad format
    // keypad_buttons[9:0]  : digits 0‑9  (BTN_NUM[9:0])
    // keypad_buttons[10]   : '='        (BTN_ENTER)
    // keypad_buttons[11]   : Backspace  (BTN_NUM[10])
    wire [11:0] keypad_buttons;
    assign keypad_buttons[9:0]  = BTN_NUM[9:0];
    assign keypad_buttons[10]   = BTN_ENTER;
    assign keypad_buttons[11]   = BTN_NUM[10];

    //============================
    // Puzzle instance & signals
    //============================
    wire        lcd_e_p;
    wire        lcd_rs_p;
    wire        lcd_rw_p;
    wire [7:0]  lcd_data_p;
    wire [2:0]  life_led_p;
    wire [3:0]  led_r_p;
    wire [3:0]  led_g_p;
    wire [3:0]  led_b_p;
    wire [7:0]  seg_p;
    wire        piezo_p;

    puzzle u_puzzle (
        .rst       (rst_puzzle),
        .clk       (clk),
        .BTN_NUM   (BTN_NUM),
        .BTN_ENTER (BTN_ENTER),

        .lcd_e     (lcd_e_p),
        .lcd_rs    (lcd_rs_p),
        .lcd_rw    (lcd_rw_p),
        .lcd_data  (lcd_data_p),

        .life_led  (life_led_p),

        .led_r     (led_r_p),
        .led_g     (led_g_p),
        .led_b     (led_b_p),

        .seg       (seg_p),

        .piezo     (piezo_p)
    );

    //============================
    // Calculator instance & signals
    //============================
    wire        lcd_e_c;
    wire        lcd_rs_c;
    wire        lcd_rw_c;
    wire [7:0]  lcd_data_c;
    wire [6:0]  seven_seg_c;
    wire        seven_seg_dp_c;
    wire        led_plus_c;
    wire        led_minus_c;
    wire        led_mul_c;
    wire        led_div_c;
    wire        piezo_c;

    calculator u_calculator (
        .rst            (rst_calculator),
        .clk            (clk),
        .keypad_buttons (keypad_buttons),
        .dip_switch1    (dip_switch1),
        .dip_switch2    (dip_switch2),
        .dip_switch3    (dip_switch3),
        .dip_switch4    (dip_switch4),

        .lcd_e          (lcd_e_c),
        .lcd_rs         (lcd_rs_c),
        .lcd_rw         (lcd_rw_c),
        .lcd_data       (lcd_data_c),
        .seven_seg      (seven_seg_c),
        .seven_seg_dp   (seven_seg_dp_c),
        .led_plus       (led_plus_c),
        .led_minus      (led_minus_c),
        .led_mul        (led_mul_c),
        .led_div        (led_div_c),
        .piezo          (piezo_c)
    );

    //============================
    // Output selection (MUX)
    //============================
    assign lcd_e    = mode_sel ? lcd_e_c    : lcd_e_p;
    assign lcd_rs   = mode_sel ? lcd_rs_c   : lcd_rs_p;
    assign lcd_rw   = mode_sel ? lcd_rw_c   : lcd_rw_p;
    assign lcd_data = mode_sel ? lcd_data_c : lcd_data_p;

    // When in calculator mode, turn puzzle-specific LEDs/buzzer off
    
    // life_led[2:0] and led4 driven by calculator in calculator mode
    assign life_led[0] = mode_sel ? led_plus_c  : life_led_p[0];
    assign life_led[1] = mode_sel ? led_minus_c : life_led_p[1];
    assign life_led[2] = mode_sel ? led_mul_c   : life_led_p[2];
    assign led4 = mode_sel ? led_div_c : 1'b0;  // puzzle does not use led4

    assign led_r    = mode_sel ? 4'b0000     : led_r_p;
    assign led_g    = mode_sel ? 4'b0000     : led_g_p;
    assign led_b    = mode_sel ? 4'b0000     : led_b_p;
    assign piezo    = mode_sel ? piezo_c    : piezo_p;

    // 7‑segment: puzzle drives all 8 bits; calculator drives 7 bits + dp
    assign seg = mode_sel ? {seven_seg_dp_c, seven_seg_c} : seg_p;

endmodule