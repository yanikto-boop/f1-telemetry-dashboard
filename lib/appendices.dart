// Справочники F1 25 (формат 2025). Порт из appendices.py.
import 'package:flutter/material.dart';

const Map<int, String> kTracks = {
  0: "Melbourne", 2: "Shanghai", 3: "Bahrain", 4: "Catalunya", 5: "Monaco",
  6: "Montreal", 7: "Silverstone", 9: "Hungaroring", 10: "Spa", 11: "Monza",
  12: "Singapore", 13: "Suzuka", 14: "Abu Dhabi", 15: "Texas", 16: "Brazil",
  17: "Austria", 19: "Mexico", 20: "Baku", 26: "Zandvoort", 27: "Imola",
  29: "Jeddah", 30: "Miami", 31: "Las Vegas", 32: "Losail",
};

const Map<int, int> kTeamColors = {
  0: 0xFF27F4D2, 1: 0xFFE80020, 2: 0xFF3671C6, 3: 0xFF64C4FF, 4: 0xFF229971,
  5: 0xFF0093CC, 6: 0xFF6692FF, 7: 0xFFB6BABD, 8: 0xFFFF8000, 9: 0xFF52E252,
};

Color teamColor(int id) => Color(kTeamColors[id] ?? 0xFF888888);

const Map<int, String> kCompoundName =
    {16: "SOFT", 17: "MEDIUM", 18: "HARD", 7: "INTER", 8: "WET"};
const Map<int, String> kCompoundShort =
    {16: "S", 17: "M", 18: "H", 7: "I", 8: "W"};
const Map<int, int> kCompoundColor = {
  16: 0xFFEF4444, 17: 0xFFEAB308, 18: 0xFFE5E7EB, 7: 0xFF22C55E, 8: 0xFF3B82F6,
};
Color compoundColor(int v) => Color(kCompoundColor[v] ?? 0xFFAAAAAA);

const Map<int, String> kWeather = {
  0: "☀ Clear", 1: "⛅ Light cloud", 2: "☁ Overcast",
  3: "🌦 Light rain", 4: "🌧 Heavy rain", 5: "⛈ Storm",
};

const Map<int, String> kSessionTypes = {
  1: "P1", 2: "P2", 3: "P3", 5: "Q1", 6: "Q2", 7: "Q3",
  15: "Race", 18: "Time Trial",
};

const Map<int, String> kErsModes =
    {0: "None", 1: "Medium", 2: "Hotlap", 3: "Overtake"};

String fmtLap(int ms) {
  if (ms <= 0) return "--:--.---";
  final m = ms ~/ 60000;
  final s = (ms % 60000) / 1000;
  return "$m:${s.toStringAsFixed(3).padLeft(6, '0')}";
}

String fmtSec(int ms) =>
    ms <= 0 ? "--.---" : (ms / 1000).toStringAsFixed(3);
