/*
 * bench_dhrystone.c -- Dhrystone 2.1 (bare-metal PicoRV32 port)
 *
 * 측정 항목: DMIPS/MHz
 * 공식: DMIPS = (Dhrystones/sec) / 1757
 *       DMIPS/MHz = DMIPS / 25
 *
 * 빌드: build_prog.bat (PROG=bench_dhrystone)
 * 업로드: TeraTerm rv32> 프롬프트에서 .srec 전송
 */

#include <stdint.h>

/* ---- 레지스터 ------------------------------------------ */
#define REG_UART_DIV  (*(volatile uint32_t *)0x02000004)
#define REG_UART_DATA (*(volatile uint32_t *)0x02000008)
#define REG_TIMER_CNT (*(volatile uint32_t *)0x02000014)
#define REG_TIMER_CMP (*(volatile uint32_t *)0x02000018)

#define UART_DIV      217
#define CLOCK_HZ      25000000UL
#define ITERATIONS    2000      /* 반복 횟수 (더 늘리면 정확도 향상) */

/* start_multitask.s가 참조하는 심볼 (더미) */
uint32_t schedule(uint32_t sp) { return sp; }
typedef struct { uint32_t sp; } TCB;
TCB tasks[2];
volatile int current_task = 0;
extern uint32_t maskirq(uint32_t mask);

/* ---- UART ---------------------------------------------- */
static void uart_putchar(char c) {
    if (c == '\n') uart_putchar('\r');
    while (REG_UART_DATA & 0x100);
    REG_UART_DATA = (uint8_t)c;
}
static void uart_puts(const char *s) { while (*s) uart_putchar(*s++); }
static void uart_putuint(uint32_t v) {
    if (v == 0) { uart_putchar('0'); return; }
    char buf[12]; int i = 0;
    while (v) { buf[i++] = '0' + (v % 10); v /= 10; }
    while (i--) uart_putchar(buf[i]);
}
static void uart_putdec2(uint32_t a, uint32_t b, int digits) {
    /* a.b 형식 출력 (b는 소수부 분자, digits는 소수 자리수) */
    uart_putuint(a);
    uart_putchar('.');
    /* b를 digits 자리로 출력 (앞에 0 채우기) */
    char buf[8]; int i = 0;
    for (int d = 0; d < digits; d++) {
        buf[i++] = '0' + (b % 10);
        b /= 10;
    }
    for (int j = i-1; j >= 0; j--) uart_putchar(buf[j]);
}

/* ---- 최소 문자열 함수 ----------------------------------- */
static void my_strcpy(char *dst, const char *src) {
    while ((*dst++ = *src++));
}
static int my_strcmp(const char *a, const char *b) {
    while (*a && (*a == *b)) { a++; b++; }
    return (unsigned char)*a - (unsigned char)*b;
}

/* ---- Dhrystone 2.1 데이터 구조 ------------------------- */
typedef enum { Ident1, Ident2, Ident3, Ident4, Ident5 } Enumeration;

typedef struct Record {
    struct Record *PtrComp;
    Enumeration    Discr;
    union {
        struct { Enumeration EnumComp; int IntComp; char StrComp[31]; } var1;
        struct { Enumeration EnumComp2; char StrComp2[31]; } var2;
        struct { char Ch1Comp; char Ch2Comp; } var3;
    } variant;
} RecordType, *RecordPtr;

typedef int     OneToThirty;
typedef int     OneToFifty;
typedef char    CapitalLetter;
typedef char    String30[31];
typedef int     Array1Dim[51];
typedef int     Array2Dim[51][51];

/* グローバル変数 */
RecordType  GlobSt1, GlobSt2;
RecordPtr   GlobPtr1 = &GlobSt1;
RecordPtr   GlobPtr2 = &GlobSt2;
int         GlobInt1, GlobInt2, GlobInt3;
char        GlobChar;
int         GlobBool;
String30    GlobStr1, GlobStr2;
Array1Dim   IntArr1;
Array2Dim   IntArr2;

/* ---- 전방 선언 ----------------------------------------- */
static void Proc3(RecordPtr *PtrParOut);
static void Proc1(RecordPtr PtrParIn);

/* ---- Dhrystone 프로시저들 ------------------------------ */
static int Func1(CapitalLetter Ch1, CapitalLetter Ch2) {
    CapitalLetter Loc1, Loc2;
    Loc1 = Ch1;
    Loc2 = Loc1;
    if (Loc2 != Ch2) return Ident1;
    else             return Ident2;
}

