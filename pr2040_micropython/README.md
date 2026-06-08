# PR2040 + DX-BT37 蓝牙模块 MicroPython 代码

Raspberry Pi Pico (RP2040) 通过串口连接 DX-BT37 蓝牙模块，
实现手机 App 与 Pico 之间的无线双向数据传输。

---

## 接线

```
BT37 模块                    PR2040 (Raspberry Pi Pico)
┌──────────┐                ┌─────────────────────┐
│  1 TX  ──┼────────────────┼── GP1  (UART0 RX)   │
│  2 RX  ──┼────────────────┼── GP0  (UART0 TX)   │
│  7 VBAT ─┼────────────────┼── 3.3V (Pin 36)     │
│  8 GND  ─┼────────────────┼── GND  (Pin 38)     │
│          │                │                      │
│  6 RST  ─┼── 悬空         │  LED → GP25 (板载)   │
│ 10 KEY  ─┼── 悬空         │                      │
└──────────┘                └─────────────────────┘
```

**关键点:**
- BT37 的 **TX → Pico 的 GP1** (UART0 RX)
- BT37 的 **RX → Pico 的 GP0** (UART0 TX)
- **交叉连接**
- 两者都是 **3.3V** 电平，直连即可

---

## BT37 模块默认参数

| 参数 | 值 |
|------|-----|
| 蓝牙协议 | BLE 5.2 |
| 串口波特率 | **9600** bps |
| 数据位 | 8 |
| 校验位 | 无 (N) |
| 停止位 | 1 |
| 蓝牙名称 | BT37 |
| Service UUID | 0xFFE0 |
| Notify UUID | 0xFFE1 |
| Write UUID | 0xFFE2 |

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `main.py` | **基础版** — 收消息闪烁LED + 自动回复 |
| `main_advanced.py` | **进阶版** — 含指令系统、AT透传、状态查询 |

### 使用哪个？

- **基础版** `main.py`: 简单可靠，适合首次测试
- **进阶版** `main_advanced.py`: 支持手机发指令控制 Pico、修改 BT37 参数

---

## 使用步骤

### 1. 刷写代码到 Pico

1. 将 Pico 通过 USB 连接到电脑，按住 BOOTSEL 键上电
2. 将 `main.py` 或 `main_advanced.py` 复制到 Pico 的存储中（命名为 `main.py`）
3. 也可以用 Thonny IDE 打开并保存到 Pico

### 2. 接线

按上方的接线图连接 BT37 和 Pico

### 3. 上电

- Pico 上电后板载 LED 会闪烁 3 次（或 2 次）表示启动成功
- BT37 模块上电后开始广播，蓝牙名称默认 **BT37**

### 4. 手机 App 连接

打开手机上的 App（选择 **BT37 (FFE0)** UUID 预设）：
1. 搜索 BLE 设备，找到名为 **BT37** 的设备
2. 连接
3. 进入收发界面

### 5. 测试收发

- 手机发送 **"Hello"** → Pico 收到后 LED 闪烁 5 次 → 自动回复 `Pico收到: Hello [5 chars]`
- 手机发送 **"Hi"** → LED 闪烁 2 次

---

## 进阶版指令系统

连接后发送以下指令控制 Pico（以 `#` 开头）：

| 指令 | 功能 | 示例 |
|------|------|------|
| `#help` | 显示帮助 | `#help` |
| `#info` | 查询 Pico 信息 | `#info` |
| `#blink N` | LED 闪烁 N 次 | `#blink 10` |
| `#at <CMD>` | 透传 AT 指令给 BT37 | `#at AT+VERSION` |
| `#reply on/off` | 开关自动回复 | `#reply off` |
| `#name <NAME>` | 修改 BT37 蓝牙名 | `#name MyDevice` |
| `#reset` | 重启 BT37 模块 | `#reset` |

### AT 指令示例

```
手机发送:  #at AT
BT37回复:  OK

手机发送:  #at AT+VERSION
BT37回复:  +VERSION=2.0

手机发送:  #at AT+BAUD7
BT37回复:  +BAUD=7
           OK
(波特率改为 115200，需同时改 Pico 代码中的 BAUDRATE)
```

---

## 注意事项

1. **波特率匹配**: Pico 代码默认 9600，与 BT37 默认一致。如用 AT 命令修改了模块波特率，需同步修改代码中的 `BAUDRATE`
2. **电平一致**: BT37 和 Pico 都是 3.3V，无需电平转换
3. **流控**: 默认不使用 RTS/CTS 硬件流控
4. **供电**: BT37 工作电流约 5mA，Pico 的 3.3V 输出可直接供电
5. **AT 命令模式**: BT37 **未被连接**时处于命令模式，可接收 AT 指令；**连接后**自动进入透传模式，此时 AT 指令无效（除非关闭透传）

---

## 串口调试

如果需要通过 USB 串口（Thonny 的 REPL）手动发送数据给手机：

1. 打开 `main_advanced.py`，取消 `# USB 串口输入转发` 下方的注释
2. 在 Thonny Shell 中输入文字按回车 → 数据会通过 BT37 发送到手机
