/*
 *  ECP5 PicoRV32 demo
 *  Copyright (C) 2017  Clifford Wolf <clifford@clifford.at>
 *  Copyright (C) 2018  David Shah <dave@ds0.me>
 *
 *  [버튼 페리페럴 추가 - 2026.05]
 *  0x02000010 : 버튼 입력 레지스터 (읽기 전용, btn[6:0])
 *
 *  [타이머 + IRQ 추가 - 2026.05]
 *  0x02000014 : 타이머 카운터 (읽기 전용, 32비트)
 *  0x02000018 : 타이머 비교값 (읽기/쓰기, 쓰면 IRQ 클리어 + 타이머 리셋)
 *
 *  IRQ 구조:
 *  irq[0] = 타이머 인터럽트 (counter == compare 일 때 발생)
 *  PROGADDR_IRQ = 0x00000010
 */

`define PICORV32_REGS picosoc_regs

module attosoc (
	input clk,
	input reset_n,
	output reg [7:0] led,
	input [6:0] btn,        // 버튼 입력 포트
	output uart_tx,
	input uart_rx
);
	wire break;
	reg [5:0] reset_cnt = 0;
	wire resetn = &reset_cnt;
	wire resetncpu = resetn & !break;

	always @(posedge clk) begin
		if (reset_n == 0)
			reset_cnt <= 0;
		else
			reset_cnt <= reset_cnt + !resetn;
	end

	parameter integer MEM_WORDS = 8192;
	parameter [31:0] STACKADDR = 32'h 0000_0000 + (4*MEM_WORDS);
	parameter [31:0] PROGADDR_RESET = 32'h 0000_0000;
	parameter [31:0] PROGADDR_IRQ   = 32'h 0000_0010;  // ★ IRQ 핸들러 주소

	reg [31:0] ram [0:MEM_WORDS-1];
	initial $readmemh("firmware.hex", ram);
	reg [31:0] ram_rdata;
	reg ram_ready;

	wire mem_valid;
	wire mem_instr;
	wire mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0] mem_wstrb;
	wire [31:0] mem_rdata;

	always @(posedge clk) begin
		ram_ready <= 1'b0;
		if (mem_addr[31:24] == 8'h00 && mem_valid) begin
			if (mem_wstrb[0]) ram[mem_addr[23:2]][7:0]   <= mem_wdata[7:0];
			if (mem_wstrb[1]) ram[mem_addr[23:2]][15:8]  <= mem_wdata[15:8];
			if (mem_wstrb[2]) ram[mem_addr[23:2]][23:16] <= mem_wdata[23:16];
			if (mem_wstrb[3]) ram[mem_addr[23:2]][31:24] <= mem_wdata[31:24];

			ram_rdata <= ram[mem_addr[23:2]];
			ram_ready <= 1'b1;
		end
	end

	wire iomem_valid;
	reg iomem_ready;
	wire [31:0] iomem_addr;
	wire [31:0] iomem_wdata;
	wire [3:0] iomem_wstrb;
	wire [31:0] iomem_rdata;

	assign iomem_valid = mem_valid && (mem_addr[31:24] > 8'h 01);
	assign iomem_wstrb = mem_wstrb;
	assign iomem_addr  = mem_addr;
	assign iomem_wdata = mem_wdata;

	wire        simpleuart_reg_div_sel = mem_valid && (mem_addr == 32'h 0200_0004);
	wire [31:0] simpleuart_reg_div_do;

	wire        simpleuart_reg_dat_sel = mem_valid && (mem_addr == 32'h 0200_0008);
	wire [31:0] simpleuart_reg_dat_do;
	wire simpleuart_reg_dat_wait;

	// 버튼 레지스터 (0x02000010, 읽기 전용)
	wire        btn_reg_sel = mem_valid && (mem_addr == 32'h 0200_0010);
	wire [31:0] btn_reg_do  = {25'b0, btn};   // btn[6:0]을 하위 7비트에

	// ★ 타이머 레지스터 (0x02000014: counter, 0x02000018: compare)
	reg [31:0] timer_cnt = 0;
	reg [31:0] timer_cmp = 0;
	reg        timer_irq = 0;

	wire timer_cnt_sel = mem_valid && (mem_addr == 32'h 0200_0014);
	wire timer_cmp_sel = mem_valid && (mem_addr == 32'h 0200_0018);

	// ★ IRQ / EOI 신호
	wire [31:0] irq;
	wire [31:0] eoi;
	assign irq = {31'b0, timer_irq};   // irq[0] = 타이머

	// IO 레지스터 처리 (LED 쓰기 / 타이머 비교값 쓰기 / 타이머 카운터 동작)
	always @(posedge clk) begin
		iomem_ready <= 1'b0;

		// 타이머 카운터 항상 증가
		timer_cnt <= timer_cnt + 1;

		// 카운터가 비교값에 도달하면 IRQ 발생 + 카운터 리셋
		if (timer_cmp != 0 && timer_cnt == timer_cmp) begin
			timer_irq <= 1'b1;
			timer_cnt <= 32'b0;
		end

		// EOI로 IRQ 클리어 (CPU가 인터럽트 처리 완료 시 자동 신호)
		if (eoi[0])
			timer_irq <= 1'b0;

		// LED 쓰기 (0x02000000)
		if (iomem_valid && iomem_wstrb[0] && mem_addr == 32'h 02000000) begin
			led <= iomem_wdata[7:0];
			iomem_ready <= 1'b1;
		end

		// 타이머 비교값 쓰기 (0x02000018) — 쓰면 카운터/IRQ도 리셋
		if (iomem_valid && iomem_wstrb[0] && mem_addr == 32'h 02000018) begin
			timer_cmp <= iomem_wdata;
			timer_cnt <= 32'b0;
			timer_irq <= 1'b0;
			iomem_ready <= 1'b1;
		end
	end

	assign mem_ready = (iomem_valid && iomem_ready) ||
	                   simpleuart_reg_div_sel ||
	                   (simpleuart_reg_dat_sel && !simpleuart_reg_dat_wait) ||
	                   btn_reg_sel       ||   // 버튼 읽기
	                   timer_cnt_sel     ||   // ★ 타이머 카운터 읽기
	                   timer_cmp_sel     ||   // ★ 타이머 비교값 읽기
	                   ram_ready;

	assign mem_rdata = simpleuart_reg_div_sel ? simpleuart_reg_div_do :
	                   simpleuart_reg_dat_sel ? simpleuart_reg_dat_do :
	                   btn_reg_sel            ? btn_reg_do             :
	                   timer_cnt_sel          ? timer_cnt              :   // ★
	                   timer_cmp_sel          ? timer_cmp              :   // ★
	                   ram_rdata;

	picorv32 #(
		.STACKADDR(STACKADDR),
		.PROGADDR_RESET(PROGADDR_RESET),
		.PROGADDR_IRQ(PROGADDR_IRQ),      // ★ 0x00000010
		.BARREL_SHIFTER(0),
		.COMPRESSED_ISA(0),
		.ENABLE_MUL(0),
		.ENABLE_DIV(0),
		.ENABLE_IRQ(1),                   // ★ IRQ 활성화
		.ENABLE_IRQ_QREGS(1)              // ★ IRQ 전용 레지스터 (자동 저장/복원)
	) cpu (
		.clk         (clk        ),
		.resetn      (resetncpu  ),
		.mem_valid   (mem_valid  ),
		.mem_instr   (mem_instr  ),
		.mem_ready   (mem_ready  ),
		.mem_addr    (mem_addr   ),
		.mem_wdata   (mem_wdata  ),
		.mem_wstrb   (mem_wstrb  ),
		.mem_rdata   (mem_rdata  ),
		.irq         (irq        ),       // ★ IRQ 입력
		.eoi         (eoi        )        // ★ EOI 출력 (인터럽트 처리 완료)
	);

	simpleuart simpleuart (
		.clk         (clk         ),
		.resetn      (resetn      ),

		.ser_tx      (uart_tx     ),
		.ser_rx      (uart_rx     ),
		.break       (break       ),

		.reg_div_we  (simpleuart_reg_div_sel ? mem_wstrb : 4'b 0000),
		.reg_div_di  (mem_wdata),
		.reg_div_do  (simpleuart_reg_div_do),

		.reg_dat_we  (simpleuart_reg_dat_sel ? mem_wstrb[0] : 1'b 0),
		.reg_dat_re  (simpleuart_reg_dat_sel && !mem_wstrb),
		.reg_dat_di  (mem_wdata),
		.reg_dat_do  (simpleuart_reg_dat_do),
		.reg_dat_wait(simpleuart_reg_dat_wait)
	);

endmodule

module picosoc_regs (
	input clk, wen,
	input [5:0] waddr,
	input [5:0] raddr1,
	input [5:0] raddr2,
	input [31:0] wdata,
	output [31:0] rdata1,
	output [31:0] rdata2
);
	reg [31:0] regs [0:31];

	always @(posedge clk)
		if (wen) regs[waddr[4:0]] <= wdata;

	assign rdata1 = regs[raddr1[4:0]];
	assign rdata2 = regs[raddr2[4:0]];
endmodule
