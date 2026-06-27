import 'package:flutter/material.dart';

import '../appendices.dart';
import '../game_state.dart';
import '../pace.dart';
import '../theme.dart';
import '../udp_service.dart';
import '../widgets/track_map.dart';

class DashboardScreen extends StatefulWidget {
  final UdpService service;
  const DashboardScreen({super.key, required this.service});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _buf = TrackBuffer();
  final _pace = PaceTracker();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.service,
      builder: (context, _) {
        final st = widget.service.state;
        _buf.feed(st);
        _pace.feed(st);
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _statusBar(st),
            const SizedBox(height: 12),
            _clusterCard(st.player),
            const SizedBox(height: 12),
            _mapCard(st),
            const SizedBox(height: 12),
            _timingCard(st),
            const SizedBox(height: 12),
            _tyresCard(st.player),
            const SizedBox(height: 12),
            _ersCard(st.player),
            const SizedBox(height: 12),
            _leaderboard(st),
            const SizedBox(height: 12),
            _events(st),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _card(Widget child) =>
      Container(decoration: cardDeco(), padding: const EdgeInsets.all(14), child: child);

  Widget _statusBar(GameState st) {
    final s = st.session;
    final live = widget.service.live;
    Widget chip(String l, String v) => Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: C.card2, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: C.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l, style: const TextStyle(fontSize: 9, color: C.muted, letterSpacing: 1.5)),
        Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
    );
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 11, height: 11, decoration: BoxDecoration(
          shape: BoxShape.circle, color: live ? C.green : Colors.grey)),
        const SizedBox(width: 8),
        const Text('F1 ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const Text('25', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: C.accent)),
        const SizedBox(width: 8),
        Text(live ? 'LIVE' : 'НЕТ СИГНАЛА',
          style: TextStyle(fontSize: 11, letterSpacing: 2, color: live ? C.green : C.muted)),
      ]),
      const SizedBox(height: 10),
      Wrap(children: [
        chip('TRACK', kTracks[s.trackId] ?? '—'),
        chip('SESSION', kSessionTypes[s.sessionType] ?? '—'),
        chip('WEATHER', kWeather[s.weather] ?? '—'),
        chip('AIR', '${s.airTemp}°'),
        chip('TRACK°', '${s.trackTemp}°'),
        chip('LAPS', s.totalLaps > 0 ? '${s.totalLaps}' : '—'),
      ]),
    ]));
  }

  Widget _clusterCard(PlayerData p) {
    return _card(Column(children: [
      _revBar(p.revLights),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${p.speed}', style: const TextStyle(
            fontSize: 64, fontWeight: FontWeight.w900, height: 0.9)),
          const Text('KM/H', style: TextStyle(fontSize: 12, color: C.muted, letterSpacing: 3)),
        ])),
        Text(p.gear > 0 ? '${p.gear}' : (p.gear == 0 ? 'N' : 'R'),
          style: const TextStyle(fontSize: 80, fontWeight: FontWeight.w900, color: C.accent2)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _pedal('BRK', p.brake, C.red),
        const SizedBox(width: 10),
        Expanded(child: _steer(p.steer)),
        const SizedBox(width: 10),
        _pedal('THR', p.throttle, C.green),
      ]),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: p.drs == 1 ? C.green : C.card2,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: p.drs == 1 ? C.green : (p.drsAllowed == 1 ? C.yellow : C.line))),
          child: Text('DRS', style: TextStyle(fontWeight: FontWeight.bold,
            color: p.drs == 1 ? Colors.black : (p.drsAllowed == 1 ? C.yellow : C.muted))),
        ),
        Text('${p.rpm} RPM', style: const TextStyle(color: C.muted, fontWeight: FontWeight.bold)),
      ]),
    ]));
  }

  Widget _revBar(int bits) {
    return Row(children: List.generate(15, (i) {
      final on = (bits >> i) & 1 == 1;
      Color col = const Color(0xFF1D2530);
      if (on) col = i < 6 ? C.green : (i < 11 ? C.yellow : C.red);
      return Expanded(child: Container(
        height: 14, margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(3)),
      ));
    }));
  }

  Widget _pedal(String label, double v, Color color) {
    return Column(children: [
      Container(
        width: 30, height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF161C27), borderRadius: BorderRadius.circular(7),
          border: Border.all(color: C.line)),
        alignment: Alignment.bottomCenter,
        child: FractionallySizedBox(
          heightFactor: v.clamp(0, 1), widthFactor: 1,
          child: Container(decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(6))),
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: C.muted)),
    ]);
  }

  Widget _steer(double v) {
    return Column(children: [
      LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        return Container(
          height: 14, width: w,
          decoration: BoxDecoration(
            color: const Color(0xFF161C27), borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.line)),
          child: Stack(children: [
            Positioned(
              left: (w / 2 - 8 + v * (w / 2 - 8)).clamp(0, w - 16),
              top: -2,
              child: Container(width: 16, height: 16, decoration: const BoxDecoration(
                color: C.accent2, shape: BoxShape.circle)),
            ),
          ]),
        );
      }),
      const SizedBox(height: 4),
      const Text('STEER', style: TextStyle(fontSize: 10, color: C.muted)),
    ]);
  }

  Widget _mapCard(GameState st) {
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      cardTitle('TRACK MAP'),
      AspectRatio(
        aspectRatio: 1.4,
        child: CustomPaint(painter: TrackMapPainter(_buf, st), size: Size.infinite),
      ),
    ]));
  }

  Widget _timingCard(GameState st) {
    final p = st.player;
    Widget row(String l, String v, [Color? c]) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: const TextStyle(color: C.muted, fontSize: 13)),
        Text(v, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: c)),
      ]),
    );
    int best = 0;
    final h = st.history[st.safePlayerIndex];
    if (h != null && h.isNotEmpty) {
      // отбрасываем мусорные значения (10 мин = заведомо не круг)
      final valid = h.where((e) => e > 0 && e < 600000);
      if (valid.isNotEmpty) best = valid.reduce((a, b) => a < b ? a : b);
    }
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      cardTitle('TIMING'),
      Center(child: Text(fmtLap(p.curLapMs), style: TextStyle(
        fontSize: 40, fontWeight: FontWeight.w900,
        color: p.lapInvalid == 1 ? C.red : C.txt))),
      const SizedBox(height: 6),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('P${p.position}', style: const TextStyle(
          fontSize: 28, fontWeight: FontWeight.w900, color: C.accent2)),
        Text('LAP ${p.curLapNum}${st.session.totalLaps > 0 ? ' / ${st.session.totalLaps}' : ''}',
          style: const TextStyle(color: C.muted, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        // 0 = ещё не доехал, 1 = едет сейчас (жёлтый), 2 = закрыт (зелёный)
        _sectorBox('S1', p.s1, p.s1 > 0 ? 2 : (p.sector == 0 ? 1 : 0)),
        const SizedBox(width: 6),
        _sectorBox('S2', p.s2, p.s2 > 0 ? 2 : (p.sector == 1 ? 1 : 0)),
        const SizedBox(width: 6),
        _sectorBox('S3', 0, p.sector == 2 ? 1 : 0),
      ]),
      const SizedBox(height: 8),
      if (_pace.liveDeltaMs != null) _deltaBanner(_pace.liveDeltaMs!),
      row('LAST', fmtLap(p.lastLapMs)),
      row('BEST', fmtLap(best), C.accent2),
      if (_pace.idealMs > 0)
        row('ИДЕАЛ', fmtLap(_pace.idealMs), C.yellow),
      row('Δ LEADER', p.deltaLeaderMs > 0 ? '+${(p.deltaLeaderMs/1000).toStringAsFixed(3)}' : '—'),
      row('Δ FRONT', p.deltaFrontMs > 0 ? '+${(p.deltaFrontMs/1000).toStringAsFixed(3)}' : '—'),
    ]));
  }

  // live-дельта к лучшему кругу — зелёный быстрее, красный медленнее
  Widget _deltaBanner(int ms) {
    final faster = ms < 0;
    final col = faster ? C.green : C.red;
    final s = '${faster ? '−' : '+'}${(ms.abs() / 1000).toStringAsFixed(3)}';
    return Container(
      width: double.infinity, margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9),
        border: Border.all(color: col)),
      child: Center(child: Text('Δ BEST  $s',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: col))),
    );
  }

  Widget _sectorBox(String l, int ms, int state) {
    // state: 0 — впереди, 1 — текущий сектор (жёлтый), 2 — закрыт (зелёный)
    final accent = state == 2 ? C.green : (state == 1 ? C.yellow : C.line);
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: state == 0 ? const Color(0xFF161C27) : accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: accent)),
      child: Column(children: [
        Text(l, style: const TextStyle(fontSize: 11, color: C.muted)),
        Text(ms > 0 ? fmtSec(ms) : (state == 1 ? '…' : '--.---'),
          style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    ));
  }

  Widget _tyresCard(PlayerData p) {
    // порядок RL,RR,FL,FR -> индексы 0,1,2,3
    Widget tyre(String label, int i) {
      final t = i < p.tyreSurfaceTemp.length ? p.tyreSurfaceTemp[i] : 0;
      final w = i < p.tyreWear.length ? p.tyreWear[i] : 0.0;
      final pr = i < p.tyrePressure.length ? p.tyrePressure[i] : 0.0;
      return Column(children: [
        Stack(alignment: Alignment.topLeft, children: [
          Container(width: 54, height: 66, decoration: BoxDecoration(
            color: tempColor(t), borderRadius: BorderRadius.circular(11),
            boxShadow: [BoxShadow(color: tempColor(t).withValues(alpha: 0.4), blurRadius: 14)])),
          Padding(padding: const EdgeInsets.all(5), child: Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold))),
          Positioned.fill(child: Center(child: Text('$t°',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)))),
        ]),
        const SizedBox(height: 4),
        Text('${w.round()}%', style: TextStyle(fontWeight: FontWeight.bold, color: wearColor(w))),
        Text('${pr.toStringAsFixed(1)} psi', style: const TextStyle(fontSize: 11, color: C.muted)),
      ]);
    }
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        cardTitle('TYRES'),
        const Spacer(),
        Text(kCompoundName[p.compound] ?? '—',
          style: TextStyle(color: compoundColor(p.compound), fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text('${p.tyreAge} laps', style: const TextStyle(color: C.muted, fontSize: 12)),
      ]),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [tyre('FL', 2), tyre('FR', 3)]),
      const SizedBox(height: 14),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [tyre('RL', 0), tyre('RR', 1)]),
    ]));
  }

  Widget _ersCard(PlayerData p) {
    final pct = (p.ersStore / 4000000 * 100).clamp(0, 100).toDouble();
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      cardTitle('ERS & FUEL'),
      Stack(children: [
        Container(height: 30, decoration: BoxDecoration(
          color: const Color(0xFF161C27), borderRadius: BorderRadius.circular(9),
          border: Border.all(color: C.line))),
        FractionallySizedBox(
          widthFactor: pct / 100,
          child: Container(height: 30, decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF7C3AED), C.accent2]),
            borderRadius: BorderRadius.circular(9))),
        ),
        Positioned.fill(child: Align(alignment: Alignment.centerRight,
          child: Padding(padding: const EdgeInsets.only(right: 12),
            child: Text('${pct.round()}%', style: const TextStyle(fontWeight: FontWeight.bold))))),
      ]),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('DEPLOY', style: TextStyle(color: C.muted)),
        Text(kErsModes[p.ersMode] ?? '—', style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('FUEL', style: TextStyle(color: C.muted)),
        Text('${p.fuelLaps.toStringAsFixed(2)} laps', style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    ]));
  }

  Widget _leaderboard(GameState st) {
    // Time Trial: позиций нет, есть ты + гост(ы) — отдельная раскладка
    if (st.session.sessionType == 18) return _timeTrialBoard(st);
    final cars = st.cars.asMap().entries
        .where((e) => e.value.active && e.value.position > 0 && e.value.resultStatus != 1)
        .toList()
      ..sort((a, b) => a.value.position.compareTo(b.value.position));
    final top = cars.take(12).toList();
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      cardTitle('LEADERBOARD'),
      ...top.map((e) {
        final i = e.key; final c = e.value;
        final me = i == st.safePlayerIndex;
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: me ? C.accent2.withValues(alpha: 0.08) : const Color(0xFF161C27),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: me ? C.accent2 : Colors.transparent)),
          child: Row(children: [
            SizedBox(width: 26, child: Text('${c.position}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: C.muted))),
            Container(width: 5, height: 18, margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: c.teamId >= 0 ? teamColor(c.teamId) : C.muted,
                borderRadius: BorderRadius.circular(3))),
            Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(c.position == 1 ? 'LEADER' : '+${(c.deltaLeaderMs/1000).toStringAsFixed(3)}',
              style: const TextStyle(color: C.muted, fontSize: 13)),
            const SizedBox(width: 8),
            Text(kCompoundShort[c.visualCompound] ?? '',
              style: TextStyle(fontWeight: FontWeight.bold, color: compoundColor(c.visualCompound))),
          ]),
        );
      }),
      if (top.isEmpty) const Text('—', style: TextStyle(color: C.muted)),
    ]));
  }

  // Time Trial — ты и гост(ы) с лучшим временем, без позиций
  Widget _timeTrialBoard(GameState st) {
    int bestOf(int idx) {
      final h = st.history[idx];
      final v = (h ?? const <int>[]).where((e) => e > 0 && e < 600000);
      if (v.isNotEmpty) return v.reduce((a, b) => a < b ? a : b);
      return st.cars[idx].lastLapMs;
    }
    final rows = st.cars.asMap().entries
        .where((e) => e.value.active && e.value.name.isNotEmpty)
        .map((e) => (idx: e.key, car: e.value, best: bestOf(e.key)))
        .where((r) => r.best > 0)
        .toList()
      ..sort((a, b) => a.best.compareTo(b.best));
    final leader = rows.isEmpty ? 0 : rows.first.best;
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      cardTitle('TIME TRIAL'),
      if (rows.isEmpty) const Text('Проедь круг — появятся времена', style: TextStyle(color: C.muted)),
      ...rows.map((r) {
        final me = r.idx == st.safePlayerIndex;
        final gap = r.best - leader;
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: me ? C.accent2.withValues(alpha: 0.08) : const Color(0xFF161C27),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: me ? C.accent2 : Colors.transparent)),
          child: Row(children: [
            Expanded(child: Text(me ? '${r.car.name} (ты)' : r.car.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, color: me ? C.accent2 : C.txt))),
            Text(fmtLap(r.best), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            SizedBox(width: 64, child: Text(
              gap == 0 ? 'BEST' : '+${(gap/1000).toStringAsFixed(3)}',
              textAlign: TextAlign.right,
              style: TextStyle(color: gap == 0 ? C.accent2 : C.muted, fontSize: 13))),
          ]),
        );
      }),
    ]));
  }

  Widget _events(GameState st) {
    final ev = st.events.reversed.take(6).toList();
    return _card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      cardTitle('EVENTS'),
      if (ev.isEmpty) const Text('Ожидание событий…', style: TextStyle(color: C.muted)),
      ...ev.map((e) => Padding(padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(e.text, style: const TextStyle(fontSize: 13)))),
    ]));
  }
}
