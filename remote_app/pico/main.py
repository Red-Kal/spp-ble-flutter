"""
PR2040 + BT37 遥控开关
=====================
手机 App → BT37 → Pico → MOS 模块

接线:
  BT37 TX  →  Pico GP1  (UART0 RX)
  BT37 RX  →  Pico GP0  (UART0 TX)
  BT37 VCC →  Pico 3V3
  BT37 GND →  Pico GND

  MOS 模块 EN →  Pico GP5  (输出高电平导通)

BT37 默认: 9600bps, 8, n, 1
"""

from machine import Pin, UART
import time

# ===== 配置 ==================================================
UART_ID = 0
BAUDRATE = 9600

# MOS 模块使能引脚
MOS_PIN = 5

# 指令定义
CMD_ON  = b"ON"    # 导通
CMD_OFF = b"OFF"   # 断开

# ===== 初始化 ================================================
uart = UART(UART_ID, baudrate=BAUDRATE, tx=Pin(0), rx=Pin(1))
mos  = Pin(MOS_PIN, Pin.OUT)
mos.value(0)  # 初始断开

# 板载 LED 指示
led  = Pin(25, Pin.OUT)
led.value(0)

print("=" * 40)
print("PR2040 + BT37 遥控开关")
print(f"MOS 使能引脚: GP{MOS_PIN}")
print("等待指令: ON=导通, OFF=断开")
print("=" * 40)

# 开机闪烁 2 次
for _ in range(2):
    led.on()
    time.sleep_ms(100)
    led.off()
    time.sleep_ms(100)

# ===== 缓冲区 ================================================
buf = b""
last_recv = 0

# ===== 主循环 ================================================
while True:
    now = time.ticks_ms()

    if uart.any():
        chunk = uart.read()
        if chunk:
            buf += chunk
            last_recv = now

            # 按换行处理
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                line = line.strip()
                if not line:
                    continue

                if line == CMD_ON:
                    mos.value(1)
                    led.on()
                    print("[指令] 导通 MOS")
                    uart.write(b"MOS ON\r\n")

                elif line == CMD_OFF:
                    mos.value(0)
                    led.off()
                    print("[指令] 断开 MOS")
                    uart.write(b"MOS OFF\r\n")

                else:
                    print(f"[未知] {line}")

    # 超时兜底（不带换行的数据）
    if buf and (now - last_recv > 200):
        line = buf.strip()
        buf = b""
        if line == CMD_ON:
            mos.value(1)
            led.on()
            print("[指令] 导通 MOS")
        elif line == CMD_OFF:
            mos.value(0)
            led.off()
            print("[指令] 断开 MOS")

    time.sleep_ms(10)
