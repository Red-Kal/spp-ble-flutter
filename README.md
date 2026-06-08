# SPP BLE 蓝牙调试工具 (Flutter)

移植自旧 Android 项目 SPP_BLE，支持 BLE 和经典蓝牙 SPP 连接调试。

## 功能

- **BLE 模式**: 扫描 BLE 设备，连接 Nordic UART Service (UUID 可配置)
- **SPP 模式**: 扫描经典蓝牙设备，RFCOMM Socket 连接
- Hex / ASCII 数据收发
- 实时数据计数与速度显示
- 仅 Android arm64-v8a 架构

## 构建

```bash
cd flutterDemo
flutter build apk --debug --target-platform android-arm64
```

## 推送

编译完成后，运行 `push.bat` 输入修改描述，自动推送到 Gitee：

```
代码 → master 分支
APK  → release 分支
```

## Gitee 仓库

https://gitee.com/sayux/spp-ble-flutter
