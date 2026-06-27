// Настройки приложения (порт/режим/ключ) — хранятся в shared_preferences.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secrets.dart';

class AppSettings extends ChangeNotifier {
  int port = 20777;
  // режим: 'lan' — игра шлёт на IP телефона; 'local' — игра на этом же ПК (127.0.0.1)
  String mode = 'lan';
  bool autoStart = true;
  String apiKey = kDefaultApiKey;
  String model = kDefaultModel;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    port = p.getInt('port') ?? port;
    mode = p.getString('mode') ?? mode;
    autoStart = p.getBool('autoStart') ?? autoStart;
    apiKey = p.getString('apiKey') ?? apiKey;
    model = p.getString('model') ?? model;
    notifyListeners();
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('port', port);
    await p.setString('mode', mode);
    await p.setBool('autoStart', autoStart);
    await p.setString('apiKey', apiKey);
    await p.setString('model', model);
    notifyListeners();
  }
}
