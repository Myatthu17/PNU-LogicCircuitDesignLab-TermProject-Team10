module stepmotor_ctrl (
    input clk,
    input rst,
    input [2:0] dip,
    output reg [3:0] stepmotor,
    output reg [1:0] state
);

reg [1:0] step_count; // 2-bit counter for step sequence

always @(posedge clk or posedge rst) begin
    if (rst) begin
        step_count <= 2'b00;
        stepmotor  <= 4'b0000;
        state      <= 2'b00;
    end else begin
        step_count <= step_count + 1'b1; // step change per clock

        // DIP ??? ?? ?? ??
        if (dip < 4) begin
            // ?? ??
            state <= 2'b00;
            case (step_count)
                2'b00: stepmotor <= 4'b1000;
                2'b01: stepmotor <= 4'b0100;
                2'b10: stepmotor <= 4'b0010;
                2'b11: stepmotor <= 4'b0001;
            endcase
        end else begin
            // ??? ??
            state <= 2'b11; // LED ON ??
            case (step_count)
                2'b00: stepmotor <= 4'b0001;
                2'b01: stepmotor <= 4'b0010;
                2'b10: stepmotor <= 4'b0100;
                2'b11: stepmotor <= 4'b1000;
            endcase
        end
    end
end

endmodule