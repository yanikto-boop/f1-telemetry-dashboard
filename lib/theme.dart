import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF0A0C10);
  static const card = Color(0xFF141923);
  static const card2 = Color(0xFF1B2230);
  static const line = Color(0xFF222C3A);
  static const txt = Color(0xFFE8EDF4);
  static const muted = Color(0xFF7D8AA0);
  static const accent = Color(0xFFE10600);
  static const accent2 = Color(0xFF27E0D2);
  static const green = Color(0xFF22C55E);
  static const yellow = Color(0xFFEAB308);
  static const red = Color(0xFFEF4444);
  static const blue = Color(0xFF3B82F6);
}

Color tempColor(num t) {
  if (t < 70) return C.blue;
  if (t < 100) return C.green;
  if (t < 120) return C.yellow;
  return C.red;
}

Color wearColor(num w) {
  if (w < 25) return C.green;
  if (w < 55) return C.yellow;
  return C.red;
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: C.accent2,
      secondary: C.accent,
      surface: C.card,
    ),
    fontFamily: 'Roboto',
  );
}

BoxDecoration cardDeco() => BoxDecoration(
  gradient: const LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [C.card, Color(0xFF11151C)],
  ),
  border: Border.all(color: C.line),
  borderRadius: BorderRadius.circular(16),
);

Widget cardTitle(String s) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(s, style: const TextStyle(
    fontSize: 12, letterSpacing: 2, color: C.muted, fontWeight: FontWeight.bold)),
);
