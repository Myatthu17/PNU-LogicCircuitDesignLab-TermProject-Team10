module button_manager (
    input CLK,
    input RESET,
    input [9:0] BTN_RAW_DIGITS,   // 10 digit buttons
    input BTN_RAW_CONFIRM,        // Confirm button
    input BTN_RAW_MISC,           // Misc/Clear/Backspace button

    output reg [3:0] digit_input, // Encoded digit value
    output wire digit_valid,      // Valid digit pulse
    output wire btn_confirm_vld,  // Confirm pulse
    output wire btn_clear_vld,    // Clear pulse
    output wire btn_backspace_vld // Backspace pulse
);

    // Combine all buttons: [11] Misc | [10] Confirm | [9:0] Digits
    wire [11:0] BTN_RAW_ALL = {BTN_RAW_MISC, BTN_RAW_CONFIRM, BTN_RAW_DIGITS};

    // Internal registers
    reg  [11:0] btn_synced;
    reg  [11:0] btn_stable;
    reg  [11:0] btn_prev;
    wire [11:0] btn_posedge;

    // Debounce + sync logic
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            btn_synced  <= 12'hFFF;
            btn_stable  <= 12'hFFF;
            btn_prev    <= 12'hFFF;
        end else begin
            btn_synced  <= ~BTN_RAW_ALL; // Active high (invert if active-low)
            btn_prev    <= btn_stable;
            btn_stable  <= btn_synced;
        end
    end

    // Positive edge detection
    assign btn_posedge = btn_stable & (~btn_prev);

    // Output pulses
    assign btn_confirm_vld   = btn_posedge[10]; // Confirm button
    assign btn_clear_vld     = btn_posedge[11]; // Misc clear
    assign btn_backspace_vld = btn_posedge[11]; // Same for backspace (optional split later)

    // Digit pulses and validity
    wire [9:0] digit_pulse = btn_posedge[9:0];
    assign digit_valid = |digit_pulse;

    // Priority encoder for digits
    always @(*) begin
        digit_input = 4'd0;
        if (digit_pulse[9])      digit_input = 4'd9;
        else if (digit_pulse[8]) digit_input = 4'd8;
        else if (digit_pulse[7]) digit_input = 4'd7;
        else if (digit_pulse[6]) digit_input = 4'd6;
        else if (digit_pulse[5]) digit_input = 4'd5;
        else if (digit_pulse[4]) digit_input = 4'd4;
        else if (digit_pulse[3]) digit_input = 4'd3;
        else if (digit_pulse[2]) digit_input = 4'd2;
        else if (digit_pulse[1]) digit_input = 4'd1;
        else if (digit_pulse[0]) digit_input = 4'd0;
    end

endmodule
