// Парсинг пакетов F1 25 (формат 2025). Порт parser.py на Dart.
// Всё little-endian, packed.
import 'dart:convert';
import 'dart:typed_data';

import 'game_state.dart';
import 'appendices.dart';

class _R {
  final ByteData d;
  int o;
  _R(this.d, this.o);
  int u8() => d.getUint8(o++);
  int i8() => d.getInt8(o++);
  int u16() { final v = d.getUint16(o, Endian.little); o += 2; return v; }
  int i16() { final v = d.getInt16(o, Endian.little); o += 2; return v; }
  int u32() { final v = d.getUint32(o, Endian.little); o += 4; return v; }
  int u64() { final v = d.getUint64(o, Endian.little); o += 8; return v; }
  double f32() { final v = d.getFloat32(o, Endian.little); o += 4; return v; }
  void skip(int n) => o += n;
  String str(int n) {
    final bytes = d.buffer.asUint8List(d.offsetInBytes + o, n);
    o += n;
    final end = bytes.indexOf(0);
    return utf8.decode(bytes.sublist(0, end < 0 ? n : end), allowMalformed: true);
  }
}

const int kHeaderSize = 29;

class Header {
  final int format, packetId, playerCarIndex;
  Header(this.format, this.packetId, this.playerCarIndex);
}

Header? parseHeader(ByteData d) {
  if (d.lengthInBytes < kHeaderSize) return null;
  final format = d.getUint16(0, Endian.little);
  final packetId = d.getUint8(6);       // 0-1 format,2-5 версии,6 packetId
  final playerCarIndex = d.getUint8(27);
  return Header(format, packetId, playerCarIndex);
}

// Диспетчер: парсит пакет в state. Возвращает текст события (если Event).
void parsePacket(Uint8List bytes, GameState st) {
  final d = ByteData.sublistView(bytes);
  final h = parseHeader(d);
  if (h == null || h.format != 2025) return;
  st.playerIndex = h.playerCarIndex;
  switch (h.packetId) {
    case 0: _motion(d, st); break;
    case 1: _session(d, st); break;
    case 2: _lap(d, st); break;
    case 3: _event(d, st); break;
    case 4: _participants(d, st); break;
    case 6: _telemetry(d, st); break;
    case 7: _status(d, st); break;
    case 10: _damage(d, st); break;
    case 11: _history(d, st); break;
  }
}

void _motion(ByteData d, GameState st) {
  final r = _R(d, kHeaderSize);
  const size = 60; // 6f(24) + 6h(12) + 6f(24)
  for (int i = 0; i < 22; i++) {
    final base = r.o;
    final x = r.f32(); r.f32(); final z = r.f32(); // pos X,Y,Z
    r.skip(12);                                     // velocity 3f
    r.skip(12);                                     // forward+right 6h
    r.f32(); r.f32(); r.f32();                      // gLat,gLon,gVert
    final yaw = r.f32();                            // yaw
    r.o = base + size;
    st.cars[i].x = x;
    st.cars[i].z = z;
    st.cars[i].yaw = yaw;
  }
}

void _session(ByteData d, GameState st) {
  final r = _R(d, kHeaderSize);
  final s = st.session;
  s.weather = r.u8();
  s.trackTemp = r.i8();
  s.airTemp = r.i8();
  s.totalLaps = r.u8();
  s.trackLength = r.u16();
  s.sessionType = r.u8();
  s.trackId = r.i8();
  r.u8();             // formula
  r.u16();            // sessionTimeLeft
  r.u16();            // sessionDuration
  r.u8();             // pitSpeedLimit
  r.u8();             // gamePaused
  r.u8();             // isSpectating
  r.u8();             // spectatorCarIndex
  r.u8();             // sliProNativeSupport
  final numZones = r.u8();
  final zones = <MarshalZone>[];
  for (int i = 0; i < numZones; i++) {
    final start = r.f32();
    final flag = r.i8();
    zones.add(MarshalZone(start, flag));
  }
  s.marshalZones = zones;
}

