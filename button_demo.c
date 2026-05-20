#include <stdint.h>

#define LED             (*(volatile uint32_t*)0x02000000)
#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_uart_data   (*(volatile uint32_t*)0x02000008)
#define BUTTONS         (*(volatile uint32_t*)0x02000010)

/* ULX3S 버튼은 액티브 LOW: 누르면 0, 안 누르면 1 */

void putchar(char c) {
    if (c == '\n') putchar('\r');
    reg_uart_data = c;
}

void print(const char *p) {
    while (*p) putchar(*(p++));
}

void print_num(int n) {
    putchar('0' + n);
}

/* 디바운싱: 같은 값이 연속으로 읽힐 때까지 기다림 */
uint32_t read_buttons() {
    uint32_t a, b;
    do {
        a = BUTTONS;
        for (volatile int i = 0; i < 500; i++);
        b = BUTTONS;
    } while (a != b);
    return a & 0x7F;  // btn[6:0]만 사용
}

int main() {
    reg_uart_clkdiv = 217;

    print("\n=== Button Demo ===\n");
    print("버튼을 눌러보세요!\n\n");

    uint32_t prev = read_buttons();

    while (1) {
        uint32_t curr = read_buttons();
        uint32_t changed = curr ^ prev;

        if (changed) {
            /* 변화한 버튼만 체크 */
            for (int i = 1; i <= 6; i++) {
                if ((changed >> i) & 1) {
                    int pressed = !((curr >> i) & 1);  // LOW = 눌림
                    print("BTN");
                    print_num(i);
                    print(pressed ? " 눌림\n" : " 뗌\n");
                }
            }

            /* LED: 눌린 버튼 번호만큼 켜기 */
            uint8_t leds = 0;
            for (int i = 1; i <= 6; i++) {
                if (!((curr >> i) & 1)) leds |= (1 << (i-1));
            }
            LED = leds;

            prev = curr;
        }
    }
}