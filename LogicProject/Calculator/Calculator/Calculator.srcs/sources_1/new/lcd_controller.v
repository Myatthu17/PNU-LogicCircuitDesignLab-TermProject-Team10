module lcd_controller (
    // System Inputs
    input CLK,
    input RESET,
    
    // Data Input (ASCII character from display_manager)
    input [7:0] ASCII_DATA,
    input START_WRITE,
    input [3:0] DISPLAY_ADDR,
    
    // LCD Control Outputs
    output LCD_RS,
    output LCD_E,
    output [3:0] LCD_DATA
);

    // --- Local Parameters (States and Delays) ---
    parameter BAUD_RATE = 200; // Delay cycles (Tuned to your CLK frequency for uS delays)
    
    // State Machine Definition (Using localparam for Verilog-2001 compatibility)
    localparam [3:0]
        S_INIT_1    = 4'd0, S_INIT_2    = 4'd1, S_INIT_3    = 4'd2,
        S_WAIT      = 4'd3,
        S_CMD_1_MSB = 4'd4, S_CMD_1_LSB = 4'd5,
        S_DATA_1_MSB= 4'd6, S_DATA_1_LSB= 4'd7;

    // --- Internal Registers (Must be 'reg') ---
    reg [3:0] state = S_INIT_1;
    reg [7:0] data_to_send;
    reg [19:0] delay_counter;
    reg [7:0] cmd_address; 
    reg busy_flag = 1'b0;

    // Output Registers (Must be 'reg' since they are assigned in always block)
    reg LCD_RS_reg;
    reg LCD_E_reg;
    reg [3:0] LCD_DATA_reg;

    // Connect internal registers to output ports
    assign LCD_RS = LCD_RS_reg;
    assign LCD_E  = LCD_E_reg;
    assign LCD_DATA = LCD_DATA_reg;


    // --- Sequential Logic (Fixed to use 'always @' and 'reg') ---
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            state <= S_INIT_1;
            delay_counter <= 0;
            LCD_E_reg <= 1'b0;
            busy_flag <= 1'b1;
        end else begin
            
            // Default E goes low after a transfer pulse
            if (state == S_CMD_1_LSB || state == S_DATA_1_LSB) LCD_E_reg <= 1'b0;

            case (state)
                // --- Initialization Sequence (4-bit mode start) ---
                S_INIT_1: begin // Send 4'h3 (Function Set) with long delay
                    LCD_RS_reg <= 1'b0; // Command mode
                    LCD_DATA_reg <= 4'h3;
                    
                    // --- Fixed Timing Logic ---
                    if (delay_counter == (BAUD_RATE * 300)) begin // Long delay
                        LCD_E_reg <= 1'b1;
                        state <= S_INIT_2;
                        delay_counter <= 0;
                    end else delay_counter <= delay_counter + 1;
                end
                
                S_INIT_2: begin // Wait >4.1ms, Send 3x Function Set (4-bit start)
                    LCD_E_reg <= 1'b0; // E must be pulsed low before high
                    LCD_DATA_reg <= 4'h3;
                    if (delay_counter == (BAUD_RATE * 10)) begin 
                        LCD_E_reg <= 1'b1;
                        state <= S_INIT_3;
                        delay_counter <= 0;
                    end else delay_counter <= delay_counter + 1;
                end

                S_INIT_3: begin // Wait >100us, Send 3x Function Set (4-bit start), then C_FUNC_SET_1
                    LCD_E_reg <= 1'b0;
                    LCD_DATA_reg <= 4'h3;
                    if (delay_counter == (BAUD_RATE * 1)) begin 
                        LCD_E_reg <= 1'b1;
                        data_to_send <= 8'h28; // Function Set (4-bit, 2 line, 5x8)
                        state <= S_CMD_1_MSB; // Start sending full commands
                        delay_counter <= 0;
                    end else delay_counter <= delay_counter + 1;
                end
// --- Idle / Ready to Write ---
                S_WAIT: begin
                    busy_flag <= 1'b0;
                    if (START_WRITE) begin
                        busy_flag <= 1'b1;
                        
                        // Calculate cursor address command
                        // Note: DISPLAY_ADDR[3] used for row selection (Row 2 address starts at 8'hC0)
                        cmd_address <= (DISPLAY_ADDR[3]) ? (8'hC0 + DISPLAY_ADDR[2:0]) : (8'h80 + DISPLAY_ADDR[2:0]);
                        data_to_send <= cmd_address;
                        state <= S_CMD_1_MSB; // Start sending command
                        delay_counter <= 0; // Reset counter for command timing
                    end
                end

                // --- Command/Address Sequence ---
                S_CMD_1_MSB: begin
                    LCD_RS_reg <= 1'b0; // Command Mode
                    LCD_DATA_reg <= data_to_send[7:4]; // MSB
                    LCD_E_reg <= 1'b1; // Pulse E
                    delay_counter <= 0;
                    state <= S_CMD_1_LSB;
                end
                S_CMD_1_LSB: begin
                    // Wait for pulse duration (BAUD_RATE cycles)
                    if (delay_counter == BAUD_RATE) begin 
                        LCD_E_reg <= 1'b0;
                        LCD_DATA_reg <= data_to_send[3:0]; // LSB
                        LCD_E_reg <= 1'b1; // Pulse E again
                        
                        data_to_send <= ASCII_DATA; // Load the actual character
                        state <= S_DATA_1_MSB;
                        delay_counter <= 0; // Reset counter for next phase
                    end else delay_counter <= delay_counter + 1;
                end

                // --- Data Sequence (Sending the character) ---
                S_DATA_1_MSB: begin
                    LCD_RS_reg <= 1'b1; // Data Mode
                    LCD_DATA_reg <= data_to_send[7:4]; // MSB
                    LCD_E_reg <= 1'b1;
                    state <= S_DATA_1_LSB;
                end
                S_DATA_1_LSB: begin
                    // Wait for pulse duration
                    if (delay_counter == BAUD_RATE) begin
                        LCD_E_reg <= 1'b0;
                        LCD_DATA_reg <= data_to_send[3:0]; // LSB
                        LCD_E_reg <= 1'b1;
                        state <= S_WAIT;
                        delay_counter <= 0;
                    end else delay_counter <= delay_counter + 1;
                end

                default: state <= S_INIT_1;
            endcase
        end
    end
endmodule
