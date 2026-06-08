"""
PR2040 (Raspberry Pi Pico) + DX-BT37 蓝牙模块
=============================================
双向收发 + 收到字符数闪烁LED

接线:
  BT37 TX  →  Pico GP1  (UART0 RX)
  BT37 RX  →  Pico GP0  (UART0 TX)
  BT37 VCC →  Pico 3.3V
  BT37 GND →  Pico GND
  LED      →  Pico GP25 (板载LED)

BT37 默认串口参数: 9600bps, 8, n, 1

使用方法:
  手机 App 连接 BT37 后，收发数据
  在 Thonny Shell 中输入文字按回车 → 发到手机
  手机发来的数据 → 显示在 Thonny Shell 中
"""

from machine import Pin, UART
import time
import sys
import select

# ===== 配置 ==================================================
UART_ID = 0
BAUDRATE = 9600
LED_PIN = 25
BLINK_MS = 150
MAX_BLINK = 20

# ===== 初始化 ================================================
uart = UART(UART_ID, baudrate=BAUDRATE, tx=Pin(0), rx=Pin(1))
led  = Pin(LED_PIN, Pin.OUT)
led.off()

# USB 标准输入轮询器
usb_poller = select.poll()
usb_poller.register(sys.stdin, select.POLLIN)

print("=" * 45)
print("  PR2040 + BT37 蓝牙通讯已启动")
print(f"  UART: {BAUDRATE}bps 8N1  LED: GP{LED_PIN}")
print("  ─────────────────────────────")
print("  手机 <-蓝牙-> BT37 <-串口-> Pico")
print("  Thonny Shell 输入 -> 发到手机")
print("=" * 45)

# ===== LED 闪烁 ==============================================
def blink(n):
    if n <= 0: return
    if n > MAX_BLINK: n = MAX_BLINK
    for _ in range(n):
        led.on()
        time.sleep_ms(BLINK_MS)
        led.off()
        time.sleep_ms(BLINK_MS)

blink(3)

# ===== 缓冲区 ================================================
uart_buf = b""   # 蓝牙串口接收缓冲区

# ===== 主循环 ================================================
while True:
    # ─── 1. 检查蓝牙 (手机 → BT37 → Pico) ─────────────
    if uart.any():
        chunk = uart.read()
        if chunk:
            uart_buf += chunk
            # 按换行分割处理
            while b"\n" in uart_buf:
                line, uart_buf = uart_buf.split(b"\n", 1)
                line = line.strip()
                if not line:
                    continue

                text = line.decode("utf-8")
                n = len(text)
                print(f"[手机] {text}  ({n}字符)")
                blink(n)

                # 自动回复
                reply = f"Pico收到({n}字符): {text}\r\n"
                uart.write(reply)

    # ─── 2. 检查 USB 串口输入 (Thonny Shell → 手机) ──
    #     select.poll() 非阻塞检查，0 超时 = 立即返回
    if usb_poller.poll(0):
        usb_line = sys.stdin.readline()
        if usb_line:
            usb_line = usb_line.strip()
            if usb_line:
                # 发送到蓝牙 → 手机
                uart.write((usb_line + "\r\n").encode())
                print(f"[Thonny→手机] {usb_line}")

    time.sleep_ms(5)
