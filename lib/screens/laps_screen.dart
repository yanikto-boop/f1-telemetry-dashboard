import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _validOnly = false;
  String? _compound;            // фильтр по шинам (null = все)
  bool _selecting = false;      // режим сравнения
  final List<LapRecord> _selected = [];

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

  // --- производные данные ---
  List<LapRecord> get _filtered => _laps.where((l) {
    if (_validOnly && !l.valid) return false;
    if (_compound != null && l.compound != _compound) return false;
    return true;
  }).toList();

  Iterable<LapRecord> get _validLaps => _laps.where((l) => l.valid && l.timeMs > 0);
  int _bestSector(int Function(LapRecord) sel) {
    final v = _validLaps.map(sel).where((x) => x > 0);
    return v.isEmpty ? 0 : v.reduce((a, b) => a < b ? a : b);
  }
  int get _bs1 => _bestSector((l) => l.s1);
  int get _bs2 => _bestSector((l) => l.s2);
  int get _bs3 => _bestSector((l) => l.s3);
  int get _ideal => (_bs1 > 0 && _bs2 > 0 && _bs3 > 0) ? _bs1 + _bs2 + _bs3 : 0;
  List<String> get _compounds =>
      _laps.map((l) => l.compound).where((c) => c.isNotEmpty).toSet().toList()..sort();

  void _analyze() {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _AnalysisSheet(
        settings: widget.settings, trackId: widget.trackId, laps: _laps),
    );
  }

  void _tapLap(LapRecord l, bool isBest) {
    if (!_selecting) { _showLapDetail(l, isBest); return; }
    setState(() {
      if (_selected.contains(l)) {
        _selected.remove(l);
      } else if (_selected.length < 2) {
        _selected.add(l);
      }
    });
    if (_selected.length == 2) {
      final a = _selected[0], b = _selected[1];
      setState(() { _selecting = false; _selected.clear(); });
      _showCompare(a, b);
    }
  }

  void _showCompare(LapRecord a, LapRecord b) {
    showModalBottomSheet(
      context: context, backgroundColor: C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => _CompareSheet(a: a, b: b, track: widget.name),
    );
  }

  @override
  Widget build(BuildContext context) {
    final laps = _filtered;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name), actions: [
        IconButton(
          tooltip: _selecting ? 'Отмена' : 'Сравнить два круга',
          icon: Icon(_selecting ? Icons.close : Icons.compare_arrows),
          onPressed: () => setState(() { _selecting = !_selecting; _selected.clear(); })),
        IconButton(tooltip: 'Удалить все круги', icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            await widget.store.clearTrack(widget.trackId);
            if (context.mounted) Navigator.pop(context);
          }),
      ]),
      floatingActionButton: _selecting ? null : FloatingActionButton.extended(
        backgroundColor: C.accent, onPressed: _laps.isEmpty ? null : _analyze,
        icon: const Text('🏁', style: TextStyle(fontSize: 18)),
        label: const Text('AI-анализ', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        Container(
          width: double.infinity, margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14), decoration: cardDeco(),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _stat('КРУГОВ', '${_laps.length}'),
              _stat('ЛУЧШИЙ', _best != null ? fmtLap(_best!) : '—'),
              _stat('ИДЕАЛ', _ideal > 0 ? fmtLap(_ideal) : '—', C.yellow),
            ]),
            if (_bs1 > 0 || _bs2 > 0 || _bs3 > 0) ...[
              const SizedBox(height: 12),
              Row(children: [
                _bestSecBox('S1', _bs1), const SizedBox(width: 6),
                _bestSecBox('S2', _bs2), const SizedBox(width: 6),
                _bestSecBox('S3', _bs3),
              ]),
            ],
          ]),
        ),
        _trendChart(),
        _filterBar(),
        if (_selecting)
          Container(
            width: double.infinity, color: C.accent.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Выбери 2 круга для сравнения  (${_selected.length}/2)',
              textAlign: TextAlign.center, style: const TextStyle(color: C.accent, fontWeight: FontWeight.bold))),
        Expanded(child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: laps.length,
          itemBuilder: (context, i) {
            final l = laps[laps.length - 1 - i]; // новые сверху
            final isBest = l.timeMs == _best && l.valid;
            final sel = _selected.contains(l);
            return InkWell(
              borderRadius: BorderRadius.circular(9),
              onTap: () => _tapLap(l, isBest),
              child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? C.accent.withValues(alpha: 0.18) : const Color(0xFF161C27),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: sel ? C.accent
                  : (isBest ? C.accent2 : (l.valid ? C.line : C.red.withValues(alpha: 0.4))))),
              child: Row(children: [
                if (_selecting) Padding(padding: const EdgeInsets.only(right: 8),
                  child: Icon(sel ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18, color: sel ? C.accent : C.muted)),
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

  Widget _bestSecBox(String l, int ms) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFF161C27), borderRadius: BorderRadius.circular(8),
      border: Border.all(color: C.line)),
    child: Column(children: [
      Text(l, style: const TextStyle(fontSize: 10, color: C.muted)),
      Text(ms > 0 ? fmtSec(ms) : '—',
        style: const TextStyle(fontWeight: FontWeight.bold, color: C.yellow)),
    ]),
  ));

  // мини-график времён валидных кругов (видно деградацию по стинту)
  Widget _trendChart() {
    final pts = <FlSpot>[];
    int n = 0;
    for (final l in _laps) {
      if (l.valid && l.timeMs > 0) pts.add(FlSpot((n++).toDouble(), l.timeMs / 1000));
    }
    if (pts.length < 2) return const SizedBox.shrink();
    final ys = pts.map((p) => p.y);
    final lo = ys.reduce((a, b) => a < b ? a : b);
    final hi = ys.reduce((a, b) => a > b ? a : b);
    return Container(
      height: 120, margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(8, 14, 14, 8), decoration: cardDeco(),
      child: LineChart(LineChartData(
        minY: lo - 0.3, maxY: hi + 0.3,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [LineChartBarData(
          spots: pts, isCurved: true, barWidth: 2.5, color: C.accent2,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: C.accent2.withValues(alpha: 0.10)),
        )],
      )),
    );
  }

  Widget _filterBar() {
    return SizedBox(height: 44, child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: [
        _chip('Только валидные', _validOnly, () => setState(() => _validOnly = !_validOnly)),
        for (final c in _compounds)
          _chip(c, _compound == c, () => setState(() => _compound = _compound == c ? null : c)),
      ],
    ));
  }

  Widget _chip(String label, bool on, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label), selected: on, onSelected: (_) => onTap(),
      backgroundColor: const Color(0xFF161C27),
      selectedColor: C.accent.withValues(alpha: 0.25),
      labelStyle: TextStyle(color: on ? C.accent : C.muted, fontWeight: FontWeight.bold),
      side: BorderSide(color: on ? C.accent : C.line),
    ),
  );

  void _showLapDetail(LapRecord l, bool isBest) {
    final cardKey = GlobalKey();
    showModalBottomSheet(
      context: context, backgroundColor: C.card, isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          RepaintBoundary(
            key: cardKey,
            child: _ShareLapCard(l: l, isBest: isBest, track: widget.name, best: _best),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: C.accent),
            onPressed: () => _shareCard(cardKey, l),
            icon: const Icon(Icons.ios_share),
            label: const Text('Поделиться кругом', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  Future<void> _shareCard(GlobalKey key, LapRecord l) async {
    try {
      final ctx = key.currentContext;
      if (ctx == null) return;
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/lap_${l.lap}_${l.timeMs}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: '${widget.name} — круг ${l.lap}: ${fmtLap(l.timeMs)} 🏎️'));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось поделиться')));
      }
    }
  }

  Widget _stat(String l, String v, [Color? c]) => Column(children: [
    Text(l, style: const TextStyle(fontSize: 10, color: C.muted, letterSpacing: 1.5)),
    Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c)),
  ]);
}

