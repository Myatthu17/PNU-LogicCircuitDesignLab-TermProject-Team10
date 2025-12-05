module traffic_light(
    input clk,
    input rst,
    input mode,
    input pulse,        // trigger ???? ???
    output reg [3:0] r,
    output reg [3:0] g,
    output reg [3:0] b
);

    parameter RST_S  = 2'b00;
    parameter RED    = 2'b01;
    parameter GREEN  = 2'b10;
    parameter YELLOW = 2'b11;

    reg [1:0] state;
    reg [19:0] count;

    wire one_sec = (count == 999_999);

    // 1? ???
    always @(posedge clk or posedge rst) begin
        if (rst)
            count <= 0;
        else if (mode == 0) begin // ????? ?? ???
            if (one_sec)
                count <= 0;
            else
                count <= count + 1;
        end else
            count <= 0;
    end

    // ?? ??
    always @(posedge clk or posedge rst) begin
        if (rst)
            state <= RST_S;
        else begin
            case (state)
                RST_S:  state <= RED;
                RED:    if ((mode==0 && one_sec) || (mode==1 && pulse)) state <= GREEN;
                GREEN:  if ((mode==0 && one_sec) || (mode==1 && pulse)) state <= YELLOW;
                YELLOW: if ((mode==0 && one_sec) || (mode==1 && pulse)) state <= RED;
                default: state <= RST_S;
            endcase
        end
    end

    // ??
    always @(*) begin
        case (state)
            RST_S:  {r,g,b} = 12'b0000_0000_0000;
            RED:    {r,g,b} = 12'b1111_0000_0000;
            GREEN:  {r,g,b} = 12'b0000_1111_0000;
            YELLOW: {r,g,b} = 12'b1111_1111_0000;
            default:{r,g,b} = 12'b0000_0000_0000;
        endcase
    end

endmodule