/*
 * bench_irq_latency.c -- PicoRV32 IRQ 레이턴시 측정
 *
 * 측정 방법:
 *   1. 타이머 IRQ 발생 → hardware가 timer_cnt를 0으로 리셋
 *   2. schedule()이 호출되는 시점에 REG_TIMER_CNT 읽기
 *   3. 그 값 = IRQ 발생부터 schedule() 진입까지 사이클 수
 *      (= CPU IRQ 레이턴시 + IRQ 벡터 프롤로그 오버헤드)
 *
 * 빌드: build_prog.bat (PROG=bench_irq_latency)
 */

#include <stdint.h>

/* ---- 레지스터 ------------------------------------------ */
#define REG_LED       (*(volatile uint32_t *)0x02000000)
#define REG_UART_DIV  (*(volatile uint32_t *)0x02000004)
#define REG_UART_DATA (*(volatile uint32_t *)0x02000008)
#define REG_TIMER_CNT (*(volatile uint32_t *)0x02000014)
#define REG_TIMER_CMP (*(volatile uint32_t *)0x02000018)

#define UART_DIV     217
#define CLOCK_HZ     25000000UL
#define TIMER_PERIOD (CLOCK_HZ / 50)   /* 20ms */
#define SAMPLES      20                /* 측정 횟수 */

/* start_multitask.s 에서 참조하는 심볼 */
typedef struct { uint32_t sp; } TCB;
TCB      tasks[2];
volatile int current_task = 0;
extern uint32_t maskirq(uint32_t mask);
extern void     start_first_task(void);

/* ---- 측정 데이터 --------------------------------------- */
volatile uint32_t irq_latency[SAMPLES];
volatile int      irq_count = 0;
volatile int      done = 0;

/* ---- UART ---------------------------------------------- */
static void uart_putchar(char c) {
    if (c == '\n') uart_putchar('\r');
    while (REG_UART_DATA & 0x100);
    REG_UART_DATA = (uint8_t)c;
}
static void uart_puts(const char *s)  { while (*s) uart_putchar(*s++); }
static void uart_putuint(uint32_t v) {
    if (v == 0) { uart_putchar('0'); return; }
    char buf[12]; int i = 0;
    while (v) { buf[i++] = '0' + (v % 10); v /= 10; }
    while (i--) uart_putchar(buf[i]);
}

/* ---- schedule() ----------------------------------------
 * start_multitask.s의 IRQ 벡터가 이 함수를 호출.
 * 호출 시점에 timer_cnt = IRQ 발생 이후 경과 사이클.
 *   (attosoc.v: timer_cnt == timer_cmp 시 IRQ 발생 + timer_cnt 리셋)
 */
uint32_t schedule(uint32_t current_sp) {
    /* 첫 번째로 timer_cnt 읽기 — 이게 IRQ 레이턴시 */
    uint32_t lat = REG_TIMER_CNT;

    if (irq_count < SAMPLES) {
        irq_latency[irq_count++] = lat;
        REG_LED = irq_count;        /* LED로 진행 상황 표시 */
    }

    if (irq_count >= SAMPLES) {
        /* 측정 완료 — 타이머 비활성화 */
        REG_TIMER_CMP = 0;
        done = 1;
    } else {
        REG_TIMER_CMP = TIMER_PERIOD;  /* 다음 IRQ 준비 */
    }

    return current_sp;   /* 태스크 전환 없이 원래 스택으로 복귀 */
}

/* ---- 더미 태스크 (실제 실행되지 않음) ------------------ */
static uint32_t dummy_stack[64];
static void dummy_task(void) { while(1); }
static void task_init_dummy(void) {
    uint32_t *frame = (dummy_stack + 64) - 33;
    for (int i = 0; i < 33; i++) frame[i] = 0;
    frame[0] = (uint32_t)dummy_task;
    frame[2] = (uint32_t)(dummy_stack + 64);
    tasks[0].sp = (uint32_t)frame;
    tasks[1].sp = (uint32_t)frame;  /* 두 태스크 모두 같은 더미 */
}

/* ---- main ---------------------------------------------- */
int main(void) {
    REG_UART_DIV = UART_DIV;
    uart_puts("\n=== IRQ 레이턴시 측정 (PicoRV32) ===\n");
    uart_puts("측정: IRQ 발생 -> schedule() 진입까지 사이클\n");
    uart_puts("      (CPU 레이턴시 + 벡터 프롤로그 오버헤드 포함)\n\n");

    task_init_dummy();

    /* 타이머 + IRQ 활성화 */
    REG_TIMER_CMP = TIMER_PERIOD;
    maskirq(0xFFFFFFFE);

    /* 측정 완료까지 대기 */
    while (!done) {
        asm volatile("nop");
    }

    maskirq(0);  /* IRQ 비활성화 */

    /* 결과 출력 */
    uart_puts("--- 측정 결과 ---\n");
    uint32_t sum = 0, min_v = 0xFFFFFFFF, max_v = 0;
    for (int i = 0; i < SAMPLES; i++) {
        uart_puts("  ["); uart_putuint(i+1); uart_puts("] ");
        uart_putuint(irq_latency[i]); uart_puts(" cycles\n");
        sum += irq_latency[i];
        if (irq_latency[i] < min_v) min_v = irq_latency[i];
        if (irq_latency[i] > max_v) max_v = irq_latency[i];
    }

    uart_puts("\n평균: "); uart_putuint(sum / SAMPLES); uart_puts(" cycles\n");
    uart_puts("최소: "); uart_putuint(min_v); uart_puts(" cycles\n");
    uart_puts("최대: "); uart_putuint(max_v); uart_puts(" cycles\n");

    /* ns 변환 (1 cycle = 40ns @ 25MHz) */
    uint32_t avg_ns = (sum / SAMPLES) * 40;
    uart_puts("평균: "); uart_putuint(avg_ns); uart_puts(" ns\n");

    uart_puts("\n=== 완료 ===\n");
    while (1);
    return 0;
}
