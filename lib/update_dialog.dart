import 'dart:io';
import 'package:flutter/material.dart';

import 'theme.dart';
import 'update_service.dart';

/// Показать диалог обновления: заметки → скачивание с прогрессом → установка.
Future<void> showUpdateDialog(BuildContext context, AppUpdate update) {
  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _UpdateDialog(update: update),
  );
}

class _UpdateDialog extends StatefulWidget {
  final AppUpdate update;
  const _UpdateDialog({required this.update});
  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _start() async {
    setState(() { _downloading = true; _error = null; _progress = 0; });
    final path = await UpdateService.downloadApk(widget.update.apkUrl, (p) {
      if (mounted) setState(() => _progress = p);
    });
    if (!mounted) return;
    if (path == null) {
      setState(() { _downloading = false; _error = 'Не удалось скачать. Проверь интернет.'; });
      return;
    }
    if (!Platform.isAndroid) {
      setState(() { _downloading = false; _error = 'Установка APK доступна только на Android.'; });
      return;
    }
    await UpdateService.install(path);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.update;
    return AlertDialog(
      backgroundColor: C.card,
      title: Row(children: [
        const Text('🏁 ', style: TextStyle(fontSize: 20)),
        Expanded(child: Text('Обновление ${u.version}',
            style: const TextStyle(fontWeight: FontWeight.bold))),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (u.notes.trim().isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: Text(u.notes, style: const TextStyle(color: C.muted, fontSize: 14)))),
        if (_downloading) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(value: _progress),
          const SizedBox(height: 6),
          Text('${(_progress * 100).round()}%', style: const TextStyle(color: C.muted)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: C.red)),
        ],
      ]),
      actions: [
        if (!_downloading)
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Позже')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.accent),
          onPressed: _downloading ? null : _start,
          child: Text(_downloading ? 'Качаю…' : 'Обновить'),
        ),
      ],
    );
  }
}