static int Func2(String30 StrPar1, String30 StrPar2) {
    OneToThirty  IntLoc = 2;
    CapitalLetter CharLoc;
    while (IntLoc <= 2) {
        if (Func1(StrPar1[IntLoc], StrPar2[IntLoc+1]) == Ident1) {
            CharLoc = 'A';
            IntLoc++;
        }
    }
    if (CharLoc >= 'W' && CharLoc < 'Z') IntLoc = 7;
    if (CharLoc == 'R')
        return 1;
    else {
        if (my_strcmp(StrPar1, StrPar2) > 0) { IntLoc = 1; return 1; }
        else                                  { return 0; }
    }
}

static int Func3(Enumeration EnumParIn) {
    Enumeration EnumLoc = EnumParIn;
    if (EnumLoc == Ident3) return 1;
    return 0;
}

static void Proc6(Enumeration EnumParIn, Enumeration *EnumParOut) {
    *EnumParOut = EnumParIn;
    if (!Func3(EnumParIn)) *EnumParOut = Ident4;
    switch (EnumParIn) {
        case Ident1: *EnumParOut = Ident1; break;
        case Ident2: if (GlobInt1 > 100) *EnumParOut = Ident1; else *EnumParOut = Ident4; break;
        case Ident3: *EnumParOut = Ident2; break;
        case Ident4: break;
        case Ident5: *EnumParOut = Ident3; break;
    }
}

static void Proc7(OneToFifty IntPar1, OneToFifty IntPar2, OneToFifty *IntParOut) {
    OneToFifty IntLoc = IntPar1 + 2;
    *IntParOut = IntPar2 + IntLoc;
}

static void Proc8(Array1Dim ArrPar1, Array2Dim ArrPar2,
                  OneToFifty IntPar1, OneToFifty IntPar2) {
    OneToFifty IntLoc = IntPar1 + 5;
    ArrPar1[IntLoc] = IntPar2;
    ArrPar1[IntLoc+1] = ArrPar1[IntLoc];
    ArrPar1[IntLoc+30] = IntLoc;
    for (OneToFifty IntIdx = IntLoc; IntIdx <= IntLoc+1; IntIdx++)
        ArrPar2[IntLoc][IntIdx] = IntLoc;
    ArrPar2[IntLoc][IntLoc-1]++;
    ArrPar2[IntLoc+1][IntLoc] = ArrPar1[IntLoc];
    GlobInt1 = 5;
}

static void Proc1(RecordPtr PtrParIn) {
    RecordPtr NextPtr = PtrParIn->PtrComp;
    *PtrParIn->PtrComp = *GlobPtr1;
    PtrParIn->variant.var1.IntComp = 5;
    NextPtr->variant.var1.IntComp = PtrParIn->variant.var1.IntComp;
    NextPtr->PtrComp = PtrParIn->PtrComp;
    Proc3(&NextPtr->PtrComp);
    if (NextPtr->Discr == Ident1) {
        NextPtr->variant.var1.IntComp = 6;
        Proc6(PtrParIn->variant.var1.EnumComp, &NextPtr->variant.var1.EnumComp);
        NextPtr->PtrComp = GlobPtr1->PtrComp;
        Proc7(NextPtr->variant.var1.IntComp, 10, &NextPtr->variant.var1.IntComp);
    } else {
        *PtrParIn = *PtrParIn->PtrComp;
    }
}

static void Proc2(OneToFifty *IntParIO) {
    OneToFifty IntLoc = *IntParIO + 10;
    CapitalLetter CharLoc;
    do {
        CharLoc = GlobStr1[IntLoc - 1];
        if (CharLoc == 'A') { IntLoc--; *IntParIO = IntLoc - GlobInt1; GlobBool = 1; }
    } while (CharLoc != 'A');
}

static void Proc3(RecordPtr *PtrParOut) {
    if (GlobPtr1 != 0) *PtrParOut = GlobPtr1->PtrComp;
    else               GlobInt1 = 100;
    Proc7(10, GlobInt1, &GlobPtr1->variant.var1.IntComp);
}

static void Proc4(void) {
    int BoolLoc = GlobChar == 'A';
    BoolLoc |= GlobBool;
    GlobChar = 'B';
}

static void Proc5(void) {
    GlobChar = 'A';
    GlobBool = 0;
}

