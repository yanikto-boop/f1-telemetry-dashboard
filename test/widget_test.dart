// Базовый тест утилит форматирования.
import 'package:flutter_test/flutter_test.dart';
import 'package:f1telemetry/appendices.dart';

void main() {
  test('fmtLap форматирует миллисекунды', () {
    expect(fmtLap(90500), '1:30.500');
    expect(fmtLap(0), '--:--.---');
  });
}
