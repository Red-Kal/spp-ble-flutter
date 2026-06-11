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
  // 设备列表
  bool _scanning = false;
  final List<ScanResult> _devices = [];
  StreamSubscription<List<ScanResult>>? _scanSub;

  // 连接状态
  bool _connecting = false;
  bool _connected = false;
  bool _sending = false;
  String _status = '准备就绪';
  String _deviceName = '';
  BluetoothDevice? _device;
  BluetoothCharacteristic? _txChar;

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

  // ─── 扫描 ─────────────────────────────────────────────
  Future<void> _startScan() async {
    setState(() { _scanning = true; _status = '搜索中...'; _devices.clear(); });
    try {
      await FlutterBluePlus.turnOn();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final idx = _devices.indexWhere((d) => d.device.remoteId.str == r.device.remoteId.str);
          if (idx >= 0) { _devices[idx] = r; } else { _devices.add(r); }
        }
        if (mounted) setState(() {});
      });
      await FlutterBluePlus.startScan(
        withServices: [], timeout: const Duration(seconds: 10),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      setState(() { _scanning = false; _status = '扫描失败: $e'; });
    }
  }

  Future<void> _stopScan() async {
    _scanSub?.cancel();
    await FlutterBluePlus.stopScan();
    setState(() { _scanning = false; });
  }

  // ─── 连接 ─────────────────────────────────────────────
  Future<void> _connect(BluetoothDevice device) async {
    await _stopScan();
    _device = device;
    setState(() { _connecting = true; _status = '连接中...'; });

    try {
      await device.connect(mtu: 512);
      final services = await device.discoverServices();

      final svc = services.cast<BluetoothService?>().firstWhere(
        (s) => s!.uuid == Guid(_serviceUuid), orElse: () => null);
      if (svc == null) {
        // 尝试 Nordic UART 作为备选
        final nordicSvc = services.cast<BluetoothService?>().firstWhere(
          (s) => s!.uuid == Guid('6e400001-b5a3-f393-e0a9-e50e24dcca9e'),
          orElse: () => null);
        if (nordicSvc == null) {
          setState(() { _connecting = false; _status = '未找到服务，暂不支持'; });
          return;
        }
        _txChar = nordicSvc.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
          (c) => c!.uuid == Guid('6e400002-b5a3-f393-e0a9-e50e24dcca9e'),
          orElse: () => null);
        if (_txChar == null) { setState(() { _connecting = false; _status = '未找到写入特征'; }); return; }
      } else {
        _txChar = svc.characteristics.cast<BluetoothCharacteristic?>().firstWhere(
          (c) => c!.uuid == Guid(_writeUuid), orElse: () => null);
        if (_txChar == null) { setState(() { _connecting = false; _status = '未找到写入特征'; }); return; }
      }

      setState(() { _connected = true; _connecting = false; _deviceName = device.localName ?? device.remoteId.str; _status = '已连接'; });
    } catch (e) {
      setState(() { _connecting = false; _status = '连接失败: $e'; });
    }
  }

  Future<void> _disconnect() async {
    _txChar = null;
    await _device?.disconnect();
    _device = null;
    setState(() { _connected = false; _deviceName = ''; _status = '已断开'; });
  }

  // ─── 发送指令 ─────────────────────────────────────────
  Future<void> _sendCommand() async {
    if (_txChar == null || !_connected) return;
    setState(() { _sending = true; _status = '发送中...'; });
    try {
      final cmd = Uint8List.fromList([0x4F, 0x4E]);
      final props = _txChar!.properties;
      if (props.writeWithoutResponse) {
        await _txChar!.write(cmd, withoutResponse: true);
      } else {
        await _txChar!.write(cmd, withoutResponse: false);
      }
      setState(() => _status = '✅ 已发送');
    } catch (e) {
      setState(() => _status = '发送失败: $e');
    } finally { setState(() => _sending = false); }
  }

  // ─── UI ───────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        title: const Text('遥 控 器', style: TextStyle(letterSpacing: 6)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_connected)
            IconButton(icon: const Icon(Icons.link_off), onPressed: _disconnect, tooltip: '断开'),
          if (!_connected && !_scanning)
            IconButton(icon: const Icon(Icons.bluetooth_searching), onPressed: _startScan, tooltip: '搜索'),
          if (_scanning)
            IconButton(icon: const Icon(Icons.stop), onPressed: _stopScan, tooltip: '停止'),
        ],
      ),
      body: _connected ? _buildControlPanel() : _buildDeviceList(),
    );
  }

  // ─── 设备列表页 ───────────────────────────────────────
  Widget _buildDeviceList() {
    return Column(children: [
      if (_connecting)
        const LinearProgressIndicator(backgroundColor: Color(0xFF1A1D2E)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Text(_scanning ? '扫描中...' : '附近设备', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          const Spacer(),
          Text('${_devices.length} 个', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ]),
      ),
      Expanded(child: _devices.isEmpty
        ? Center(child: Text(_scanning ? '正在搜索...' : '点击右上角搜索', style: TextStyle(color: Colors.grey[600])))
        : ListView.builder(itemCount: _devices.length, itemBuilder: (_, i) {
          final d = _devices[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            color: const Color(0xFF1A1D2E),
            child: ListTile(
              leading: const Icon(Icons.bluetooth, color: Colors.blueAccent),
              title: Text(d.device.localName.isNotEmpty ? d.device.localName : '未知设备', style: const TextStyle(color: Colors.white)),
              subtitle: Text('${d.device.remoteId.str}  RSSI: ${d.rssi}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              trailing: d.device.localName.toLowerCase().contains('bt37')
                ? const Icon(Icons.check_circle, color: Colors.green, size: 18)
                : null,
              onTap: () => _connect(d.device),
            ),
          );
        }),
      ),
    ]);
  }

  // ─── 控制面板 ─────────────────────────────────────────
  Widget _buildControlPanel() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 20),
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green)),
        const SizedBox(width: 8),
        Text(_deviceName, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      ]),
      const SizedBox(height: 60),

      GestureDetector(
        onTap: _sending ? null : _sendCommand,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 200, height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFD32F2F),
            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 40, spreadRadius: 10)],
          ),
          child: Center(child: _sending
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('开始', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white))),
        ),
      ),
      const SizedBox(height: 40),
      Text(_status, style: const TextStyle(color: Colors.greenAccent, fontSize: 14)),
    ]));
  }
}
