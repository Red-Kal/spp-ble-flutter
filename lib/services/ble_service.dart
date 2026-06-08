import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_logger.dart';

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
    BleLogger.info('BLE', '切换 UUID 预设: $presetName', {
      'uart': _uartUuid,
      'tx': _txUuid,
      'rx': _rxUuid,
    });
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
    BleLogger.info('BLE', '开始扫描设备');

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
    BleLogger.info('BLE', '停止扫描，发现 ${_foundDevices.length} 个设备');
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
            BleLogger.warn('BLE', '设备已断开连接', {'addr': device.remoteId.str});
            _cleanup();
            _setState(BleConnectionState.disconnected);
          }
        }
      });

      BleLogger.info('BLE', '正在连接...', {
        'name': device.localName,
        'addr': device.remoteId.str,
        'preset': _currentPreset,
      });

      // 连接（自动发现服务 + 协商 MTU）
      await device.connect(mtu: 512, timeout: const Duration(seconds: 15));

      // 等待连接稳定
      await Future.delayed(const Duration(milliseconds: 300));

      _setState(BleConnectionState.connected);
      BleLogger.info('BLE', '连接成功', {
        'name': device.localName,
        'addr': device.remoteId.str,
      });

      // 发现服务
      await _discoverServices();
    } catch (e) {
      BleLogger.error('BLE', '连接失败', {'error': e.toString()});
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
      BleLogger.error('BLE', '服务未找到', {
        'expected_uuid': _uartUuid,
        'available_services': services.map((s) => s.uuid.toString()).toList(),
      });
      throw Exception('Service not found: $_uartUuid');
    }

    BleLogger.info('BLE', '服务发现成功', {
      'service': _uartUuid,
      'total_services': services.length,
    });

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
      BleLogger.error('BLE', 'TX 特征值未找到', {
        'expected_tx': _txUuid,
        'available_chars': uartService.characteristics.map((c) => c.uuid.toString()).toList(),
      });
      throw Exception('TX characteristic not found: $_txUuid');
    }
    if (_rxCharacteristic == null) {
      BleLogger.error('BLE', 'RX 特征值未找到', {
        'expected_rx': _rxUuid,
        'available_chars': uartService.characteristics.map((c) => c.uuid.toString()).toList(),
      });
      throw Exception('RX characteristic not found: $_rxUuid');
    }

    BleLogger.info('BLE', '特征值已找到', {
      'tx': _txUuid,
      'rx': _rxUuid,
      'tx_properties': _txCharacteristic!.properties.toString(),
    });

    // 启用通知
    try {
      await _rxCharacteristic!.setNotifyValue(true);
      BleLogger.info('BLE', '通知已启用');
    } catch (e) {
      BleLogger.warn('BLE', '启用通知失败', {'error': e.toString()});
      rethrow;
    }
    _notificationSub = _rxCharacteristic!.value.listen((data) {
      BleLogger.debug('BLE', '收到数据', {'len': data.length, 'hex': data.take(20).map((b) => b.toRadixString(16).padLeft(2,'0')).join(' ')});
      _dataController.add(Uint8List.fromList(data));
    });
  }

  // ─── 写入数据 ────────────────────────────────────────────
  Future<void> write(Uint8List data) async {
    if (_txCharacteristic == null) {
      BleLogger.error('BLE', '写入失败: 特征值为空');
      throw Exception('特征值为空，请重新连接');
    }
    if (_state != BleConnectionState.connected) {
      BleLogger.error('BLE', '写入失败: 设备已断开');
      throw Exception('设备已断开');
    }

    final props = _txCharacteristic!.properties;
    final hexPreview = data.length <= 20
        ? data.map((b) => b.toRadixString(16).padLeft(2,'0')).join(' ')
        : '${data.take(20).map((b) => b.toRadixString(16).padLeft(2,'0')).join(' ')}...';

    BleLogger.debug('BLE', '写入数据', {'len': data.length, 'hex': hexPreview});

    if (props.write) {
      try {
        await _txCharacteristic!.write(data, withoutResponse: false);
        BleLogger.debug('BLE', '写入成功(withResponse)');
        return;
      } catch (e) {
        BleLogger.debug('BLE', 'writeWithResponse 失败，尝试 withoutResponse', {'error': e.toString()});
        if (props.writeWithoutResponse) {
          await _txCharacteristic!.write(data, withoutResponse: true);
          BleLogger.debug('BLE', '写入成功(withoutResponse)');
          return;
        }
        BleLogger.error('BLE', '写入失败', {'error': e.toString()});
        rethrow;
      }
    } else if (props.writeWithoutResponse) {
      await _txCharacteristic!.write(data, withoutResponse: true);
      BleLogger.debug('BLE', '写入成功(withoutResponse)');
    } else {
      BleLogger.error('BLE', '特征值不可写入', {'props': props.toString()});
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
      BleLogger.info('BLE', '主动断开连接', {'addr': _device!.remoteId.str});
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
