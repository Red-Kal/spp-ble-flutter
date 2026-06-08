# SPP BLE 蓝牙调试工具 — 完整开发记录

## 项目概述

将旧 Android 项目（SPP_BLE）的蓝牙连接代码移植到 Flutter，创建 Android arm64-v8a 专用 APK，配合 PR2040 (Raspberry Pi Pico) + DX-BT37 蓝牙模块实现手机与单片机双向无线通信。

---

## 目录

1. [环境搭建与项目初始化](#1-环境搭建与项目初始化)
2. [旧项目分析与清理](#2-旧项目分析与清理)
3. [Flutter 项目移植](#3-flutter-项目移植)
4. [Git 版本控制与远程仓库](#4-git-版本控制与远程仓库)
5. [BT37 模块适配](#5-bt37-模块适配)
6. [发送失败问题排查](#6-发送失败问题排查)
7. [MicroPython Pico 代码](#7-micropython-pico-代码)
8. [Node.js 日志服务器](#8-nodejs-日志服务器)
9. [App 设置页面与 SQLite](#9-app-设置页面与-sqlite)
10. [Android 网络权限问题](#10-android-网络权限问题)
11. [Pico 数据接收问题](#11-pico-数据接收问题)
12. [OLED 显示屏集成](#12-oled-显示屏集成)
13. [Gitee / GitHub 发布](#13-gitee--github-发布)

---

## 1. 环境搭建与项目初始化

### 初始状态
空目录 `C:\Users\zhao\Desktop\QQForReasonix`

### 操作步骤
1. 创建 DeepSeek Token 用量监控网页 `index.html`
2. 下载旧项目 RAR 包并解压到 `2026608/` 目录
3. 创建 `flutterDemo/` 目录用于 Flutter 项目

---

## 2. 旧项目分析与清理

### 旧项目结构
`SPP_BLE` 是一个 Android 蓝牙调试工具，包含：
- **BLE 模式** (`SpBLE.java`)：基于 Nordic UART Service
- **SPP 模式** (`BluetoothChatService.java`)：基于经典蓝牙 RFCOMM Socket

### 删除的无用文件（11项）
| 删除项 | 原因 |
|--------|------|
| `.gradle/` | 构建缓存 |
| `.idea/` | IDE 配置 |
| `build/` 、`app/build/` | 编译产物 |
| `app/release/` | APK 发布包 |
| `app/libs/` | 空目录 |
| `*.iml` | IDE 模块文件 |
| `androidTest/`、`test/` | 空测试代码 |
| `app-releaseFinishV1.apk` | 重复 APK |

---

## 3. Flutter 项目移植

### 创建项目
```bash
flutter create --org com.bt --project-name spp_ble_flutter --platforms android flutterDemo
```

### 蓝牙服务移植对照

| 旧 Android 代码 | Flutter 实现 | 技术方案 |
|----------------|-------------|---------|
| `SpBLE.java` | `ble_service.dart` | `flutter_blue_plus` 包 |
| `BluetoothChatService.java` | `SppPlugin.kt` + `spp_service.dart` | MethodChannel + 原生 Kotlin |
| `MainActivity.java` | `main.dart` (BleChatPage / SppChatPage) | Flutter UI |

### 构建配置
- **ABI**: 仅 `arm64-v8a`
- **并行编译**: `org.gradle.parallel=true`
- **蓝牙权限**: BLUETOOTH / BLUETOOTH_ADMIN / BLUETOOTH_CONNECT / BLUETOOTH_SCAN / ACCESS_FINE_LOCATION
- **minSdk**: 21

---

## 4. Git 版本控制与远程仓库

### Gitee 仓库
- 使用 PAT 令牌创建私有仓库（后改为公开）
- `master` 分支：源码
- `release` 分支：APK 文件（后续改为直接放 master）

### GitHub 仓库
- 使用 Classic PAT (`ghp_` 开头)
- 直接上传 APK 到 Release 附件（无 WAF 拦截）

### 推送脚本
`push.bat` — 一键推送代码到 master + APK 到 release

---

## 5. BT37 模块适配

### PDF 手册关键信息
从 `DX-BT37蓝牙模块技术手册.pdf` 和 `DX-BT37蓝牙模块_串口UART_应用指导.pdf` 提取：

### BT37 UUID 默认值
| 用途 | 16位 UUID | 完整 128位 UUID |
|------|-----------|----------------|
| Service UUID | 0xFFE0 | `0000FFE0-...` |
| Notify/Read UUID | 0xFFE1 | `0000FFE1-...` |
| Write UUID | 0xFFE2 | `0000FFE2-...` |

### 串口默认参数
9600bps, 8, n, 1

### UUID 预设选择器
在 BLE 扫描页顶部增加下拉选择器，支持：
- **Nordic UART**（默认）：`6E400001/002/003`
- **BT37 (FFE0)**：`0000FFE0/FFE1/FFE2`

---

## 6. 发送失败问题排查

### 问题现象
App 显示"已连接"，但点击发送提示"发送失败"或"connect error"

### 原因 1：写入模式不匹配
BT37 的 FFE2 特征值只支持 **Write Without Response**（无应答写入），而代码写死了 `withoutResponse: false`

**修复**: 自动检测特征值属性：
```dart
if (props.writeWithoutResponse) {
  await write(data, withoutResponse: true);  // BT37
} else {
  await write(data, withoutResponse: false); // Nordic UART
}
```

### 原因 2：连接竞态条件
`connectionState` 流在开始监听时会立即发射当前状态。如果设备之前是断开的，连接成功后流会先发 `disconnected`（旧状态残留）→ 再发 `connected`，导致特征值被误清空。

**修复**: 只在真正 connected 之后才响应 `disconnected` 事件。

### 原因 3：Service UUID 不匹配
扫描时用了 `withServices: []`（匹配所有服务），但 `_discoverServices()` 用预设 UUID 查找。如果预设不对会导致服务找不到。

### 修复步骤汇总
1. 连接前先断开已有连接，避免状态冲突
2. 连接成功后等待 300ms 让 GATT 稳定
3. `connectionState` 监听器加状态判断
4. 写入方法双模式重试：先 WithResponse → 失败则 WithoutResponse

---

## 7. MicroPython Pico 代码

### 文件结构
```
pr2040_micropython/
├── main.py              ← 基础版
├── main_advanced.py     ← 进阶版（AT指令）
├── main_oled.py         ← OLED 显示版
└── README.md
```

### 接线（BT37 → PR2040）
```
BT37 TX  → Pico GP1  (UART0 RX)
BT37 RX  → Pico GP0  (UART0 TX)
BT37 VCC → Pico 3V3 (Pin 36)
BT37 GND → Pico GND (Pin 38)
```

### 问题 1：`bytes.decode()` 不支持关键字参数
**现象**: `TypeError: function doesn't take keyword arguments`
**原因**: MicroPython 的 `bytes.decode()` 不支持 `errors="replace"` 关键字参数
**修复**: 改为 `raw.decode("utf-8")`

### 问题 2：Thonny 终端无法发送数据
**现象**: 手机可以发到 Pico，但 Thonny Shell 输入的文字发不到手机
**原因**: USB 串口输入转发的代码被注释了
**修复**: 使用 `select.poll()` 非阻塞检查 `sys.stdin`

### 问题 3：手机数据不带换行，Pico 不处理
**现象**: 手机 App 发送数据后 Pico 没反应，数据卡在缓冲区
**原因**: Pico 代码用 `while b"\n" in uart_buf` 等待换行符才处理，但手机 App 发的是原始字节，不追加 `\n`
**修复**: 增加 200ms 超时兜底，没收到换行也处理缓冲区数据

---

## 8. Node.js 日志服务器

### 位置
`flutterDemo/log_server/`

### 启动
```bash
npm --prefix log_server install
node log_server/server.js
```

### API
```
POST http://192.168.0.10:3322/log
Content-Type: application/json
{"level":"INFO","tag":"BLE","message":"连接成功","data":{},"time":"..."}
```

### 功能
- 实时接收 App BLE 日志
- SSE 推送到网页
- 按级别筛选
- 统计计数

---

## 9. App 设置页面与 SQLite

### 设置页面
- 右上角齿轮图标进入
- 输入日志服务器地址
- 保存（写入 SQLite）
- 测试连接

### SQLite 持久化
`settings_service.dart` 使用 `sqflite` 包存储键值对：
```sql
CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)
```

### BleLogger 改进
- 服务器地址可从设置动态修改
- `init()` 改为 `async`，启动时从 SQLite 读取

---

## 10. Android 网络权限问题

### 问题现象
```
SocketException: Operation not permitted, errno = 1
address = 192.168.0.10, port = 3322
```

### 原因
Android 9+ **默认阻止明文 HTTP 流量**连接到本地网络

### 修复
`AndroidManifest.xml` 添加：
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<application android:usesCleartextTraffic="true" ...>
```

---

## 11. Pico 数据接收问题

### OLED 显示模式
- **之前**: 多行列表滚动，显示所有历史消息
- **现在**: 单条消息显示，新消息覆盖旧消息
- **超长文本**（>21字符）: 自动水平滚动

### 显示布局
```
┌─────────────────────────┐
│ [>]                     │  ← 方向标签
│ RX: 28 chars            │  ← 字符数统计
│ ─────────────────────── │  ← 分隔线
│ Hello from phone!       │  ← 消息内容(居中)
└─────────────────────────┘
```

---

## 12. OLED 显示屏集成

### 型号
0.96" SSD1306 128x64, I2C 接口, 地址 0x3C

### 接线
```
OLED VCC → Pico 3V3 (Pin 36)
OLED GND → Pico GND (Pin 38)
OLED SCL → Pico GP5  (I2C0 SCL)
OLED SDA → Pico GP4  (I2C0 SDA)
```

### 电流需求
| 设备 | 电流 |
|------|------|
| BT37 | ~5mA |
| OLED | ~15-20mA |
| **合计** | **~25mA** |
| Pico 3V3 最大输出 | **300mA** |

> ⚠️ GPIO 引脚不可直接给外部设备供电（最大 ~4mA），必须用 Pin 36 (3V3_OUT)

### 驱动实现
- 自实现 SSD1306 初始化 + 帧缓冲
- 内嵌 6x8 字体（ASCII 32-126）
- 不依赖外部库

---

## 13. Gitee / GitHub 发布

### Gitee
- 遇到 WAF 阻止 `.apk` 下载 → 改为 `.zip` 打包发布

### GitHub
- 需要 Classic PAT（`ghp_` 开头）才能创建仓库
- Fine-grained PAT 没有 `administration: write` 权限
- APK 直接上传为 Release 附件

### Release 地址
- **GitHub**: https://github.com/Red-Kal/spp-ble-flutter/releases/tag/v1.0
- **Gitee**: https://gitee.com/sayux/spp-ble-flutter/releases/tag/v1.0

---

## 附录：命令速查

### Flutter 编译
```bash
# debug
flutter build apk --debug --target-platform android-arm64
# release
flutter build apk --release --target-platform android-arm64
```

### Git 推送
```bash
git -C flutterDemo push origin master
git -C flutterDemo push github master
```

### 日志服务器
```bash
node flutterDemo/log_server/server.js
# 网页: http://192.168.0.10:3322
```

### GitHub Release APK 更新
```bash
# 1. 获取 asset ID
curl -H "Authorization: Bearer <token>" \
  "https://api.github.com/repos/Red-Kal/spp-ble-flutter/releases/336079555/assets"
# 2. 删除旧 asset
curl -X DELETE -H "Authorization: Bearer <token>" \
  "https://api.github.com/repos/Red-Kal/spp-ble-flutter/releases/assets/<id>"
# 3. 上传新 APK
curl -X POST -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/vnd.android.package-archive" \
  --data-binary "@app-release.apk" \
  "https://uploads.github.com/repos/Red-Kal/spp-ble-flutter/releases/336079555/assets?name=app-release.apk"
```
