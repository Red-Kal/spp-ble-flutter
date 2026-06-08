import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'services/ble_service.dart';
import 'services/spp_service.dart';

// ─────────────────────────────────────────────────────────────
// 入口
// ─────────────────────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SppBleApp());
}

class SppBleApp extends StatelessWidget {
  const SppBleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPP BLE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF4F8CFF),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 主页 - BLE 与 SPP 双标签
// ─────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final BleService _ble = BleService();
  final SppService _spp = SppService();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _ble.dispose();
    _spp.dispose();
    super.dispose();
  }

  void _onBleDeviceTap(ScanResult result) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BleChatPage(ble: _ble, device: result.device),
      ),
    );
  }

  void _onSppDeviceTap(Map<String, dynamic> device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SppChatPage(spp: _spp, deviceInfo: device),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SPP BLE 蓝牙调试'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'BLE', icon: Icon(Icons.bluetooth)),
            Tab(text: 'SPP', icon: Icon(Icons.bluetooth_connected)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _BleScanPage(ble: _ble, onTap: _onBleDeviceTap),
          _SppScanPage(spp: _spp, onTap: _onSppDeviceTap),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BLE 扫描页
// ─────────────────────────────────────────────────────────────
class _BleScanPage extends StatefulWidget {
  final BleService ble;
  final void Function(ScanResult) onTap;
  const _BleScanPage({required this.ble, required this.onTap});
  @override
  State<_BleScanPage> createState() => _BleScanPageState();
}

class _BleScanPageState extends State<_BleScanPage> {
  List<ScanResult> _devices = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _scanSub = widget.ble.scanStream.listen((list) {
      if (mounted) setState(() => _devices = list);
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    widget.ble.stopScan();
    super.dispose();
  }

  Future<void> _toggleScan() async {
    if (_scanning) {
      await widget.ble.stopScan();
      setState(() => _scanning = false);
    } else {
      setState(() => _devices = []);
      _scanning = true;
      await widget.ble.startScan();
      setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // UUID 预设选择器
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: const Color(0xFF1A1D2E),
            child: Row(
              children: [
                const Icon(Icons.vpn_key, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                const Text('UUID: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: widget.ble.currentPreset,
                      isDense: true,
                      dropdownColor: const Color(0xFF2A2D3E),
                      style: const TextStyle(fontSize: 13, color: Colors.cyanAccent),
                      items: BleService.presets.keys.map((name) {
                        final p = BleService.presets[name]!;
                        return DropdownMenuItem(
                          value: name,
                          child: Text('$name (${p['uart']!.substring(4, 8)})'),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) widget.ble.applyPreset(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _devices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey[600]),
                        const SizedBox(height: 12),
                        Text('点击下方搜索 BLE 设备', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _devices.length,
                    itemBuilder: (_, i) {
                      final d = _devices[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        child: ListTile(
                          leading: const Icon(Icons.bluetooth, color: Colors.blueAccent),
                          title: Text(d.device.localName.isNotEmpty ? d.device.localName : '未知设备'),
                          subtitle: Text('${d.device.remoteId.str}  RSSI: ${d.rssi}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => widget.onTap(d),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleScan,
        icon: Icon(_scanning ? Icons.stop : Icons.search),
        label: Text(_scanning ? '停止搜索' : '搜索设备'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SPP 扫描页
// ─────────────────────────────────────────────────────────────
class _SppScanPage extends StatefulWidget {
  final SppService spp;
  final void Function(Map<String, dynamic>) onTap;
  const _SppScanPage({required this.spp, required this.onTap});
  @override
  State<_SppScanPage> createState() => _SppScanPageState();
}

class _SppScanPageState extends State<_SppScanPage> {
  List<Map<String, dynamic>> _devices = [];
  StreamSubscription<List<Map<String, dynamic>>>? _scanSub;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _scanSub = widget.spp.scanStream.listen((list) {
      if (mounted) setState(() => _devices = list);
    });
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    widget.spp.stopScan();
    super.dispose();
  }

  Future<void> _toggleScan() async {
    if (_scanning) {
      await widget.spp.stopScan();
      setState(() => _scanning = false);
    } else {
      setState(() => _devices = []);
      _scanning = true;
      await widget.spp.startScan();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _devices.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bluetooth_searching, size: 64, color: Colors.grey[600]),
                  const SizedBox(height: 12),
                  Text('点击下方搜索 SPP 设备', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (_, i) {
                final d = _devices[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: ListTile(
                    leading: const Icon(Icons.bluetooth, color: Colors.green),
                    title: Text(d['name'] ?? '未知设备'),
                    subtitle: Text('${d['address']}  RSSI: ${d['rssi']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => widget.onTap(d),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleScan,
        icon: Icon(_scanning ? Icons.stop : Icons.search),
        label: Text(_scanning ? '停止搜索' : '搜索设备'),
      ),
    );
  }
}

// ─── BLE 聊天页 ──────────────────────────────────────────
class BleChatPage extends StatefulWidget {
  final BleService ble;
  final BluetoothDevice device;
  const BleChatPage({super.key, required this.ble, required this.device});
  @override
  State<BleChatPage> createState() => _BleChatPageState();
}

class _BleChatPageState extends State<BleChatPage> {
  BleConnectionState _connState = BleConnectionState.disconnected;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<String> _messages = [];
  bool _txHex = false, _rxHex = false;
  int _txCount = 0, _rxCount = 0;
  int _txSpeed = 0, _rxSpeed = 0;
  Timer? _speedTimer;
  int _rssi = 0;

  StreamSubscription<BleConnectionState>? _stateSub;
  StreamSubscription<Uint8List>? _dataSub;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.ble.stateStream.listen((s) {
      if (mounted) setState(() => _connState = s);
    });
    _dataSub = widget.ble.dataStream.listen(_onDataReceived);
    widget.ble.rssiStream.listen((r) {
      if (mounted) setState(() => _rssi = r);
    });
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _dataSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _speedTimer?.cancel();
    widget.ble.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    try {
      await widget.ble.connect(widget.device);
      _speedTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() {
          _txSpeed = _txCount; _rxSpeed = _rxCount;
          _txCount = 0; _rxCount = 0;
        });
      });
      widget.ble.readRssi();
      Timer.periodic(const Duration(seconds: 2), (_) => widget.ble.readRssi());
    } catch (e) {
      if (mounted) _showSnack('连接失败: $e');
    }
  }

  void _onDataReceived(Uint8List data) {
    final display = _formatData(data, _rxHex);
    setState(() { _rxCount += data.length; _messages.add('<< $display'); });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    final data = _txHex ? _hexStringToBytes(text) : Uint8List.fromList(utf8.encode(text));
    try {
      await widget.ble.write(data);
      setState(() { _txCount += data.length; _messages.add('>> ${_formatData(data, _txHex)}'); });
      _inputCtrl.clear();
      _scrollToBottom();
    } catch (e) { _showSnack('发送失败: $e'); }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  });

  String _formatData(Uint8List raw, bool hex) => hex
      ? raw.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')
      : utf8.decode(raw, allowMalformed: true);

  Uint8List _hexStringToBytes(String hex) {
    hex = hex.replaceAll(' ', '');
    final bytes = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.device.localName.isNotEmpty ? widget.device.localName : 'BLE'),
          Text(_connState == BleConnectionState.connected ? '已连接 RSSI:$_rssi'
              : _connState == BleConnectionState.connecting ? '连接中...' : '未连接',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
      body: Column(children: [
        if (_connState != BleConnectionState.connected)
          Padding(padding: const EdgeInsets.all(12), child: ElevatedButton.icon(onPressed: _connect, icon: const Icon(Icons.link), label: const Text('连接'))),
        if (_connState == BleConnectionState.connected)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Row(children: [
            Text('TX:$_txSpeed B/s  ', style: const TextStyle(color: Colors.orange)),
            Text('RX:$_rxSpeed B/s  ', style: const TextStyle(color: Colors.cyan)),
            Text('总TX:$_txCount  ', style: const TextStyle(color: Colors.grey)),
            Text('总RX:$_rxCount', style: const TextStyle(color: Colors.grey)),
          ])),
        Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: const Color(0xFF1A1D2E), borderRadius: BorderRadius.circular(8)),
          child: ListView.builder(controller: _scrollCtrl, itemCount: _messages.length, itemBuilder: (_, i) {
            final isSend = _messages[i].startsWith('>>');
            return Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1), child: Text(
              _messages[i], style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: isSend ? Colors.orangeAccent : Colors.lightBlueAccent),
            ));
          }),
        )),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
          Checkbox(value: _txHex, onChanged: (v) => setState(() => _txHex = v ?? false)),
          const Text('TX Hex', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 12),
          Checkbox(value: _rxHex, onChanged: (v) => setState(() => _rxHex = v ?? false)),
          const Text('RX Hex', style: TextStyle(fontSize: 12)),
          const Spacer(),
          TextButton.icon(onPressed: () => setState(() => _messages.clear()), icon: const Icon(Icons.clear_all, size: 16), label: const Text('清空', style: TextStyle(fontSize: 12))),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: Row(children: [
          Expanded(child: TextField(controller: _inputCtrl, style: const TextStyle(fontFamily: 'monospace'),
            decoration: InputDecoration(hintText: _txHex ? 'Hex (01 02 AB)' : '输入文本', filled: true, fillColor: const Color(0xFF1A1D2E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            onSubmitted: (_) => _send(),
          )),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
        ])),
      ]),
    );
  }
}

// ─── SPP 聊天页 ──────────────────────────────────────────
class SppChatPage extends StatefulWidget {
  final SppService spp;
  final Map<String, dynamic> deviceInfo;
  const SppChatPage({super.key, required this.spp, required this.deviceInfo});
  @override
  State<SppChatPage> createState() => _SppChatPageState();
}

class _SppChatPageState extends State<SppChatPage> {
  SppConnectionState _connState = SppConnectionState.none;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<String> _messages = [];
  bool _txHex = false, _rxHex = false;
  int _txCount = 0, _rxCount = 0;
  int _txSpeed = 0, _rxSpeed = 0;
  Timer? _speedTimer;

  StreamSubscription<SppConnectionState>? _stateSub;
  StreamSubscription<Uint8List>? _dataSub;

  @override
  void initState() {
    super.initState();
    _stateSub = widget.spp.stateStream.listen((s) {
      if (mounted) setState(() => _connState = s);
    });
    _dataSub = widget.spp.dataStream.listen(_onDataReceived);
  }

  @override
  void dispose() {
    _stateSub?.cancel(); _dataSub?.cancel();
    _inputCtrl.dispose(); _scrollCtrl.dispose();
    _speedTimer?.cancel(); widget.spp.disconnect();
    super.dispose();
  }

  Future<void> _connect() async {
    final addr = widget.deviceInfo['address'] as String?;
    if (addr == null) return;
    try {
      await widget.spp.connect(addr);
      _speedTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() { _txSpeed = _txCount; _rxSpeed = _rxCount; _txCount = 0; _rxCount = 0; });
      });
    } catch (e) { if (mounted) _showSnack('连接失败: $e'); }
  }

  void _onDataReceived(Uint8List data) {
    final display = _formatData(data, _rxHex);
    setState(() { _rxCount += data.length; _messages.add('<< $display'); });
    _scrollToBottom();
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    final data = _txHex ? _hexStringToBytes(text) : Uint8List.fromList(utf8.encode(text));
    final ok = await widget.spp.write(data);
    if (ok) {
      setState(() { _txCount += data.length; _messages.add('>> ${_formatData(data, _txHex)}'); });
      _inputCtrl.clear(); _scrollToBottom();
    } else { _showSnack('发送失败'); }
  }

  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  void _scrollToBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollCtrl.hasClients) _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
  });

  String _formatData(Uint8List raw, bool hex) => hex
      ? raw.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')
      : utf8.decode(raw, allowMalformed: true);

  Uint8List _hexStringToBytes(String hex) {
    hex = hex.replaceAll(' ', '');
    final bytes = Uint8List(hex.length ~/ 2);
    for (int i = 0; i < bytes.length; i++) bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    return bytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.deviceInfo['name'] ?? 'SPP'),
          Text(_connState == SppConnectionState.connected ? '已连接'
              : _connState == SppConnectionState.connecting ? '连接中...' : '未连接',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
      body: Column(children: [
        if (_connState != SppConnectionState.connected)
          Padding(padding: const EdgeInsets.all(12), child: ElevatedButton.icon(onPressed: _connect, icon: const Icon(Icons.link), label: const Text('连接'))),
        if (_connState == SppConnectionState.connected)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Row(children: [
            Text('TX:$_txSpeed B/s  ', style: const TextStyle(color: Colors.orange)),
            Text('RX:$_rxSpeed B/s  ', style: const TextStyle(color: Colors.cyan)),
            Text('总TX:$_txCount  ', style: const TextStyle(color: Colors.grey)),
            Text('总RX:$_rxCount', style: const TextStyle(color: Colors.grey)),
          ])),
        Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: const Color(0xFF1A1D2E), borderRadius: BorderRadius.circular(8)),
          child: ListView.builder(controller: _scrollCtrl, itemCount: _messages.length, itemBuilder: (_, i) {
            final isSend = _messages[i].startsWith('>>');
            return Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1), child: Text(
              _messages[i], style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: isSend ? Colors.orangeAccent : Colors.lightBlueAccent),
            ));
          }),
        )),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
          Checkbox(value: _txHex, onChanged: (v) => setState(() => _txHex = v ?? false)),
          const Text('TX Hex', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 12),
          Checkbox(value: _rxHex, onChanged: (v) => setState(() => _rxHex = v ?? false)),
          const Text('RX Hex', style: TextStyle(fontSize: 12)),
          const Spacer(),
          TextButton.icon(onPressed: () => setState(() => _messages.clear()), icon: const Icon(Icons.clear_all, size: 16), label: const Text('清空', style: TextStyle(fontSize: 12))),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: Row(children: [
          Expanded(child: TextField(controller: _inputCtrl, style: const TextStyle(fontFamily: 'monospace'),
            decoration: InputDecoration(hintText: _txHex ? 'Hex 数据' : '输入文本', filled: true, fillColor: const Color(0xFF1A1D2E),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            onSubmitted: (_) => _send(),
          )),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
        ])),
      ]),
    );
  }
}

