// Трекер темпа: лучшие секторы за сессию, «идеальный круг» и live-дельта.
// Кормится снимком каждый тик из дашборда (как TrackBuffer).
import 'game_state.dart';

class PaceTracker {
  int bestS1 = 0, bestS2 = 0, bestS3 = 0, bestLapMs = 0;

  // live-дельта к лучшему кругу на последнем закрытом секторе (мс, +/-)
  int? liveDeltaMs;

  int _prevSector = -1;
  int? _prevLap;
  int _curS1 = 0, _curS2 = 0;

  void feed(GameState st) {
    final p = st.player;

    // закрытие сектора 1 (0 -> 1)
    if (_prevSector == 0 && p.sector == 1 && p.s1 > 0) {
      _curS1 = p.s1;
      if (bestS1 == 0 || _curS1 < bestS1) bestS1 = _curS1;
      _updateDelta(1);
    }
    // закрытие сектора 2 (1 -> 2)
    if (_prevSector == 1 && p.sector == 2 && p.s2 > 0) {
      _curS2 = p.s2;
      if (bestS2 == 0 || _curS2 < bestS2) bestS2 = _curS2;
      _updateDelta(2);
    }
    _prevSector = p.sector;

    // смена круга — закрываем сектор 3 по lastLap
    if (_prevLap != null && p.curLapNum != _prevLap) {
      final last = p.lastLapMs;
      if (last > 0 && last < 600000) {
        if (bestLapMs == 0 || last < bestLapMs) bestLapMs = last;
        final s3 = last - _curS1 - _curS2;
        if (s3 > 0 && s3 < 200000 && (bestS3 == 0 || s3 < bestS3)) bestS3 = s3;
      }
      _curS1 = 0; _curS2 = 0;
      liveDeltaMs = null;
    }
    _prevLap = p.curLapNum;
  }

  // дельта суммы закрытых секторов к сумме лучших секторов
  void _updateDelta(int sectorsDone) {
    if (bestS1 == 0) { liveDeltaMs = null; return; }
    if (sectorsDone == 1) {
      liveDeltaMs = _curS1 - bestS1;
    } else if (sectorsDone == 2 && bestS2 > 0) {
      liveDeltaMs = (_curS1 + _curS2) - (bestS1 + bestS2);
    }
  }

  // «идеальный круг» = сумма лучших секторов (0 если не хватает данных)
  int get idealMs =>
      (bestS1 > 0 && bestS2 > 0 && bestS3 > 0) ? bestS1 + bestS2 + bestS3 : 0;
}
