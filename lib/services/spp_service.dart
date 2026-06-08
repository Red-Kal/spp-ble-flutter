import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';

/// SPP 经典蓝牙连接状态
enum SppConnectionState {
  none,
  connecting,
  connected,
}

/// SPP 服务 — 通过 MethodChannel 调用原生 Android 蓝牙 API
///
/// 移植自旧项目 BluetoothChatService.java 的 RFCOMM Socket 连接逻辑
class SppService {
  static const MethodChannel _channel = MethodChannel('com.bt.spp_ble/spp');

  // ─── 状态流 ───────────────────────────────────────────────
  final StreamController<SppConnectionState> _stateController =
      StreamController<SppConnectionState>.broadcast();
  Stream<SppConnectionState> get stateStream => _stateController.stream;

  SppConnectionState _state = SppConnectionState.none;
  SppConnectionState get state => _state;

  final StreamController<Uint8List> _dataController =
      StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get dataStream => _dataController.stream;

  // 设备信息
  String? _connectedDeviceName;
  String? _connectedDeviceAddress;
  String? get connectedDeviceName => _connectedDeviceName;
  String? get connectedDeviceAddress => _connectedDeviceAddress;

  // ─── 扫描 ─────────────────────────────────────────────────
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  final List<Map<String, dynamic>> _foundDevices = [];
  List<Map<String, dynamic>> get foundDevices => List.unmodifiable(_foundDevices);

  final StreamController<List<Map<String, dynamic>>> _foundController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  Stream<List<Map<String, dynamic>>> get scanStream => _foundController.stream;

  // ─── 初始化 ───────────────────────────────────────────────
  SppService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDeviceFound':
        final device = Map<String, dynamic>.from(call.arguments as Map);
        if (!_foundDevices.any((d) => d['address'] == device['address'])) {
          _foundDevices.add(device);
          _foundController.add(List.from(_foundDevices));
        }
        break;
      case 'onScanFinished':
        _isScanning = false;
        break;
      case 'onStateChange':
        final state = call.arguments as int;
        _setState(_fromNativeState(state));
        break;
      case 'onConnected':
        final info = Map<String, dynamic>.from(call.arguments as Map);
        _connectedDeviceName = info['name'] as String?;
        _connectedDeviceAddress = info['address'] as String?;
        _setState(SppConnectionState.connected);
        break;
      case 'onDisconnected':
        _connectedDeviceName = null;
        _connectedDeviceAddress = null;
        _setState(SppConnectionState.none);
        break;
      case 'onDataReceived':
        final data = (call.arguments as Uint8List?) ?? Uint8List(0);
        _dataController.add(data);
        break;
      case 'onDataSent':
        break;
      case 'onError':
        break;
    }
  }

  SppConnectionState _fromNativeState(int state) {
    switch (state) {
      case 1: return SppConnectionState.connecting;
      case 2: return SppConnectionState.connected;
      default: return SppConnectionState.none;
    }
  }

  // ─── 扫描设备 ────────────────────────────────────────────
  Future<void> startScan() async {
    if (_isScanning) return;
    _foundDevices.clear();
    _isScanning = true;
    try {
      await _channel.invokeMethod('startScan');
    } catch (e) {
      _isScanning = false;
    }
  }

  Future<void> stopScan() async {
    try {
      await _channel.invokeMethod('stopScan');
    } catch (_) {}
    _isScanning = false;
  }

  // ─── 连接 ─────────────────────────────────────────────────
  Future<void> connect(String address) async {
    _setState(SppConnectionState.connecting);
    try {
      await _channel.invokeMethod('connect', {'address': address});
    } catch (e) {
      _setState(SppConnectionState.none);
      rethrow;
    }
  }

  // ─── 写入数据 ────────────────────────────────────────────
  Future<bool> write(Uint8List data) async {
    try {
      final ok = await _channel.invokeMethod<bool>('write', {'data': data.buffer.asUint8List()});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  // ─── 断开连接 ────────────────────────────────────────────
  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } catch (_) {}
    _connectedDeviceName = null;
    _connectedDeviceAddress = null;
    _setState(SppConnectionState.none);
  }

  void _setState(SppConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  // ─── 释放 ─────────────────────────────────────────────────
  void dispose() {
    disconnect();
    _stateController.close();
    _dataController.close();
    _foundController.close();
  }
}
