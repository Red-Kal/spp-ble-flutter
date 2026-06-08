import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE 连接状态
enum BleConnectionState {
  disconnected,
  connecting,
  connected,
}

/// BLE 服务 — 移植自旧项目 SpBLE.java
///
/// 支持多种 UUID 预设：
///   1. Nordic UART Service（默认）
///       UART: 6E400001-B5A3-F393-E0A9-E50E24DCCA9E
///       TX:   6E400002-B5A3-F393-E0A9-E50E24DCCA9E
///       RX:   6E400003-B5A3-F393-E0A9-E50E24DCCA9E
///   2. BT37 / FFE0（大夏龙雀 DX-BT37 模块）
///       UART: 0000FFE0-0000-1000-8000-00805F9B34FB
///       TX:   0000FFE2-0000-1000-8000-00805F9B34FB
///       RX:   0000FFE1-0000-1000-8000-00805F9B34FB
class BleService {
  // ─── UUID 预设 ──────────────────────────────────────────
  static const String presetNordicUart = 'Nordic UART';
  static const String presetBt37 = 'BT37 (FFE0)';

  static const Map<String, Map<String, String>> presets = {
    presetNordicUart: {
      'uart': '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
      'tx':   '6e400002-b5a3-f393-e0a9-e50e24dcca9e',
      'rx':   '6e400003-b5a3-f393-e0a9-e50e24dcca9e',
    },
    presetBt37: {
      'uart': '0000ffe0-0000-1000-8000-00805f9b34fb',
      'tx':   '0000ffe2-0000-1000-8000-00805f9b34fb',
      'rx':   '0000ffe1-0000-1000-8000-00805f9b34fb',
    },
  };

  String _currentPreset = presetNordicUart;
  String get currentPreset => _currentPreset;

  // ─── 当前 UUID ───────────────────────────────────────────
  String _uartUuid = presets[presetNordicUart]!['uart']!;
  String _txUuid = presets[presetNordicUart]!['tx']!;
  String _rxUuid = presets[presetNordicUart]!['rx']!;

  String get uartUuid => _uartUuid;
  String get txUuid => _txUuid;
  String get rxUuid => _rxUuid;

  // ─── 当前连接设备 ────────────────────────────────────────
  BluetoothDevice? _device;
  BluetoothCharacteristic? _txCharacteristic;
  BluetoothCharacteristic? _rxCharacteristic;

  BluetoothDevice? get device => _device;
  String? get deviceAddress => _device?.remoteId.str;
  String? get deviceName => _device?.localName;

  // ─── 状态流 ───────────────────────────────────────────────
  final StreamController<BleConnectionState> _stateController =
      StreamController<BleConnectionState>.broadcast();
  Stream<BleConnectionState> get stateStream => _stateController.stream;

  BleConnectionState _state = BleConnectionState.disconnected;
  BleConnectionState get state => _state;

  // 收到的数据流
  final StreamController<Uint8List> _dataController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get dataStream => _dataController.stream;

  // RSSI 流
  final StreamController<int> _rssiController =
      StreamController<int>.broadcast();
  Stream<int> get rssiStream => _rssiController.stream;

  // ─── 订阅管理 ─────────────────────────────────────────────
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _notificationSub;

  // ─── 扫描相关 ─────────────────────────────────────────────
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  final List<ScanResult> _foundDevices = [];
  List<ScanResult> get foundDevices => List.unmodifiable(_foundDevices);

  final StreamController<List<ScanResult>> _scanController =
      StreamController<List<ScanResult>>.broadcast();
  Stream<List<ScanResult>> get scanStream => _scanController.stream;

  StreamSubscription<List<ScanResult>>? _scanSub;

  // ─── 设置 UUID ───────────────────────────────────────────
  void applyPreset(String presetName) {
    if (!presets.containsKey(presetName)) return;
    final p = presets[presetName]!;
    _uartUuid = p['uart']!;
    _txUuid = p['tx']!;
    _rxUuid = p['rx']!;
    _currentPreset = presetName;
  }

  void setCustomUuid({
    required String uart,
    required String tx,
    required String rx,
  }) {
    _uartUuid = uart;
    _txUuid = tx;
    _rxUuid = rx;
    _currentPreset = '自定义';
  }

  void resetUuid() {
    applyPreset(presetNordicUart);
  }

