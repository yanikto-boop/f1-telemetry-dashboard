import 'package:flutter/material.dart';

import '../ai.dart';
import '../app_settings.dart';
import '../appendices.dart';
import '../lap_store.dart';
import '../theme.dart';

class LapsScreen extends StatefulWidget {
  final LapStore store;
  final AppSettings settings;
  const LapsScreen({super.key, required this.store, required this.settings});
  @override
  State<LapsScreen> createState() => _LapsScreenState();
}

class _LapsScreenState extends State<LapsScreen> {
  List<TrackSummary> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final t = await widget.store.listTracks();
    if (mounted) setState(() { _tracks = t; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Круги'), actions: [
        IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
      ]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tracks.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(32),
                  child: Text('Пока нет записанных кругов.\nПроедь пару кругов в игре — они появятся здесь.',
                    textAlign: TextAlign.center, style: TextStyle(color: C.muted))))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _tracks.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final t = _tracks[i];
                      return Container(
                        decoration: cardDeco(),
                        child: ListTile(
                          title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${t.count} кругов · best ${t.bestMs != null ? fmtLap(t.bestMs!) : "—"}',
                            style: const TextStyle(color: C.muted)),
                          trailing: const Icon(Icons.chevron_right, color: C.muted),
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => TrackLapsScreen(
                              store: widget.store, settings: widget.settings,
                              trackId: t.trackId, name: t.name))).then((_) => _refresh()),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class TrackLapsScreen extends StatefulWidget {
  final LapStore store;
  final AppSettings settings;
  final int trackId;
  final String name;
  const TrackLapsScreen({super.key, required this.store, required this.settings,
    required this.trackId, required this.name});
  @override
  State<TrackLapsScreen> createState() => _TrackLapsScreenState();
}

class _TrackLapsScreenState extends State<TrackLapsScreen> {
  List<LapRecord> _laps = [];
  int? _best;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final laps = await widget.store.readLaps(widget.trackId);
    final valid = laps.where((l) => l.valid && l.timeMs > 0).map((l) => l.timeMs);
    if (!mounted) return;
    setState(() {
      _laps = laps;
      _best = valid.isEmpty ? null : valid.reduce((a, b) => a < b ? a : b);
    });
  }

  void _analyze() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _AnalysisSheet(
        settings: widget.settings, trackId: widget.trackId, laps: _laps),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name), actions: [
        IconButton(tooltip: 'Удалить все круги', icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            await widget.store.clearTrack(widget.trackId);
            if (context.mounted) Navigator.pop(context);
          }),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: C.accent, onPressed: _laps.isEmpty ? null : _analyze,
        icon: const Text('🏁', style: TextStyle(fontSize: 18)),
        label: const Text('AI-анализ', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        Container(
          width: double.infinity, margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14), decoration: cardDeco(),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _stat('КРУГОВ', '${_laps.length}'),
            _stat('ЛУЧШИЙ', _best != null ? fmtLap(_best!) : '—'),
          ]),
        ),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _laps.length,
          itemBuilder: (context, i) {
            final l = _laps[_laps.length - 1 - i]; // новые сверху
            final isBest = l.timeMs == _best && l.valid;
            return InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => _showLapDetail(l, isBest),
              child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF161C27), borderRadius: BorderRadius.circular(9),
                border: Border.all(color: isBest ? C.accent2 : (l.valid ? C.line : C.red.withValues(alpha: 0.4)))),
              child: Row(children: [
                SizedBox(width: 38, child: Text('L${l.lap}', style: const TextStyle(color: C.muted))),
                Text(fmtLap(l.timeMs), style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold,
                  color: isBest ? C.accent2 : (l.valid ? C.txt : C.muted))),
                const SizedBox(width: 10),
                if (isBest) const Text('★', style: TextStyle(color: C.accent2)),
                const Spacer(),
                Text('${l.s1 > 0 ? (l.s1/1000).toStringAsFixed(1) : "-"} / '
                     '${l.s2 > 0 ? (l.s2/1000).toStringAsFixed(1) : "-"} / '
                     '${l.s3 > 0 ? (l.s3/1000).toStringAsFixed(1) : "-"}',
                  style: const TextStyle(color: C.muted, fontSize: 12)),
                const SizedBox(width: 8),
                Text(l.compound.isNotEmpty ? l.compound[0] : '',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ));
          },
        )),
      ]),
    );
  }

  void _showLapDetail(LapRecord l, bool isBest) {
    Widget kv(String k, String v, [Color? c]) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(k, style: const TextStyle(color: C.muted, fontSize: 14)),
        Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: c)),
      ]),
    );
    showModalBottomSheet(
      context: context, backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('Круг ${l.lap}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            if (isBest) const Text('★ лучший', style: TextStyle(color: C.accent2, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (!l.valid) const Text('НЕВАЛИДНЫЙ', style: TextStyle(color: C.red, fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
          const SizedBox(height: 14),
          kv('Время круга', fmtLap(l.timeMs), isBest ? C.accent2 : C.txt),
          kv('Сектор 1', l.s1 > 0 ? fmtSec(l.s1) : '—'),
          kv('Сектор 2', l.s2 > 0 ? fmtSec(l.s2) : '—'),
          kv('Сектор 3', l.s3 > 0 ? fmtSec(l.s3) : '—'),
          const Divider(color: C.line, height: 24),
          kv('Шины', l.compound),
          kv('Возраст шин', '${l.tyreAge} кр.'),
          kv('Сессия', l.session),
          kv('Валидный', l.valid ? 'да' : 'нет'),
          kv('Записан', l.ts.replaceFirst('T', ' ')),
        ]),
      ),
    );
  }

  Widget _stat(String l, String v) => Column(children: [
    Text(l, style: const TextStyle(fontSize: 10, color: C.muted, letterSpacing: 1.5)),
    Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
  ]);
}

class _AnalysisSheet extends StatefulWidget {
  final AppSettings settings;
  final int trackId;
  final List<LapRecord> laps;
  const _AnalysisSheet({required this.settings, required this.trackId, required this.laps});
  @override
  State<_AnalysisSheet> createState() => _AnalysisSheetState();
}

class _AnalysisSheetState extends State<_AnalysisSheet> {
  AiResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() => _loading = true);
    final r = await analyze(
      apiKey: widget.settings.apiKey, model: widget.settings.model,
      trackId: widget.trackId, laps: widget.laps);
    if (mounted) setState(() { _result = r; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false, initialChildSize: 0.7, maxChildSize: 0.92,
      builder: (context, scroll) => Padding(
        padding: const EdgeInsets.all(18),
        child: ListView(controller: scroll, children: [
          Row(children: [
            const Text('🏁 AI-анализ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (!_loading) IconButton(onPressed: _run, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: Column(children: [
              CircularProgressIndicator(), SizedBox(height: 14),
              Text('Инженер изучает твои круги…', style: TextStyle(color: C.muted)),
            ])))
          else if (_result != null && !_result!.ok)
            Text('Ошибка: ${_result!.text}', style: const TextStyle(color: C.red))
          else if (_result != null) ...[
            Text(_result!.text, style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 20),
            ExpansionTile(title: const Text('Сырые данные', style: TextStyle(color: C.muted)),
              children: [Text(_result!.summary, style: const TextStyle(color: C.muted, fontSize: 12))]),
          ],
        ]),
      ),
    );
  }
}
