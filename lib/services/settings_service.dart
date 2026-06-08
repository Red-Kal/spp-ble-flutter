import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 设置服务 — 使用 SQLite 持久化存储
///
/// 存储项:
///   - log_server_url: 日志服务器地址
class SettingsService {
  static Database? _db;

  static Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'ble_settings.db');
    _db = await openDatabase(path, version: 1,
        onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    });
    return _db!;
  }

  // ─── 读取设置 ─────────────────────────────────────────────
  static Future<String?> get(String key) async {
    final db = await _getDb();
    final result = await db.query('settings',
        where: 'key = ?', whereArgs: [key]);
    if (result.isEmpty) return null;
    return result.first['value'] as String?;
  }

  // ─── 写入设置 ─────────────────────────────────────────────
  static Future<void> set(String key, String value) async {
    final db = await _getDb();
    await db.insert('settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ─── 日志服务器 URL ──────────────────────────────────────
  static const _logServerKey = 'log_server_url';
  static const String defaultLogServer = 'http://192.168.0.10:3322';

  static Future<String> getLogServerUrl() async {
    final url = await get(_logServerKey);
    return url ?? defaultLogServer;
  }

  static Future<void> setLogServerUrl(String url) async {
    // 去掉末尾的 /log
    String clean = url.trim();
    if (clean.endsWith('/')) clean = clean.substring(0, clean.length - 1);
    if (clean.endsWith('/log')) clean = clean.substring(0, clean.length - 4);
    await set(_logServerKey, clean);
  }
}