// Красивая карточка круга для шеринга (рендерится в PNG).
class _ShareLapCard extends StatelessWidget {
  final LapRecord l;
  final bool isBest;
  final String track;
  final int? best;
  const _ShareLapCard({required this.l, required this.isBest, required this.track, this.best});

  @override
  Widget build(BuildContext context) {
    Widget sec(String name, int ms) => Column(children: [
      Text(name, style: const TextStyle(fontSize: 11, color: C.muted, letterSpacing: 1)),
      const SizedBox(height: 2),
      Text(ms > 0 ? fmtSec(ms) : '—',
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
    ]);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF12161F), Color(0xFF1B2330)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isBest ? C.accent2 : C.line, width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Text('F1 ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const Text('25', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: C.accent)),
          const Spacer(),
          if (isBest) Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: C.accent2.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20), border: Border.all(color: C.accent2)),
            child: const Text('★ ЛИЧНЫЙ РЕКОРД', style: TextStyle(
              color: C.accent2, fontSize: 10, fontWeight: FontWeight.bold))),
          if (!l.valid) const Text('НЕВАЛИДНЫЙ',
            style: TextStyle(color: C.red, fontSize: 11, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 6),
        Text(track, style: const TextStyle(fontSize: 15, color: C.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text(fmtLap(l.timeMs), style: TextStyle(
          fontSize: 52, fontWeight: FontWeight.w900, height: 1,
          color: isBest ? C.accent2 : C.txt)),
        Text('Круг ${l.lap}', style: const TextStyle(color: C.muted)),
        const Divider(color: C.line, height: 26),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          sec('S1', l.s1), sec('S2', l.s2), sec('S3', l.s3),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _tag('🛞 ${l.compound}'),
          const SizedBox(width: 8),
          _tag('${l.tyreAge} кр.'),
          const SizedBox(width: 8),
          _tag(l.session),
        ]),
      ]),
    );
  }

  Widget _tag(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: const Color(0xFF0E1219),
      borderRadius: BorderRadius.circular(8), border: Border.all(color: C.line)),
    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
  );
}

