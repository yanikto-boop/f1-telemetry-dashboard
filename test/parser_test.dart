// Проверка смещений парсера на синтетических пакетах формата 2025.
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:f1telemetry/game_state.dart';
import 'package:f1telemetry/parser.dart';

ByteData _withHeader(int packetId, int totalLen) {
  final d = ByteData(totalLen);
  d.setUint16(0, 2025, Endian.little); // format
  d.setUint8(6, packetId);             // packetId @ offset 6
  d.setUint8(27, 0);                   // playerCarIndex = 0
  return d;
}

void main() {
  test('header: packetId и playerIndex читаются с верных смещений', () {
    final d = _withHeader(6, 29);
    final h = parseHeader(d)!;
    expect(h.format, 2025);
    expect(h.packetId, 6);
    expect(h.playerCarIndex, 0);
  });

  test('telemetry: поля игрока', () {
    const total = 29 + 60 * 22 + 3;
    final d = _withHeader(6, total);
    int o = 29; // car0
    d.setUint16(o, 300, Endian.little);      // speed
    d.setFloat32(o + 2, 1.0, Endian.little); // throttle
    d.setFloat32(o + 6, 0.0, Endian.little); // steer
    d.setFloat32(o + 10, 0.5, Endian.little);// brake
    d.setUint8(o + 14, 0);                   // clutch
    d.setInt8(o + 15, 7);                    // gear
    d.setUint16(o + 16, 11000, Endian.little);// rpm
    d.setUint8(o + 18, 1);                   // drs
    d.setUint8(o + 19, 0);                   // revPercent
    d.setUint16(o + 20, 0, Endian.little);   // revBits
    // brakesTemp 4H @ o+22 (8) -> surfaceTemp 4B @ o+30
    d.setUint8(o + 30, 90);
    // innerTemp 4B @ o+34; engineTemp H @ o+38; pressure 4f @ o+40
    d.setFloat32(o + 40, 23.5, Endian.little);

    final st = GameState();
    parsePacket(d.buffer.asUint8List(), st);
    expect(st.player.speed, 300);
    expect(st.player.gear, 7);
    expect(st.player.rpm, 11000);
    expect(st.player.drs, 1);
    expect(st.player.tyreSurfaceTemp[0], 90);
    expect(st.player.tyrePressure[0], closeTo(23.5, 0.05));
  });

  test('lap: позиция, круг, сектор, resultStatus', () {
    const total = 29 + 57 * 22 + 2;
    final d = _withHeader(2, total);
    int o = 29; // car0
    d.setUint32(o, 90500, Endian.little);    // lastLap
    d.setUint32(o + 4, 12345, Endian.little);// cur
    // секторы @ o+8.. ; lapDist f32 @ o+20
    d.setFloat32(o + 20, 1234.5, Endian.little);
    // 15-байтовый блок начинается на o+32
    d.setUint8(o + 32, 1);  // carPosition
    d.setUint8(o + 33, 5);  // currentLapNum
    d.setUint8(o + 36, 2);  // sector (o+32+4)
    d.setUint8(o + 45, 2);  // resultStatus (14-й байт блока: o+32+13)

    final st = GameState();
    parsePacket(d.buffer.asUint8List(), st);
    expect(st.player.lastLapMs, 90500);
    expect(st.player.position, 1);
    expect(st.player.curLapNum, 5);
    expect(st.player.sector, 2);
    expect(st.cars[0].resultStatus, 2);
    expect(st.cars[0].lapDistance, closeTo(1234.5, 0.1));
  });
}
