// Локальная запись всех кругов — файл на каждую трассу в папке документов.
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'appendices.dart';
import 'game_state.dart';

class LapRecord {
  final String ts, compound, session;
  final int lap, timeMs, s1, s2, s3, tyreAge;
  final bool valid;
  LapRecord({
    required this.ts, required this.lap, required this.timeMs,
    required this.s1, required this.s2, required this.s3,
    required this.compound, required this.tyreAge,
    required this.valid, required this.session,
  });

  Map<String, dynamic> toJson() => {
    'ts': ts, 'lap': lap, 'timeMs': timeMs, 's1': s1, 's2': s2, 's3': s3,
    'compound': compound, 'tyreAge': tyreAge, 'valid': valid, 'session': session,
  };

  factory LapRecord.fromJson(Map<String, dynamic> j) => LapRecord(
    ts: j['ts'] ?? '', lap: j['lap'] ?? 0, timeMs: j['timeMs'] ?? 0,
    s1: j['s1'] ?? 0, s2: j['s2'] ?? 0, s3: j['s3'] ?? 0,
    compound: j['compound'] ?? '?', tyreAge: j['tyreAge'] ?? 0,
    valid: j['valid'] ?? false, session: j['session'] ?? '?',
  );
}

class TrackSummary {
  final int trackId;
  final String name;
  final int count;
  final int? bestMs;
  TrackSummary(this.trackId, this.name, this.count, this.bestMs);
}

class LapStore {
  Directory? _dir;
  // состояние детектора смены круга
  int? _prevLap;
  int _s1 = 0, _s2 = 0;

  Future<void> init() async {
    final base = await getApplicationDocumentsDirectory();
    _dir = Directory('${base.path}/laps');
    if (!await _dir!.exists()) await _dir!.create(recursive: true);
  }

  File _file(int trackId) => File('${_dir!.path}/track_$trackId.jsonl');

  /// Кормить снимком каждый тик — пишет завершённый круг при смене.
  Future<void> feed(SessionData s, PlayerData p) async {
    if (_dir == null) return;
    if (p.sector >= 1 && p.s1 > 0) _s1 = p.s1;
    if (p.sector >= 2 && p.s2 > 0) _s2 = p.s2;

    final lapNum = p.curLapNum;
    if (_prevLap == null) { _prevLap = lapNum; return; }
    if (lapNum == _prevLap) return;

    final completed = _prevLap!;
    _prevLap = lapNum;
    final s1 = _s1, s2 = _s2;
    _s1 = 0; _s2 = 0;

    final last = p.lastLapMs;
    if (last <= 0 || last > 600000) return;
    var s3 = last - s1 - s2;
    if (s3 <= 0 || s3 > 200000) s3 = 0;

    final rec = LapRecord(
      ts: DateTime.now().toIso8601String().split('.').first,
      lap: completed, timeMs: last, s1: s1, s2: s2, s3: s3,
      compound: kCompoundName[p.compound] ?? '?',
      tyreAge: p.tyreAge, valid: p.lapInvalid == 0,
      session: kSessionTypes[s.sessionType] ?? '?',
    );
    try {
      await _file(s.trackId).writeAsString(
        '${jsonEncode(rec.toJson())}\n',
        mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  Future<List<LapRecord>> readLaps(int trackId) async {
    if (_dir == null) return [];
    final f = _file(trackId);
    if (!await f.exists()) return [];
    final out = <LapRecord>[];
    for (final line in await f.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try { out.add(LapRecord.fromJson(jsonDecode(line))); } catch (_) {}
    }
    return out;
  }

  Future<List<TrackSummary>> listTracks() async {
    if (_dir == null) return [];
    final out = <TrackSummary>[];
    for (final e in _dir!.listSync()) {
      if (e is! File || !e.path.endsWith('.jsonl')) continue;
      final m = RegExp(r'track_(\d+)\.jsonl').firstMatch(e.path);
      if (m == null) continue;
      final tid = int.parse(m.group(1)!);
      final laps = await readLaps(tid);
      if (laps.isEmpty) continue;
      final valid = laps.where((l) => l.valid && l.timeMs > 0).map((l) => l.timeMs);
      out.add(TrackSummary(tid, kTracks[tid] ?? 'Track $tid', laps.length,
          valid.isEmpty ? null : valid.reduce((a, b) => a < b ? a : b)));
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  Future<void> clearTrack(int trackId) async {
    final f = _file(trackId);
    if (await f.exists()) await f.delete();
  }
}
