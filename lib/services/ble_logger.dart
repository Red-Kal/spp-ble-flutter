import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// BLE 日志服务 — 自动将日志发送到内网 Node.js 服务器
///
/// 服务器地址: http://192.168.0.10:3322
/// 网页查看:   http://192.168.0.10:3322
class BleLogger {
  static const String _serverUrl = 'http://192.168.0.10:3322';

  // 日志队列（批量发送，减少请求次数）
  static final List<Map<String, dynamic>> _queue = [];
  static Timer? _flushTimer;
  static int _logId = 0;

  // ─── 初始化 ───────────────────────────────────────────────
  static void init() {
    _flushTimer = Timer.periodic(const Duration(seconds: 2), (_) => _flush());
    _log("INFO", "LOGGER", "日志服务已启动", {"server": _serverUrl});
  }

  // ─── 四种日志级别 ─────────────────────────────────────────
  static void debug(String tag, String msg, [dynamic data]) =>
      _log("DEBUG", tag, msg, data);

  static void info(String tag, String msg, [dynamic data]) =>
      _log("INFO", tag, msg, data);

  static void warn(String tag, String msg, [dynamic data]) =>
      _log("WARN", tag, msg, data);

  static void error(String tag, String msg, [dynamic data]) =>
      _log("ERROR", tag, msg, data);

  // ─── 核心方法 ─────────────────────────────────────────────
  static void _log(String level, String tag, String message, [dynamic data]) {
    _logId++;
    // 本地控制台输出
    debugPrint("[BLE][$level][$tag] $message");

    // 加入发送队列
    _queue.add({
      "id": _logId,
      "level": level,
      "tag": tag,
      "message": message,
      "data": data,
      "time": DateTime.now().toIso8601String(),
    });

    // 如果队列达到 10 条，立即发送
    if (_queue.length >= 10) _flush();
  }

  // ─── 批量发送 ─────────────────────────────────────────────
  static void _flush() {
    if (_queue.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();

    // 逐条发送（不阻塞主流程）
    for (final entry in batch) {
      _send(entry);
    }
  }

  static void _send(Map<String, dynamic> entry) {
    try {
      http
          .post(
            Uri.parse("$_serverUrl/log"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(entry),
          )
          .timeout(const Duration(seconds: 3))
          .catchError((_) {});
    } catch (_) {
      // 静默失败，不干扰 App 主流程
    }
  }

  // ─── 释放 ─────────────────────────────────────────────────
  static void dispose() {
    _flushTimer?.cancel();
    _flush(); // 发送剩余日志
  }
}
