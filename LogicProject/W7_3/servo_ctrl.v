module servo_ctrl (
    input  wire clk,       // 10kHz 시스템 클럭 (주기 100us)
    input  wire rst,       // 리셋 (1=리셋)
    input  wire l_ctrl,    // 왼쪽(0°) 제어
    input  wire r_ctrl,    // 오른쪽(180°) 제어
    output reg  servo      // 서보모터 제어 PWM 출력
);

    // === 파라미터 정의 (10kHz 기준) ===
    localparam integer PERIOD_MAX  = 200; // 20ms (주기)
    localparam integer PULSE_LEFT  = 7;   // 0.7ms → 0°
    localparam integer PULSE_MID   = 15;  // 1.5ms → 90°
    localparam integer PULSE_RIGHT = 23;  // 2.3ms → 180°

    // === 내부 레지스터 ===
    reg [7:0] period_cnt;   // 주기 카운터 (0~199)
    reg [7:0] pulse_width;  // 현재 펄스 폭 설정

    // === 제어 입력에 따른 펄스폭 결정 ===
    always @(*) begin
        if (rst)
            pulse_width = PULSE_MID;     // reset 시 중앙 위치로 복귀
        else if (r_ctrl)
            pulse_width = PULSE_RIGHT;   // 오른쪽
        else if (l_ctrl)
            pulse_width = PULSE_LEFT;    // 왼쪽
        else
            pulse_width = PULSE_MID;     // 중앙
    end

    // === 메인 동작 (비동기 리셋) ===
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            period_cnt <= 8'd0;
            servo <= 1'b0;               // servo 출력 초기화
        end else begin
            // 0~199 반복 카운터
            if (period_cnt == PERIOD_MAX - 1)
                period_cnt <= 8'd0;
            else
                period_cnt <= period_cnt + 1'b1;

            // 펄스폭 만큼 high 출력
            if (period_cnt < pulse_width)
                servo <= 1'b1;
            else
                servo <= 1'b0;
        end
    end

endmodule
