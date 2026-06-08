"""
PR2040 (Raspberry Pi Pico) + DX-BT37 蓝牙模块
=============================================
双向收发 + 收到字符数闪烁LED

接线:
  BT37 TX  →  Pico GP1  (UART0 RX)
  BT37 RX  →  Pico GP0  (UART0 TX)
  BT37 VCC →  Pico 3.3V
  BT37 GND →  Pico GND
  LED      →  Pico GP25 (板载LED) 或 外接LED+电阻

BT37 默认串口参数: 9600bps, 8, n, 1
"""

from machine import Pin, UART, Timer
import time

# ===== 配置 ==================================================
UART_ID = 0          # UART0: GP0=TX, GP1=RX
BAUDRATE = 9600      # BT37 默认波特率
LED_PIN = 25         # Pico 板载 LED (GP25)
BLINK_DELAY_MS = 150 # 每次闪烁的间隔(毫秒)
MAX_BLINK = 20       # 最多闪烁次数(防止太多字符闪太久)

# ===== 初始化 ================================================
uart = UART(UART_ID, baudrate=BAUDRATE, tx=Pin(0), rx=Pin(1))
led  = Pin(LED_PIN, Pin.OUT)
led.value(0)  # 初始熄灭

print("=" * 40)
print("PR2040 + BT37 蓝牙通讯已启动")
print(f"UART: {BAUDRATE}bps, 8N1")
print(f"LED: GP{LED_PIN}")
print("=" * 40)

# ===== LED 闪烁函数 ==========================================
def blink(count: int):
    """LED 闪烁 count 次"""
    if count <= 0:
        return
    if count > MAX_BLINK:
        count = MAX_BLINK
    for _ in range(count):
        led.value(1)
        time.sleep_ms(BLINK_DELAY_MS)
        led.value(0)
        time.sleep_ms(BLINK_DELAY_MS)

# ===== 启动提示（开机闪3次）===================================
blink(3)

# ===== 主循环 ================================================
while True:
    # ----- 检查是否有从手机发来的数据 -----
    if uart.any():
        raw = uart.read()          # 读取全部可用数据
        if raw is None or len(raw) == 0:
            continue

        text = raw.decode("utf-8").strip()
        char_count = len(text)

        print(f"\n[收到] ({char_count}字符): {text}")

        # 1. 根据字符数闪烁 LED
        blink(char_count)

        # 2. 自动回复（回声 + 字符数统计）
        reply = f"Pico收到: {text}  [{char_count} chars]\r\n"
        uart.write(reply)
        print(f"[发送] {reply.strip()}")

    # ----- 检查是否有串口输入（调试/手动发送）-----
    # 如果需要通过 USB 串口（REPL）发送数据给手机，
    # 可在 PuTTY / Thonny 等工具中输入:
    #   输入内容按回车 -> 发送给手机
    #
    # 取消下面注释可启用 USB 输入转发:
    # import sys
    # if sys.stdin in select.select([sys.stdin], [], [], 0)[0]:
    #     line = sys.stdin.readline().strip()
    #     if line:
    #         uart.write(line + "\r\n")
    #         print(f"[USB→蓝牙] {line}")

    time.sleep_ms(10)  # 避免 CPU 空转
