module display_manager (
    input CLK,
    input RESET,
    
    // Inputs from Calculator Core
    input [7:0] display_A,
    input [7:0] display_B,
    input [7:0] result_out,
    input [1:0] display_op,   // 00:+, 01:-, 10:*, 11:/
    input [2:0] calc_state,   // 0: idle, 1: entering A, 2: entering B, 3: result ready

    // Outputs to Physical LCD Pins
    output LCD_RS,
    output LCD_E,
    output [3:0] LCD_DATA
);

    // --- LCD Controller Signals ---
    reg [7:0] lcd_data_reg;
    reg lcd_rs_reg, lcd_e_reg;
    assign LCD_RS = lcd_rs_reg;
    assign LCD_E  = lcd_e_reg;
    assign LCD_DATA = lcd_data_reg[3:0]; // assuming 4-bit mode

    // --- ASCII Conversion ---
    function [7:0] to_ascii;
        input [3:0] num;
        begin
            if (num < 10)
                to_ascii = 8'h30 + num;  // '0'-'9'
            else
                to_ascii = 8'h20;        // space if invalid
        end
    endfunction

    function [7:0] op_ascii;
        input [1:0] op;
        begin
            case(op)
                2'b00: op_ascii = "+"; 
                2'b01: op_ascii = "-"; 
                2'b10: op_ascii = "*"; 
                2'b11: op_ascii = "/"; 
                default: op_ascii = " ";
            endcase
        end
    endfunction

    // --- Simplified LCD FSM ---
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            lcd_data_reg <= 8'h20;
            lcd_rs_reg   <= 1'b0;
            lcd_e_reg    <= 1'b0;
        end else begin
            case(calc_state)
                3'd0: begin // idle
                    lcd_data_reg <= 8'h20; // blank
                    lcd_rs_reg <= 1'b1;
                    lcd_e_reg  <= 1'b1;
                end
                3'd1: begin // entering A
                    lcd_data_reg <= display_A;  // show A
                    lcd_rs_reg   <= 1'b1;
                    lcd_e_reg    <= 1'b1;
                end
                3'd2: begin // entering B
                    lcd_data_reg <= {display_A, op_ascii(display_op), display_B}; // show A op B
                    lcd_rs_reg   <= 1'b1;
                    lcd_e_reg    <= 1'b1;
                end
                3'd3: begin // result ready
                    lcd_data_reg <= {display_A, op_ascii(display_op), display_B}; // Row0
                    lcd_rs_reg   <= 1'b1;
                    lcd_e_reg    <= 1'b1;
                    // Row1 can be handled with same controller, e.g., using address = 0x40
                    // Here we assume your LCD controller handles writing two lines automatically
                end
            endcase
        end
    end

endmodule
