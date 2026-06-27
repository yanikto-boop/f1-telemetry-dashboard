// Анализ кругов через OpenRouter. Порт analyze.py.
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'appendices.dart';
import 'lap_store.dart';

const _apiUrl = 'https://openrouter.ai/api/v1/chat/completions';
const _fallbackModels = [
  'meta-llama/llama-3.3-70b-instruct:free',
  'deepseek/deepseek-chat-v3-0324:free',
  'google/gemini-2.0-flash-exp:free',
];

class AiResult {
  final bool ok;
  final String text;     // анализ или ошибка
  final String summary;  // сырые данные
  final String? model;
  AiResult(this.ok, this.text, {this.summary = '', this.model});
}

String _buildSummary(int trackId, List<LapRecord> laps) {
  final valid = laps.where((l) => l.valid && l.timeMs > 0).toList();
  final name = kTracks[trackId] ?? 'track $trackId';
  if (valid.isEmpty) return '';
  final times = valid.map((l) => l.timeMs).toList()..sort();
  final best = times.first;
  final avg = times.reduce((a, b) => a + b) ~/ times.length;
  final bestLap = valid.reduce((a, b) => a.timeMs < b.timeMs ? a : b);
  final b = StringBuffer()
    ..writeln('Трасса: $name')
    ..writeln('Кругов записано: ${laps.length} (валидных: ${valid.length})')
    ..writeln('Лучший: ${fmtLap(best)} | средний: ${fmtLap(avg)} | разброс: ${fmtLap(times.last - best)}')
    ..writeln('Лучший по секторам: S1 ${(bestLap.s1/1000).toStringAsFixed(3)} '
        'S2 ${(bestLap.s2/1000).toStringAsFixed(3)} S3 ${(bestLap.s3/1000).toStringAsFixed(3)} '
        '(шины ${bestLap.compound}, возраст ${bestLap.tyreAge})')
    ..writeln('')
    ..writeln('Последние круги (время | S1 | S2 | S3 | шины | возраст):');
  for (final l in valid.length > 12 ? valid.sublist(valid.length - 12) : valid) {
    b.writeln('  L${l.lap}: ${fmtLap(l.timeMs)} | ${(l.s1/1000).toStringAsFixed(3)} | '
        '${(l.s2/1000).toStringAsFixed(3)} | ${(l.s3/1000).toStringAsFixed(3)} | ${l.compound} | ${l.tyreAge}');
  }
  return b.toString();
}

Future<AiResult> analyze({
  required String apiKey,
  required String model,
  required int trackId,
  required List<LapRecord> laps,
}) async {
  if (apiKey.isEmpty) return AiResult(false, 'API-ключ OpenRouter не задан в настройках.');
  final summary = _buildSummary(trackId, laps);
  if (summary.isEmpty) return AiResult(false, 'Нет валидных кругов для анализа.');

  const system =
      'Ты — гоночный инженер F1. Анализируй телеметрию кругов пилота и давай '
      'конкретные практические советы. Пиши по-русски, кратко и по делу, маркерами. '
      'Структура: 1) Общая оценка стабильности и темпа. 2) Самый слабый сектор и причина. '
      '3) 3-4 конкретных совета как ехать быстрее. 4) Замечания по деградации шин. Без воды.';

  final models = [model, ..._fallbackModels.where((m) => m != model)];
  String lastErr = 'unknown';
  for (final m in models) {
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final res = await http.post(
          Uri.parse(_apiUrl),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'X-Title': 'F1Dash',
          },
          body: jsonEncode({
            'model': m,
            'temperature': 0.6,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': summary},
            ],
          }),
        ).timeout(const Duration(seconds: 60));
        if (res.statusCode == 200) {
          final data = jsonDecode(utf8.decode(res.bodyBytes));
          final text = (data['choices']?[0]?['message']?['content'] ?? '').toString().trim();
          return AiResult(true, text, summary: summary, model: m);
        }
        lastErr = 'OpenRouter ${res.statusCode} ($m): ${res.body}';
        if (res.statusCode == 429 && attempt == 0) {
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        break;
      } catch (e) {
        lastErr = '$e';
        break;
      }
    }
  }
  return AiResult(false, lastErr, summary: summary);
}