/* ---- 타이머 유틸 --------------------------------------- */
static uint32_t timer_start(void) {
    REG_TIMER_CMP = 0xFFFFFFFF;   /* 카운터 리셋 (최대값으로 비교, IRQ 없음) */
    return REG_TIMER_CNT;
}
static uint32_t timer_elapsed(uint32_t start) {
    return REG_TIMER_CNT - start;
}

/* ---- main ---------------------------------------------- */
int main(void) {
    REG_UART_DIV = UART_DIV;

    uart_puts("\n=== Dhrystone 2.1 Benchmark (PicoRV32) ===\n");
    uart_puts("Config: RV32I, no MUL/DIV, no barrel shifter\n");
    uart_puts("Clock:  25 MHz\n\n");

    /* 초기화 */
    GlobPtr1->PtrComp     = GlobPtr2;
    GlobPtr1->Discr       = Ident1;
    GlobPtr1->variant.var1.EnumComp = Ident3;
    GlobPtr1->variant.var1.IntComp  = 40;
    my_strcpy(GlobPtr1->variant.var1.StrComp, "DHRYSTONE PROGRAM, SOME STRING");
    my_strcpy(GlobStr1, "DHRYSTONE PROGRAM, 1ST STRING");
    my_strcpy(GlobStr2, "DHRYSTONE PROGRAM, 2ND STRING");
    IntArr2[8][7] = 10;

    /* 타이머 리셋 후 시작 */
    REG_TIMER_CMP = 0xFFFFFFFF;
    volatile uint32_t t_start = REG_TIMER_CNT;

    for (int i = 0; i < ITERATIONS; i++) {
        Proc5();
        Proc4();

        OneToFifty IntLoc1 = 2;
        OneToFifty IntLoc2 = 3;
        String30 StrLoc1, StrLoc2;
        my_strcpy(StrLoc1, "DHRYSTONE PROGRAM, 1ST STRING");
        Enumeration EnumLoc;

        IntArr2[8][7] = 10;
        IntLoc2 = IntLoc1;
        IntLoc2++;
        Proc8(IntArr1, IntArr2, IntLoc1, IntLoc2);
        Proc1(GlobPtr1);

        for (char CharIdx = 'A'; CharIdx <= 'B'; CharIdx++) {
            if (EnumLoc == Func1(CharIdx, 'C'))
                Proc6(Ident1, &EnumLoc);
        }

        IntLoc1 = IntLoc1 * IntLoc2;   /* 곱셈 (libgcc) */
        IntLoc2 = IntLoc1 / IntLoc2;   /* 나눗셈 (libgcc) */
        IntLoc2 = 7 * (IntLoc2 - IntLoc1) - IntLoc1;
        Proc2(&IntLoc1);
    }

    uint32_t elapsed = REG_TIMER_CNT - t_start;

    /* 결과 출력 */
    uart_puts("--- 결과 ---\n");
    uart_puts("반복 횟수  : "); uart_putuint(ITERATIONS); uart_puts("\n");
    uart_puts("총 사이클  : "); uart_putuint(elapsed);    uart_puts(" cycles\n");

    uint32_t cycles_per_iter = elapsed / ITERATIONS;
    uart_puts("사이클/반복: "); uart_putuint(cycles_per_iter); uart_puts(" cycles\n");

    /* Dhrystones/sec = ITERATIONS / (elapsed / CLOCK_HZ)
     *                = ITERATIONS * CLOCK_HZ / elapsed */
    /* 오버플로 방지: 1000배 스케일로 계산 */
    uint32_t dps_k = ((uint32_t)ITERATIONS * (CLOCK_HZ / 1000)) / elapsed;  /* Dhrystones/sec / 1000 */
    uart_puts("Dhrystone/s: "); uart_putuint(dps_k * 1000); uart_puts("\n");

    /* DMIPS = dps / 1757 */
    uint32_t dmips_int  = (dps_k * 1000) / 1757;
    uint32_t dmips_frac = ((dps_k * 1000) % 1757) * 100 / 1757;
    uart_puts("DMIPS      : "); uart_putuint(dmips_int);
    uart_putchar('.'); uart_putuint(dmips_frac); uart_puts("\n");

    /* DMIPS/MHz = DMIPS / 25 */
    uint32_t dmips_mhz_int  = dmips_int / 25;
    uint32_t dmips_mhz_frac = (dmips_int % 25) * 100 / 25;
    uart_puts("DMIPS/MHz  : "); uart_putuint(dmips_mhz_int);
    uart_putchar('.'); uart_putuint(dmips_mhz_frac); uart_puts("\n");

    uart_puts("\n=== 완료 ===\n");
    while (1);
    return 0;
}