void _lap(ByteData d, GameState st) {
  final r = _R(d, kHeaderSize);
  final pi = st.safePlayerIndex;
  const size = 57; // II HBHBHBHB fff + 15B + HHBfB
  for (int i = 0; i < 22; i++) {
    final base = r.o;
    final last = r.u32();
    final cur = r.u32();
    final s1ms = r.u16(); final s1min = r.u8();
    final s2ms = r.u16(); final s2min = r.u8();
    final dFrontMs = r.u16(); final dFrontMin = r.u8();
    final dLeaderMs = r.u16(); final dLeaderMin = r.u8();
    final lapDist = r.f32();
    r.f32();            // totalDistance
    r.f32();            // safetyCarDelta
    // блок из 15 однобайтовых полей:
    final carPos = r.u8();        // carPosition
    final curLapNum = r.u8();     // currentLapNum
    r.u8();                       // pitStatus
    r.u8();                       // numPitStops
    final sector = r.u8();        // sector
    final invalid = r.u8();       // currentLapInvalid
    r.u8();                       // penalties
    r.u8();                       // totalWarnings
    r.u8();                       // cornerCuttingWarnings
    r.u8();                       // numUnservedDriveThrough
    r.u8();                       // numUnservedStopGo
    r.u8();                       // gridPosition
    r.u8();                       // driverStatus
    final resultStatus = r.u8();  // resultStatus
    r.o = base + size;            // пропускаем хвост (pitTimer..speedTrap)

    final c = st.cars[i];
    c.position = carPos;
    c.lapDistance = lapDist;
    c.lastLapMs = last;
    c.deltaLeaderMs = dLeaderMin * 60000 + dLeaderMs;
    c.deltaFrontMs = dFrontMin * 60000 + dFrontMs;
    c.resultStatus = resultStatus;

    if (i == pi) {
      final p = st.player;
      p.curLapMs = cur;
      p.lastLapMs = last;
      p.s1 = s1min * 60000 + s1ms;
      p.s2 = s2min * 60000 + s2ms;
      p.sector = sector;
      p.position = carPos;
      p.curLapNum = curLapNum;
      p.lapInvalid = invalid;
      p.deltaLeaderMs = c.deltaLeaderMs;
      p.deltaFrontMs = c.deltaFrontMs;
    }
  }
}

void _telemetry(ByteData d, GameState st) {
  final r = _R(d, kHeaderSize);
  final pi = st.safePlayerIndex;
  const size = 60; // H3fBbHBBH 4H 4B 4B H 4f 4B = 60
  for (int i = 0; i < 22; i++) {
    if (i != pi) { r.skip(size); continue; }
    final speed = r.u16();
    final throttle = r.f32();
    final steer = r.f32();
    final brake = r.f32();
    r.u8();                 // clutch
    final gear = r.i8();
    final rpm = r.u16();
    final drs = r.u8();
    r.u8();                 // revLightsPercent
    final revBits = r.u16();
    r.skip(8);              // brakesTemp 4H
    final surf = [r.u8(), r.u8(), r.u8(), r.u8()];
    r.skip(4);              // innerTemp 4B
    r.u16();                // engineTemp
    final pres = [r.f32(), r.f32(), r.f32(), r.f32()];
    r.skip(4);              // surfaceType 4B
    final p = st.player;
    p.speed = speed; p.throttle = throttle; p.steer = steer; p.brake = brake;
    p.gear = gear; p.rpm = rpm; p.drs = drs; p.revLights = revBits;
    p.tyreSurfaceTemp = surf;
    p.tyrePressure = pres.map((e) => double.parse(e.toStringAsFixed(1))).toList();
  }
}

