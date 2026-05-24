/*
 * multitask.c -- PicoRV32 preemptive multitask demo
 *
 * Two tasks, switched every TIMER_PERIOD cycles (0.5 sec):
 *   Task A: LED binary counter (0x00 -> 0xFF, repeating)
 *   Task B: UART prints "[B] n=N" in a loop
 *
 * Context frame layout (must match start_multitask.s):
 *   word  0 (offset   0): PC
 *   word  1 (offset   4): x1  ra
 *   word  2 (offset   8): x2  sp (original, before frame alloc)
 *   word  3 (offset  12): x3  gp
 *   ...
 *   word 31 (offset 124): x31 t6
 */

#include <stdint.h>

/* ---- registers ----------------------------------------- */
#define REG_LED       (*(volatile uint32_t *)0x02000000)
#define REG_UART_DIV  (*(volatile uint32_t *)0x02000004)
#define REG_UART_DATA (*(volatile uint32_t *)0x02000008)
#define REG_TIMER_CMP (*(volatile uint32_t *)0x02000018)
#define REG_BTN       (*(volatile uint32_t *)0x02000010)

#define UART_BAUD_DIV  217
#define CLOCK_HZ       25000000UL
#define TIMER_PERIOD   (CLOCK_HZ / 50)  /* 20 ms */

/* ---- external (start_multitask.s) ---------------------- */
extern uint32_t maskirq(uint32_t mask);
extern void     start_first_task(void);

/* ---- UART ---------------------------------------------- */
static void uart_putchar(char c)
{
    if (c == '\n') uart_putchar('\r');
    while (REG_UART_DATA & 0x100);
    REG_UART_DATA = (uint8_t)c;
}
static void uart_puts(const char *s) { while (*s) uart_putchar(*s++); }
static void uart_putuint(uint32_t v)
{
    if (v == 0) { uart_putchar('0'); return; }
    char buf[10]; int i = 0;
    while (v) { buf[i++] = '0' + (v % 10); v /= 10; }
    while (i--) uart_putchar(buf[i]);
}

/* ---- TCB & stacks -------------------------------------- */
#define STACK_WORDS  256        /* 1 KB per task */

typedef struct { uint32_t sp; } TCB;

TCB      tasks[2];              /* referenced by start_multitask.s */
volatile int current_task = 0;

static uint32_t task0_stack[STACK_WORDS];
static uint32_t task1_stack[STACK_WORDS];

/* ---- task_init ----------------------------------------
 * Build an initial context frame at the top of the stack
 * so the task can be "resumed" for the first time just like
 * any interrupted task.
 */
static void task_init(int id, void (*func)(void),
                      uint32_t *stack_top)
{
    /* 33 words below stack_top = 132 bytes */
    uint32_t *frame = stack_top - 33;
    for (int i = 0; i < 33; i++) frame[i] = 0;
    frame[0] = (uint32_t)func;      /* PC  */
    frame[2] = (uint32_t)stack_top; /* original sp */
    tasks[id].sp = (uint32_t)frame;
}

/* ---- schedule -----------------------------------------
 * Called from irq_vec in start_multitask.s.
 * current_sp: context frame base of the interrupted task.
 * Returns:    context frame base of the next task.
 */
uint32_t schedule(uint32_t current_sp)
{
    tasks[current_task].sp = current_sp;
    current_task ^= 1;
    REG_TIMER_CMP = TIMER_PERIOD;   /* reset timer for next slice */
    return tasks[current_task].sp;
}

/* ---- Task A: LED binary counter ----------------------- */
static void task_a(void)
{
    uint8_t led = 0;
    while (1) {
        REG_LED = led++;
        for (volatile uint32_t i = 0; i < 80000; i++);
    }
}

/* ---- Task B: print "taskB!" on button press (edge detect) */
static void task_b(void)
{
    uint32_t btn_prev = 1;   /* 1 = not pressed (active LOW) */
    while (1) {
        uint32_t btn_now = (REG_BTN >> 2) & 1;   /* btn[2] = F1 */
        /* falling edge: 1->0 = button just pressed */
        if (btn_prev == 1 && btn_now == 0) {
            maskirq(0);
            uart_puts("taskB!\n");
            maskirq(0xFFFFFFFE);
            for (volatile uint32_t i = 0; i < 50000; i++); /* debounce 2ms */
        }
        btn_prev = btn_now;
    }
}

/* ---- main --------------------------------------------- */
int main(void)
{
    REG_UART_DIV = UART_BAUD_DIV;
    uart_puts("=== multitask start ===\n");
    uart_puts("Task A: LED counter\n");
    uart_puts("Task B: UART output\n\n");

    task_init(0, task_a, task0_stack + STACK_WORDS);
    task_init(1, task_b, task1_stack + STACK_WORDS);

    REG_TIMER_CMP = TIMER_PERIOD;
    maskirq(0xFFFFFFFE);            /* enable only irq[0] */

    uart_puts("Starting...\n");
    start_first_task();             /* never returns */

    return 0;
}
