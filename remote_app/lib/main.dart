import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RemoteApp());
}

class RemoteApp extends StatelessWidget {
  const RemoteApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '遥控器',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFFFF5722),
        useMaterial3: true,
      ),
      home: const RemoteControlPage(),
    );
  }
}

const String _serviceUuid = '0000ffe0-0000-1000-8000-00805f9b34fb';
const String _writeUuid = '0000ffe2-0000-1000-8000-00805f9b34fb';

class RemoteControlPage extends StatefulWidget {
  const RemoteControlPage({super.key});
  @override
  State<RemoteControlPage> createState() => _RemoteControlPageState();
}

class _RemoteControlPageState extends State<RemoteControlPage> {
  bool _scanning = false;
  bool _connecting = false;
  bool _connected = false;
  bool _sending = false;
  String _status = '准备就绪';
  BluetoothDevice? _device;
  BluetoothCharacteristic? _txChar;
  StreamSubscription? _scanSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    FlutterBluePlus.stopScan();
    _device?.disconnect();
    super.dispose();
  }

  Future<void> _startScan() async {
    if (_scanning) return;
    setState(() { _scanning = true; _status = '搜索 BT37...'; });

    try {
      await FlutterBluePlus.turnOn();
      await FlutterBluePlus.startScan(
        withServices: [],
        timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final name = r.device.localName;
          if (name != null && (name.contains("BT37") || name.contains("bt37"))) {
            _scanSub?.cancel();
            FlutterBluePlus.stopScan();
            _connectTo(r.device);
            return;
          }
        }
      });

      // 超时自动停止
      Future.delayed(const Duration(seconds: 12), () {
        if (_scanning && mounted) {
          _scanSub?.cancel();
          FlutterBluePlus.stopScan();
          setState(() { _scanning = false; _status = '未找到 BT37'; });
        }
      });
    } catch (e) {
      setState(() { _scanning = false; _status = '扫描失败: $e'; });
    }
  }

  Future<void> _connectTo(BluetoothDevice device) async {
    _device = device;
    setState(() { _connecting = true; _status = '连接 ${device.localName}...'; });

    try {
      await device.connect(mtu: 512);
      final services = await device.discoverServices();

      final svc = services.cast<BluetoothService?>().firstWhere(
        (s) => s!.uuid == Guid(_serviceUuid), orElse: () => null);
      if (svc == null) { setState(() { _connecting = false; _status = '未找到服务'; }); return; }

      _txChar = svc.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
        (c) => c!.uuid == Guid(_writeUuid), orElse: () => null);
      if (_txChar == null) { setState(() { _connecting = false; _status = '未找到写入特征'; }); return; }

      setState(() { _connected = true; _connecting = false; _status = '已连接'; });
    } catch (e) {
      setState(() { _connecting = false; _status = '连接失败: $e'; });
    }
  }

  Future<void> _sendCommand() async {
    if (_txChar == null || !_connected) { setState(() => _status = '未连接'); return; }
    setState(() { _sending = true; _status = '发送中...'; });

    try {
      final cmd = Uint8List.fromList([0x4F, 0x4E]); // "ON"
      final props = _txChar!.properties;
      if (props.writeWithoutResponse) {
        await _txChar!.write(cmd, withoutResponse: true);
      } else {
        await _txChar!.write(cmd, withoutResponse: false);
      }
      setState(() => _status = '✅ 已发送');
    } catch (e) {
      setState(() => _status = '发送失败: $e');
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🔴 遥 控 器', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 8)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _connected ? const Color(0xFF1A3A1A) : const Color(0xFF2A1A1A),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(_status, style: TextStyle(fontSize: 14, color: _connected ? Colors.greenAccent : Colors.orangeAccent)),
        ),
        const SizedBox(height: 60),

        GestureDetector(
          onTap: _connected && !_sending ? _sendCommand : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 200, height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _connected ? const Color(0xFFD32F2F) : const Color(0xFF333333),
              boxShadow: _connected ? [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 40, spreadRadius: 10)] : [],
            ),
            child: Center(child: _sending
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('开始', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white))),
          ),
        ),
        const SizedBox(height: 60),

        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: _connected ? Colors.green : (_connecting ? Colors.yellow : Colors.red))),
          const SizedBox(width: 8),
          Text(_connected ? 'BT37 已连接' : (_connecting ? '连接中...' : '未连接'), style: TextStyle(color: Colors.grey[400], fontSize: 14)),
        ]),
        const SizedBox(height: 20),

        if (!_connected && !_connecting && !_scanning)
          TextButton(onPressed: () { setState(() => _status = '准备就绪'); _startScan(); },
            child: const Text('重新搜索 BT37', style: TextStyle(color: Colors.blueAccent))),
      ])),
    );
  }
}
