/// Menu de debug: dono do [DevTools], do estado da sintonia e das preferências, e da tela [DebugMenuView]. Os itens
/// (mapa do jogo, simulador de GPS, relógio UTC, spawns, sintonia, save...) estão no [DebugRegistry]
/// (`debug_registry.dart`, `debug_items.dart`). Fica em todas as builds de teste, inclusive as de release (CLAUDE.md).
library;

import 'package:flutter/material.dart';

import '../data/geolocator_source.dart';
import '../data/session_log_store.dart';
import '../save/backup_io.dart';
import '../save/save_store.dart';
import '../ui/tuning/log_exporter.dart';
import 'debug_capture.dart';
import 'debug_env.dart';
import 'debug_items.dart';
import 'debug_menu_view.dart';
import 'debug_prefs.dart';
import 'debug_registry.dart';
import 'dev_tools.dart';

class TuningDebugMenu extends StatefulWidget {
  const TuningDebugMenu({this.store, this.exporter, this.devTools, this.prefs, this.saveStore, this.backupIo, super.key});

  /// A fonte de posição e o relógio. Por padrão, o GPS real e o relógio do aparelho.
  final DevTools? devTools;

  /// Registro das sessões. Por padrão, `sessions.csv` nos documentos do app.
  final SessionLogStore? store;
  final LogExporter? exporter;

  /// Favoritos e seções abertas. Por padrão, `debug_menu.json` nos documentos do app.
  final DebugPrefs? prefs;

  /// O save e o jeito de exportar e importar backup. Por padrão, o do app.
  final SaveStore? saveStore;
  final BackupIo? backupIo;

  @override
  State<TuningDebugMenu> createState() => _TuningDebugMenuState();
}

class _TuningDebugMenuState extends State<TuningDebugMenu> {
  late final DevTools _tools = widget.devTools ?? DevTools(realSource: GeolocatorPositionSource());
  late final DebugEnv _env = DebugEnv(
    tools: _tools,
    capture: CaptureDebug(store: widget.store, exporter: widget.exporter),
    saveStore: widget.saveStore,
    io: widget.backupIo ?? const DeviceBackupIo(),
  );
  late final DebugRegistry _registry = buildDefaultRegistry(_env);
  DebugPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = widget.prefs ?? await DebugPrefs.inDocuments();
    await prefs.load();
    if (mounted) setState(() => _prefs = prefs);
    _env.loadLevelOverride();
    try {
      await _env.capture.load();
    } catch (_) {
      // sem assets ou sem disco: os itens da sintonia ficam em "Carregando..."
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null) return const Scaffold(body: Center(child: Text('Carregando...')));
    return DebugMenuView(registry: _registry, prefs: prefs);
  }

  @override
  void dispose() {
    _env.dispose();
    super.dispose();
  }
}
