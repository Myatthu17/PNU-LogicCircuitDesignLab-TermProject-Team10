module bin_to_bcd (
    input CLK,
    input RESET,
    input [7:0] BIN_IN,
    input START_CONV,

    output reg [3:0] BCD_H,
    output reg [3:0] BCD_T,
    output reg [3:0] BCD_U,
    output reg CONV_DONE
);

    // --- Internal Registers ---
    reg [7:0] bin_shift;
    reg [3:0] hundreds, tens, units;
    reg [3:0] shift_count;
    reg busy;

    localparam [1:0] S_IDLE = 2'd0,
                     S_SHIFT = 2'd1,
                     S_DONE  = 2'd2;

    reg [1:0] state, next_state;

    // --- Sequential Block ---
    always @(posedge CLK or posedge RESET) begin
        if (RESET) begin
            state <= S_IDLE;
            bin_shift <= 8'd0;
            hundreds <= 4'd0;
            tens <= 4'd0;
            units <= 4'd0;
            shift_count <= 4'd0;
            busy <= 1'b0;
            CONV_DONE <= 1'b0;
        end else begin
            state <= next_state;

            case (state)
                // ---- IDLE ----
                S_IDLE: begin
                    CONV_DONE <= 1'b0;
                    if (START_CONV) begin
                        bin_shift <= BIN_IN;
                        hundreds <= 4'd0;
                        tens <= 4'd0;
                        units <= 4'd0;
                        shift_count <= 4'd0;
                        busy <= 1'b1;
                    end
                end

                // ---- SHIFT & ADJUST ----
                S_SHIFT: begin
                    // Add 3 if any BCD digit >= 5
                    if (hundreds >= 5) hundreds <= hundreds + 3;
                    if (tens >= 5) tens <= tens + 3;
                    if (units >= 5) units <= units + 3;

                    // Shift left by one
                    {hundreds, tens, units, bin_shift} <= {hundreds, tens, units, bin_shift} << 1;

                    shift_count <= shift_count + 1;

                    if (shift_count == 8)
                        busy <= 1'b0;
                end

                // ---- DONE ----
                S_DONE: begin
                    CONV_DONE <= 1'b1;
                end
            endcase
        end
    end

    // --- Combinational Next State Logic ---
    always @(*) begin
        next_state = state;

        case (state)
            S_IDLE: if (START_CONV) next_state = S_SHIFT;
            S_SHIFT: if (!busy && shift_count >= 8) next_state = S_DONE;
            S_DONE: next_state = S_IDLE;
            default: next_state = S_IDLE;
        endcase
    end

    // --- Output Assignments ---
    always @(posedge CLK) begin
        if (state == S_DONE) begin
            BCD_H <= hundreds;
            BCD_T <= tens;
            BCD_U <= units;
        end
    end

endmodule
