import 'package:flutter/material.dart';
import '../game_state.dart';
import '../theme.dart';
import '../appendices.dart';

// Накопитель контура: bucket(lapDist) -> точка. Живёт в состоянии экрана.
class TrackBuffer {
  static const bucket = 12.0;
  final Map<int, Offset> byDist = {};
  int trackLen = 4000;
  double minX = 0, maxX = 1, minZ = 0, maxZ = 1;

  void feed(GameState st) {
    final me = st.cars[st.safePlayerIndex];
    if (me.x == null) return;
    final d = me.lapDistance;
    if (d < 0) return;
    if (st.session.trackLength > 0) trackLen = st.session.trackLength;
    byDist[(d / bucket).round()] = Offset(me.x!, me.z!);
    _bounds();
  }

  void _bounds() {
    if (byDist.length < 2) return;
    minX = 1e9; maxX = -1e9; minZ = 1e9; maxZ = -1e9;
    for (final p in byDist.values) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minZ) minZ = p.dy;
      if (p.dy > maxZ) maxZ = p.dy;
    }
  }

  double get coverage => byDist.length / (trackLen / bucket);
}

class TrackMapPainter extends CustomPainter {
  final TrackBuffer buf;
  final GameState st;
  TrackMapPainter(this.buf, this.st);

  Offset _proj(Offset p, Size size) {
    const pad = 26.0;
    final w = size.width - pad * 2, h = size.height - pad * 2;
    final bw = (buf.maxX - buf.minX).abs() < 1 ? 1 : buf.maxX - buf.minX;
    final bh = (buf.maxZ - buf.minZ).abs() < 1 ? 1 : buf.maxZ - buf.minZ;
    final sc = (w / bw < h / bh) ? w / bw : h / bh;
    final ox = pad + (w - bw * sc) / 2;
    final oz = pad + (h - bh * sc) / 2;
    return Offset(ox + (p.dx - buf.minX) * sc, oz + (p.dy - buf.minZ) * sc);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pts = (buf.byDist.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key)))
        .map((e) => e.value)
        .toList();
    if (pts.length > 5) {
      final path = Path();
      for (int i = 0; i < pts.length; i++) {
        final o = _proj(pts[i], size);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      if (buf.coverage > 0.9) path.close();
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = C.line);
      canvas.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF39465A));
    }
    // машины
    for (final c in st.cars) {
      if (c.x == null || c.resultStatus == 1) continue;
      final o = _proj(Offset(c.x!, c.z!), size);
      final isPlayer = st.cars.indexOf(c) == st.safePlayerIndex;
      canvas.drawCircle(o, isPlayer ? 8 : 5,
          Paint()..color = c.teamId >= 0 ? teamColor(c.teamId) : const Color(0xFF888888));
      if (isPlayer) {
        canvas.drawCircle(o, 8,
            Paint()..style = PaintingStyle.stroke ..strokeWidth = 2.5 ..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant TrackMapPainter old) => true;
}