// Сравнение двух кругов по секторам.
class _CompareSheet extends StatelessWidget {
  final LapRecord a, b;
  final String track;
  const _CompareSheet({required this.a, required this.b, required this.track});

  @override
  Widget build(BuildContext context) {
    Widget row(String label, int av, int bv, {bool lap = false}) {
      final fmt = lap ? fmtLap : fmtSec;
      final delta = (av > 0 && bv > 0) ? bv - av : 0; // b относительно a
      final col = delta == 0 ? C.muted : (delta < 0 ? C.green : C.red);
      final ds = delta == 0 ? '—'
        : '${delta < 0 ? '−' : '+'}${(delta.abs() / 1000).toStringAsFixed(3)}';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          SizedBox(width: 44, child: Text(label, style: const TextStyle(color: C.muted, fontWeight: FontWeight.bold))),
          Expanded(child: Text(av > 0 ? fmt(av) : '—', textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(bv > 0 ? fmt(bv) : '—', textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold))),
          SizedBox(width: 80, child: Text(ds, textAlign: TextAlign.right,
            style: TextStyle(color: col, fontWeight: FontWeight.w900))),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Сравнение кругов', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Δ — насколько круг B быстрее/медленнее A', style: TextStyle(color: C.muted, fontSize: 12)),
        const SizedBox(height: 14),
        Row(children: [
          const SizedBox(width: 44),
          Expanded(child: Text('A · L${a.lap}', textAlign: TextAlign.center,
            style: const TextStyle(color: C.accent2, fontWeight: FontWeight.bold))),
          Expanded(child: Text('B · L${b.lap}', textAlign: TextAlign.center,
            style: const TextStyle(color: C.accent, fontWeight: FontWeight.bold))),
          const SizedBox(width: 80, child: Text('Δ', textAlign: TextAlign.right,
            style: TextStyle(color: C.muted, fontWeight: FontWeight.bold))),
        ]),
        const Divider(color: C.line),
        row('LAP', a.timeMs, b.timeMs, lap: true),
        row('S1', a.s1, b.s1),
        row('S2', a.s2, b.s2),
        row('S3', a.s3, b.s3),
        const Divider(color: C.line, height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Text('A: ${a.compound} · ${a.tyreAge}кр', style: const TextStyle(color: C.muted, fontSize: 12)),
          Text('B: ${b.compound} · ${b.tyreAge}кр', style: const TextStyle(color: C.muted, fontSize: 12)),
        ]),
      ]),
    );
  }
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
