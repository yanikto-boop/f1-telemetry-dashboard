// Автообновление напрямую через GitHub Releases (публичный репозиторий, без токенов).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

// Репозиторий с релизами приложения.
const String kRepoOwner = 'yanikto-boop';
const String kRepoName = 'f1-telemetry-dashboard';

class AppUpdate {
  final String version;
  final String notes;
  final String apkUrl;
  AppUpdate({required this.version, required this.notes, required this.apkUrl});
}

class UpdateService {
  static const _installer = MethodChannel('com.f1dash.f1telemetry/installer');

  /// Проверяет последний релиз на GitHub. Возвращает обновление, если оно новее.
  static Future<AppUpdate?> check() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = info.version;

      final resp = await http.get(
        Uri.parse('https://api.github.com/repos/$kRepoOwner/$kRepoName/releases/latest'),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      if (data['draft'] == true || data['prerelease'] == true) return null;
      final latest = _normalize((data['tag_name'] ?? '').toString());
      if (latest.isEmpty || !_isNewer(latest, current)) return null;

      final assets = (data['assets'] as List?) ?? [];
      final apk = assets.cast<Map<String, dynamic>>().firstWhere(
        (a) => (a['name'] ?? '').toString().toLowerCase().endsWith('.apk'),
        orElse: () => {},
      );
      final url = (apk['browser_download_url'] ?? '').toString();
      if (url.isEmpty) return null;

      return AppUpdate(
        version: latest,
        notes: (data['body'] ?? '').toString(),
        apkUrl: url,
      );
    } catch (_) {
      return null;
    }
  }

  /// Качает APK во внешнюю папку приложения, отдаёт прогресс 0..1.
  static Future<String?> downloadApk(String url, void Function(double) onProgress) async {
    try {
      final base = await getExternalStorageDirectory();
      if (base == null) return null;
      final dir = Directory('${base.path}/updates');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}/f1app_update.apk');

      final client = http.Client();
      final resp = await client.send(http.Request('GET', Uri.parse(url)));
      final total = resp.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.close();
      client.close();
      return file.path;
    } catch (_) {
      return null;
    }
  }

  static Future<void> install(String path) =>
      _installer.invokeMethod('installApk', {'path': path});

  static String _normalize(String v) =>
      v.trim().replaceFirst(RegExp(r'^[vV]'), '');

  static bool _isNewer(String a, String b) {
    final pa = _parts(a), pb = _parts(b);
    final n = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < n; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static List<int> _parts(String v) =>
      v.split(RegExp(r'[.+\-]')).map((s) => int.tryParse(s) ?? 0).toList();
}