void _status(ByteData d, GameState st) {
  final r = _R(d, kHeaderSize);
  final pi = st.safePlayerIndex;
  const size = 55;
  for (int i = 0; i < 22; i++) {
    final base = r.o;
    r.skip(5);              // tc,abs,fuelMix,brakeBias,pitLimiter
    r.f32();                // fuelInTank
    r.f32();                // fuelCapacity
    final fuelLaps = r.f32();
    r.u16(); r.u16();       // maxRPM, idleRPM
    r.u8();                 // maxGears
    final drsAllowed = r.u8();
    r.u16();                // drsActivationDistance
    r.u8();                 // actualCompound
    final visual = r.u8();
    final age = r.u8();
    final fia = r.i8();
    r.f32(); r.f32();       // powerICE, powerMGUK
    final ers = r.f32();
    final ersMode = r.u8();
    // остаток до size
    r.o = base + size;

    final c = st.cars[i];
    c.visualCompound = visual;
    c.tyreAge = age;
    if (i == pi) {
      final p = st.player;
      p.fuelLaps = fuelLaps;
      p.drsAllowed = drsAllowed;
      p.compound = visual;
      p.tyreAge = age;
      p.fiaFlag = fia;
      p.ersStore = ers;
      p.ersMode = ersMode;
    }
  }
}

void _damage(ByteData d, GameState st) {
  final r = _R(d, kHeaderSize);
  final pi = st.safePlayerIndex;
  const size = 46;
  for (int i = 0; i < 22; i++) {
    if (i != pi) { r.skip(size); continue; }
    final wear = [r.f32(), r.f32(), r.f32(), r.f32()];
    st.player.tyreWear =
        wear.map((e) => double.parse(e.toStringAsFixed(1))).toList();
    r.skip(size - 16);
  }
}

void _participants(ByteData d, GameState st) {
  final r = _R(d, kHeaderSize);
  final num = r.u8();
  const size = 57;
  for (int i = 0; i < 22; i++) {
    final base = r.o;
    r.u8();                 // aiControlled
    r.u8();                 // driverId
    r.u8();                 // networkId
    final teamId = r.u8();
    r.u8();                 // myTeam
    final raceNum = r.u8();
    r.u8();                 // nationality
    final name = r.str(32);
    r.o = base + size;
    final c = st.cars[i];
    c.name = name.isEmpty ? "CAR $i" : name;
    c.teamId = teamId;
    c.raceNumber = raceNum;
    c.active = i < num;
  }
}

void _event(ByteData d, GameState st) {
  final code = String.fromCharCodes(
      d.buffer.asUint8List(d.offsetInBytes + kHeaderSize, 4));
  final r = _R(d, kHeaderSize + 4);
  String nm(int idx) =>
      (idx >= 0 && idx < 22) ? st.cars[idx].name : "#$idx";
  switch (code) {
    case "FTLP":
      final idx = r.u8(); final lt = r.f32();
      st.pushEvent("⚡ Fastest lap — ${nm(idx)} ${fmtLap((lt * 1000).round())}");
      break;
    case "OVTK":
      final a = r.u8(); final b = r.u8();
      st.pushEvent("↔ ${nm(a)} обогнал ${nm(b)}");
      break;
    case "PENA":
      r.u8(); r.u8(); final v = r.u8();
      st.pushEvent("⚠ Пенальти — ${nm(v)}");
      break;
    case "SPTP":
      final idx = r.u8(); final sp = r.f32();
      st.pushEvent("💨 Speed trap — ${nm(idx)} ${sp.round()} км/ч");
      break;
    case "SCAR":
      st.pushEvent("🚨 Safety Car");
      break;
    case "CHQF": st.pushEvent("🏁 Клетчатый флаг"); break;
    case "LGOT": st.pushEvent("🟢 Старт!"); break;
    case "RDFL": st.pushEvent("🔴 Красный флаг"); break;
  }
}

void _history(ByteData d, GameState st) {
  final carIdx = d.getUint8(kHeaderSize);
  final numLaps = d.getUint8(kHeaderSize + 1);
  final r = _R(d, kHeaderSize + 8);
  const lapSize = 14;
  final laps = <int>[];
  for (int i = 0; i < numLaps && i < 100; i++) {
    final t = r.u32();
    r.skip(lapSize - 4);
    if (t > 0) laps.add(t);
  }
  st.history[carIdx] = laps;
}