  // ─── 扫描 BLE 设备 ──────────────────────────────────────
  Future<void> startScan({Duration timeout = const Duration(seconds: 15)}) async {
    if (_isScanning) return;
    _foundDevices.clear();
    _isScanning = true;

    // 确保蓝牙已开启
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {}

    // 监听扫描结果
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final idx = _foundDevices.indexWhere(
          (d) => d.device.remoteId.str == r.device.remoteId.str,
        );
        if (idx >= 0) {
          _foundDevices[idx] = r;
        } else {
          _foundDevices.add(r);
        }
      }
      _scanController.add(List.from(_foundDevices));
    });

    await FlutterBluePlus.startScan(
      withServices: [],
      timeout: timeout,
      androidUsesFineLocation: true,
    );

    // 扫描会在 timeout 后自动停止
    await Future.delayed(timeout);
    await stopScan();
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    _isScanning = false;
    await _scanSub?.cancel();
    _scanSub = null;
  }

  // ─── 连接设备 ────────────────────────────────────────────
  Future<void> connect(BluetoothDevice device) async {
    _device = device;
    _setState(BleConnectionState.connecting);

    try {
      // 先断开已有连接
      if (device.isConnected) {
        await device.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // 监听连接状态变化
      // 注意: connectionState 在开始监听时可能会立即发出当前状态
      // 如果之前是 disconnected，连接成功后会先发 disconnected → 再发 connected
      // 所以我们只在真正 connected 之后才响应 disconnected 事件
      _connectionSub = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (_state == BleConnectionState.connected) {
            // 确实是已连接状态下的断开
            _cleanup();
            _setState(BleConnectionState.disconnected);
          }
          // 忽略连接过程中的 disconnected 事件（旧状态残留）
        }
      });

      // 连接（自动发现服务 + 协商 MTU）
      await device.connect(mtu: 512, timeout: const Duration(seconds: 15));

      // 等待连接稳定
      await Future.delayed(const Duration(milliseconds: 300));

      _setState(BleConnectionState.connected);

      // 发现服务
      await _discoverServices();
    } catch (e) {
      _cleanup();
      _setState(BleConnectionState.disconnected);
      rethrow;
    }
  }

  Future<void> _discoverServices() async {
    if (_device == null) return;

    final services = await _device!.discoverServices();

    // 查找 UART 服务
    final uartGuid = Guid(_uartUuid);
    final uartService = services.cast<BluetoothService?>().firstWhere(
      (s) => s!.uuid == uartGuid,
      orElse: () => null,
    );

    if (uartService == null) {
      throw Exception('Service not found: $_uartUuid');
    }

    // 查找 TX 特征值（写入）
    final txGuid = Guid(_txUuid);
    _txCharacteristic = uartService.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
      (c) => c!.uuid == txGuid,
      orElse: () => null,
    );

    // 查找 RX 特征值（通知/读取）
    final rxGuid = Guid(_rxUuid);
    _rxCharacteristic = uartService.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
      (c) => c!.uuid == rxGuid,
      orElse: () => null,
    );

    if (_txCharacteristic == null) {
      throw Exception('TX characteristic not found: $_txUuid');
    }
    if (_rxCharacteristic == null) {
      throw Exception('RX characteristic not found: $_rxUuid');
    }

    // 启用通知
    await _rxCharacteristic!.setNotifyValue(true);
    _notificationSub = _rxCharacteristic!.value.listen((data) {
      _dataController.add(Uint8List.fromList(data));
    });
  }

  // ─── 写入数据 ────────────────────────────────────────────
  Future<void> write(Uint8List data) async {
    if (_txCharacteristic == null) {
      throw Exception('特征值为空，请重新连接');
    }
    if (_state != BleConnectionState.connected) {
      throw Exception('设备已断开');
    }

    final props = _txCharacteristic!.properties;

    // Nordic UART (6E400002): 优先 WriteWithResponse
    // BT37 (FFE2): 只支持 WriteWithoutResponse
    // 先试 withResponse, 若失败再试 withoutResponse
    if (props.write) {
      try {
        await _txCharacteristic!.write(data, withoutResponse: false);
        return;
      } catch (e) {
        // 如果写带响应失败，且支持无响应，再试一次
        if (props.writeWithoutResponse) {
          await _txCharacteristic!.write(data, withoutResponse: true);
          return;
        }
        rethrow;
      }
    } else if (props.writeWithoutResponse) {
      await _txCharacteristic!.write(data, withoutResponse: true);
    } else {
      throw Exception('特征值不可写入');
    }
  }

  // ─── 读取 RSSI ──────────────────────────────────────────
  Future<int?> readRssi() async {
    if (_device == null) return null;
    try {
      final rssi = await _device!.readRssi();
      _rssiController.add(rssi);
      return rssi;
    } catch (_) {
      return null;
    }
  }

  // ─── 断开连接 ────────────────────────────────────────────
  Future<void> disconnect() async {
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
    }
    _cleanup();
    _setState(BleConnectionState.disconnected);
  }

  void _cleanup() {
    _notificationSub?.cancel();
    _notificationSub = null;
    _connectionSub?.cancel();
    _connectionSub = null;
    _txCharacteristic = null;
    _rxCharacteristic = null;
    _device = null;
  }

  void _setState(BleConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  // ─── 释放资源 ────────────────────────────────────────────
  void dispose() {
    disconnect();
    _stateController.close();
    _dataController.close();
    _rssiController.close();
    _scanController.close();
    _scanSub?.cancel();
  }
}
