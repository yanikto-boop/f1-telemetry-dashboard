// Слушает UDP-телеметрию напрямую, парсит и уведомляет UI.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'game_state.dart';
import 'lap_store.dart';
import 'parser.dart';

class UdpService extends ChangeNotifier {
  final GameState state = GameState();
  final LapStore lapStore;

  RawDatagramSocket? _socket;
  int _port = 20777;
  bool _running = false;
  DateTime _lastPacket = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _ui;
  String? error;

  UdpService(this.lapStore);

  bool get running => _running;
  int get port => _port;
  bool get live =>
      DateTime.now().difference(_lastPacket).inMilliseconds < 2000;

  Future<void> start(int port) async {
    await stop();
    _port = port;
    error = null;
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
      _socket!.listen(_onEvent);
      _running = true;
      // обновляем UI ~30 fps, чтобы не дёргать setState на каждый пакет
      _ui = Timer.periodic(const Duration(milliseconds: 33), (_) {
        if (_running) notifyListeners();
      });
    } catch (e) {
      error = '$e';
      _running = false;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    _ui?.cancel();
    _socket?.close();
    _socket = null;
    _running = false;
    notifyListeners();
  }

  void _onEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _socket?.receive();
    if (dg == null) return;
    _lastPacket = DateTime.now();
    try {
      parsePacket(dg.data, state);
      // запись кругов — дёшево, детектор сам ловит смену круга
      lapStore.feed(state.session, state.player);
    } catch (_) {}
  }

  /// Локальные IPv4-адреса устройства (чтобы вписать в игру).
  static Future<List<String>> localIps() async {
    final out = <String>[];
    try {
      for (final ni in await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false)) {
        for (final a in ni.addresses) {
          out.add(a.address);
        }
      }
    } catch (_) {}
    return out;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
