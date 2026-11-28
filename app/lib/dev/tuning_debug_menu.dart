/// Menu de debug: dono do [DevTools], do estado da sintonia, das preferências e do [DebugRegistry] (`debug_registry.dart`,
/// `debug_items.dart`), que a tela [DebugMenuView] e o `cmd` (`debug_commands.dart`) usam. Fica em todas as builds de
/// teste, inclusive as de release dos amigos, até a distribuição (`docs/distribuicao.md`).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../data/geolocator_source.dart';
import '../data/session_log_store.dart';
import '../patrol/patrol_launch.dart';
import '../ui/game/game_map_screen.dart';
import '../save/backup_io.dart';
import '../save/save_store.dart';
import '../ui/tuning/log_exporter.dart';
import 'debug_capture.dart';
import 'debug_env.dart';
import 'debug_items.dart';
import 'debug_items_creature.dart' show restoreCreatureForm;
import 'debug_menu_view.dart';
import 'debug_prefs.dart';
import 'debug_registry.dart';
import 'debug_commands.dart';
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
  late final DevTools _tools = widget.devTools ?? (DevTools(realSource: GeolocatorPositionSource())..detect());
  late final DebugEnv _env = DebugEnv(
    tools: _tools,
    capture: CaptureDebug(store: widget.store, exporter: widget.exporter),
    saveStore: widget.saveStore,
    io: widget.backupIo ?? const DeviceBackupIo(),
  );
  late final DebugRegistry _registry = buildDefaultRegistry(_env)..screen = () => mounted ? context : null;
  late final Listenable _changes = debugListenables(_env);
  DebugPrefs? _prefs;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Comandos do adb por intent (scripts/celular.sh cmd ...): o celular se dirige sem teclado (0.24.2). 0.26.6: pelo
    // mesmo registro da tela.
    unawaited(listenDebugCommands(_registry, _tools));
    final prefs = widget.prefs ?? await DebugPrefs.inDocuments();
    await prefs.load();
    prefs.migrateFavorites((id) => _registry.byName(id)?.id);
    restoreCreatureForm(_registry, prefs.creatureForm);
    _env.prefs = prefs;
    if (mounted) setState(() => _prefs = prefs);
    _env.loadLevelOverride();
    // Aberto pelo aviso de um Eco raro da Patrulha: vai direto ao mapa, que abre o Eco.
    if (await initPatrolLaunch() && mounted) {
      unawaited(openGameMap(context, _tools));
    }
    try {
      await _env.capture.ensure();
    } catch (_) {
      // sem assets ou sem disco: as entradas da sintonia ficam em "carregando"
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null) return const Scaffold(body: Center(child: Text('Carregando...')));
    return DebugMenuView(registry: _registry, prefs: prefs, listenable: _changes, onTop: () => openGameMap(context, _tools));
  }

  @override
  void dispose() {
    _env.dispose();
    super.dispose();
  }
}
