"""
PR2040 + BT37 蓝牙模块 - 进阶版
================================
功能:
  1. 手机App ↔ BT37 ↔ PR2040 双向收发
  2. 收到消息: 按字符数闪烁LED + 自动回复
  3. AT 命令透传 (通过蓝牙发 AT 指令给 BT37 模块)
  4. 定时上报状态

指令系统 (从手机发送):
  #help     - 显示帮助
  #info     - 查询 Pico 信息
  #blink N  - LED 闪烁 N 次
  #at XYZ   - 透传 AT 指令给 BT37 模块
  #reply on/off - 开关自动回复
  #name xxx - 修改 BT37 蓝牙名
  #reset    - 重启 BT37 模块
"""

from machine import Pin, UART
import time, sys

# ===== 配置 ==================================================
UART_ID = 0
BAUDRATE = 9600
LED_PIN = 25
BLINK_MS = 150
MAX_BLINK = 30

# ===== 初始化 ================================================
uart = UART(UART_ID, baudrate=BAUDRATE, tx=Pin(0), rx=Pin(1))
led  = Pin(LED_PIN, Pin.OUT)
led.off()

auto_reply = True
buf = b""  # UART 接收缓冲区

def blink(n):
    n = min(n, MAX_BLINK)
    for _ in range(n):
        led.on()
        time.sleep_ms(BLINK_MS)
        led.off()
        time.sleep_ms(BLINK_MS)

def send_to_phone(text):
    """通过 BT37 发送文本到手机"""
    uart.write((text + "\r\n").encode("utf-8"))

def info_str():
    import machine
    import uos
    return (
        f"Pico RP2040\r\n"
        f"频率: {machine.freq() // 1000000}MHz\r\n"
        f"固件: {uos.uname().version}\r\n"
        f"UART: {BAUDRATE}bps 8N1\r\n"
        f"LED: GP{LED_PIN}"
    )

def process_command(cmd: str):
    """处理来自手机的命令"""
    global auto_reply
    parts = cmd.strip().split(maxsplit=1)
    instruction = parts[0].lower()
    arg = parts[1] if len(parts) > 1 else ""

    if instruction == "#help":
        send_to_phone(
            "可用指令:\r\n"
            "  #help        - 显示本帮助\r\n"
            "  #info        - Pico 信息\r\n"
            "  #blink N     - LED闪烁N次\r\n"
            "  #at <CMD>    - 透传AT指令给BT37\r\n"
            "  #reply on/off - 自动回复开关\r\n"
            "  #name <NAME> - 修改BT37蓝牙名\r\n"
            "  #reset       - 重启BT37"
        )
    elif instruction == "#info":
        send_to_phone(info_str())
    elif instruction == "#blink":
        try:
            blink(int(arg))
        except:
            send_to_phone("用法: #blink N")
    elif instruction == "#at":
        if arg:
            uart.write((arg + "\r\n").encode())
            time.sleep_ms(500)
            if uart.any():
                resp = uart.read().decode("utf-8")
                send_to_phone(f"AT回复: {resp.strip()}")
            else:
                send_to_phone("AT无回复 (确认模块处于命令模式)")
        else:
            send_to_phone("用法: #at <AT指令>, 如 #at AT+VERSION")
    elif instruction == "#reply":
        auto_reply = (arg == "on")
        send_to_phone(f"自动回复: {'开' if auto_reply else '关'}")
    elif instruction == "#name":
        if arg:
            uart.write(f"AT+NAME{arg}\r\n".encode())
            time.sleep_ms(300)
            uart.write(b"AT+RESET\r\n")
            send_to_phone(f"改名 {arg} 并重启中...")
        else:
            send_to_phone("用法: #name BT37")
    elif instruction == "#reset":
        uart.write(b"AT+RESET\r\n")
        send_to_phone("BT37 重启中...")
    else:
        send_to_phone(f"未知指令: {instruction}  (发送 #help 查看帮助)")

# ===== 启动 ================================================
blink(2)
send_to_phone("")
send_to_phone("=== PR2040 + BT37 就绪 ===")
send_to_phone('发送 #help 查看指令')

# ===== 主循环 ================================================
while True:
    # 读取 UART（手机→BT37→Pico）
    if uart.any():
        raw = uart.read()
        if raw:
            buf += raw
            # 按换行分割处理
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                line = line.strip()
                if not line:
                    continue

                text = line.decode("utf-8")
                n = len(text)

                print(f"[收] {text}")

                # LED 闪烁
                blink(n)

                # 判断是否命令
                if text.startswith("#"):
                    process_command(text)
                elif auto_reply:
                    reply = f"Pico: 收到{n}字符 -> {text}\r\n"
                    uart.write(reply.encode())
                    print(f"[发] {reply.strip()}")

    # USB 串口输入转发到手机（Thonny/PuTTY 输入）
    # 取消注释以下代码启用 USB→蓝牙转发
    """
    import select
    if select.select([sys.stdin], [], [], 0)[0]:
        usb_line = sys.stdin.readline().strip()
        if usb_line:
            uart.write((usb_line + "\r\n").encode())
            print(f"[USB→蓝牙] {usb_line}")
    """

    time.sleep_ms(5)
