import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'lap_store.dart';
import 'theme.dart';
import 'udp_service.dart';
import 'update_service.dart';
import 'update_dialog.dart';
import 'screens/dashboard_screen.dart';
import 'screens/laps_screen.dart';
import 'screens/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settings = AppSettings();
  await settings.load();

  final store = LapStore();
  await store.init();

  final service = UdpService(store);
  if (settings.autoStart) {
    await service.start(settings.port);
  }

  runApp(F1App(settings: settings, store: store, service: service));
}

class F1App extends StatelessWidget {
  final AppSettings settings;
  final LapStore store;
  final UdpService service;
  const F1App({super.key, required this.settings, required this.store, required this.service});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'F1 25 Telemetry',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeShell(settings: settings, store: store, service: service),
    );
  }
}

class HomeShell extends StatefulWidget {
  final AppSettings settings;
  final LapStore store;
  final UdpService service;
  const HomeShell({super.key, required this.settings, required this.store, required this.service});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Тихая проверка обновлений при запуске.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final upd = await UpdateService.check();
      if (upd != null && mounted) showUpdateDialog(context, upd);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(service: widget.service),
      LapsScreen(store: widget.store, settings: widget.settings),
      SettingsScreen(settings: widget.settings, service: widget.service),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _tab, children: pages)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.speed), label: 'Дашборд'),
          NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'Круги'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}
