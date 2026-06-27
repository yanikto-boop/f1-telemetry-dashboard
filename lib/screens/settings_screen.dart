import 'package:flutter/material.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../app_settings.dart';
import '../theme.dart';
import '../udp_service.dart';
import '../update_service.dart';
import '../update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  final UdpService service;
  const SettingsScreen({super.key, required this.settings, required this.service});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _port;
  late TextEditingController _key;
  late TextEditingController _model;
  List<String> _ips = [];
  String _version = '';
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _port = TextEditingController(text: '${s.port}');
    _key = TextEditingController(text: s.apiKey);
    _model = TextEditingController(text: s.model);
    UdpService.localIps().then((v) => mounted ? setState(() => _ips = v) : null);
    PackageInfo.fromPlatform().then((i) =>
        mounted ? setState(() => _version = i.version) : null);
  }

  Future<void> _checkUpdate() async {
    setState(() => _checking = true);
    final upd = await UpdateService.check();
    if (!mounted) return;
    setState(() => _checking = false);
    if (upd != null) {
      showUpdateDialog(context, upd);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У тебя последняя версия')));
    }
  }

  Future<void> _saveAndRestart() async {
    final s = widget.settings;
    s.port = int.tryParse(_port.text) ?? 20777;
    s.apiKey = _key.text.trim();
    s.model = _model.text.trim();
    await s.save();
    await widget.service.start(s.port);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.service.running
            ? 'Слушаю UDP на порту ${s.port}'
            : 'Ошибка: ${widget.service.error}')));
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        _section('ПОДКЛЮЧЕНИЕ'),
        Container(decoration: cardDeco(), padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.circle, size: 12, color: widget.service.running
                  ? (widget.service.live ? C.green : C.yellow) : Colors.grey),
              const SizedBox(width: 8),
              Text(widget.service.running
                  ? (widget.service.live ? 'Приём данных' : 'Слушаю, жду пакеты')
                  : 'Остановлено',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 14),
            _modeSelector(s),
            const SizedBox(height: 14),
            TextField(controller: _port, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'UDP порт', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            _ipHint(s),
          ])),
        const SizedBox(height: 20),
        _section('OPENROUTER (AI-АНАЛИЗ)'),
        Container(decoration: cardDeco(), padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(controller: _key, obscureText: true,
              decoration: const InputDecoration(labelText: 'API key', border: OutlineInputBorder())),
            const SizedBox(height: 14),
            TextField(controller: _model,
              decoration: const InputDecoration(labelText: 'Модель', border: OutlineInputBorder())),
          ])),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: C.accent,
            padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: _saveAndRestart,
          icon: const Icon(Icons.save),
          label: const Text('Сохранить и перезапустить приём'),
        ),
        const SizedBox(height: 12),
        if (widget.service.running)
          OutlinedButton.icon(onPressed: () async {
            await widget.service.stop(); setState(() {});
          }, icon: const Icon(Icons.stop), label: const Text('Остановить приём')),
        const SizedBox(height: 24),
        _section('О ПРИЛОЖЕНИИ'),
        Container(decoration: cardDeco(), padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Версия', style: TextStyle(color: C.muted)),
              Text(_version.isEmpty ? '…' : 'v$_version',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              onPressed: _checking ? null : _checkUpdate,
              icon: _checking
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.system_update),
              label: Text(_checking ? 'Проверяю…' : 'Проверить обновления'),
            )),
          ])),
      ]),
    );
  }

  Widget _section(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 4),
    child: Text(s, style: const TextStyle(color: C.muted, letterSpacing: 2, fontSize: 12, fontWeight: FontWeight.bold)));

  Widget _modeSelector(AppSettings s) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'lan', label: Text('LAN'), icon: Icon(Icons.wifi)),
        ButtonSegment(value: 'local', label: Text('Этот ПК'), icon: Icon(Icons.computer)),
      ],
      selected: {s.mode},
      onSelectionChanged: (v) => setState(() { s.mode = v.first; s.save(); }),
    );
  }

  Widget _ipHint(AppSettings s) {
    if (s.mode == 'local') {
      return _hintBox('В игре укажи UDP IP Address = 127.0.0.1, порт = ${_port.text}. '
          'Приложение и игра на одном ПК.');
    }
    final ips = _ips.isEmpty ? 'определяю…' : _ips.join('  |  ');
    return _hintBox('В игре укажи UDP IP Address = IP этого устройства, порт = ${_port.text}.\n'
        'Твои локальные IP:\n$ips');
  }

  Widget _hintBox(String t) => Container(
    width: double.infinity, padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: C.line)),
    child: Text(t, style: const TextStyle(color: C.muted, fontSize: 13, height: 1.4)));
}
