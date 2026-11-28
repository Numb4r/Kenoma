/// Aba Criaturas, a sintonia: abrir a sintonia de qualquer espécie, com nível do Eco e do Conjurador, selo, tônico, alvo no
/// dial e tipo oculto; o registro das sessões; e sentir a vibração. O estado vive no [CaptureDebug], então as entradas
/// podem ir para os favoritos sem perder a escolha.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../capture/eco_type.dart';
import '../capture/seal.dart';
import '../capture/tuning_setup.dart';
import '../capture/vibe.dart';
import '../data/session_log_store.dart';
import '../data/tuning_data.dart';
import '../ui/tuning/log_exporter.dart';
import '../ui/tuning/tuning_screen.dart';
import '../ui/tuning/vibration_driver.dart';
import '../ui/type_label.dart';
import 'debug_registry.dart';

class CaptureDebug extends ChangeNotifier {
  CaptureDebug({this.store, LogExporter? exporter}) : exporter = exporter ?? ShareLogExporter();

  SessionLogStore? store;
  final LogExporter exporter;
  final vibration = DeviceVibration();

  String appBuild = '';
  int sessions = 0;
  TuningData? data;
  EcoSpecies? species;
  Seal? seal;
  int ecoLevel = 1;
  int playerLevel = 1;
  bool tonic = false;
  bool showTarget = false;
  bool hidden = false;
  bool _disposed = false;

  Future<void>? _loading;

  /// Carrega uma vez só (o menu ao abrir e o `cmd` antes de conferir valores).
  Future<void> ensure() => _loading ??= load().catchError((Object e) {
        _loading = null;
        throw e;
      });

  Future<void> load() async {
    final d = await TuningData.load();
    final info = await PackageInfo.fromPlatform();
    final st = store ?? await SessionLogStore.inDocuments();
    await st.migrate(); // quem exporta logo depois já leva o formato atual
    final n = await st.count();
    if (_disposed) return;
    store = st;
    appBuild = '${info.version}+${info.buildNumber}';
    sessions = n;
    data = d;
    species = d.species.first;
    seal = d.seals.first;
    notifyListeners();
  }

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  TuningSetup setupFor(TuningData d, EcoSpecies s) =>
      TuningSetup(type: s.type, ecoLevel: ecoLevel, playerLevel: playerLevel, seal: seal!, tonic: tonic ? d.tonics.first : null);

  Future<void> start(BuildContext context, TuningData d) async {
    final nav = Navigator.of(context);
    await nav.push(MaterialPageRoute<void>(
      builder: (_) => TuningScreen(
        pool: hidden ? [for (final x in d.species) if (x.tier == 'eco' && EcoType.mvp.contains(x.type)) x] : [species!], // o modo oculto é dos três do MVP
        buildSetup: (s) => setupFor(d, s),
        balance: d.balance,
        balanceVersion: d.balanceVersion,
        appBuild: appBuild,
        store: store!,
        hidden: hidden,
        showTarget: showTarget,
      ),
    ));
    final n = await store!.count();
    if (!_disposed) update(() => sessions = n);
  }

  @override
  void dispose() {
    _disposed = true;
    vibration.cancel();
    super.dispose();
  }
}

List<DebugEntry> captureEntries(CaptureDebug c) {
  TuningData data() => c.data ?? (throw const DebugError('carregando os dados da sintonia'));
  DebugEntry opt(String id, String name, String alias, bool Function() get, void Function(bool v) set, {String? info, bool Function()? enabled}) => DebugEntry(
        id: 'creature.tuning_$id',
        name: name,
        tab: DebugTab.creatures,
        kind: DebugKind.toggle,
        aliases: [alias],
        keywords: const ['sintonia', 'dial'],
        info: info,
        enabled: enabled,
        read: () => get() ? 'on' : 'off',
        run: (call) => c.update(() => set(call.value == 'on')),
      );
  DebugEntry level(String id, String name, int Function() get, void Function(int v) set) => DebugEntry(
        id: 'creature.tuning_$id',
        name: name,
        tab: DebugTab.creatures,
        kind: DebugKind.number,
        aliases: [if (id == 'eco_level') 'cap.levels'],
        keywords: const ['sintonia', 'nível', 'level'],
        min: 1,
        max: 20,
        read: () => '${get()}',
        run: (call) => c.update(() => set(call.intOf(''))),
      );
  return [
    DebugEntry(
      id: 'creature.tuning_species',
      name: 'Sintonia: espécie',
      tab: DebugTab.creatures,
      kind: DebugKind.choice,
      aliases: const ['cap.species'],
      keywords: const ['eco', 'criatura', 'sintonia', 'tipo', 'sootling', 'rillet', 'frondling', 'humoth', 'pebblet', 'rustling', 'glimlet', 'umbrel', 'wisplet', 'bitling', 'sprigglet', 'wyrmlet'],
      load: c.ensure,
      enabled: () => !c.hidden,
      optionsOf: () => [for (final s in c.data?.species ?? const <EcoSpecies>[]) if (s.tier == 'eco' || s.tier == 'spirit') DebugOption(s.id, s.name)],
      read: () => c.species?.id,
      run: (call) => c.update(() => c.species = data().species.firstWhere((s) => s.id == call.value)),
    ),
    level('eco_level', 'Sintonia: nível do Eco', () => c.ecoLevel, (v) => c.ecoLevel = v),
    level('player_level', 'Sintonia: nível do Conjurador', () => c.playerLevel, (v) => c.playerLevel = v),
    DebugEntry(
      id: 'creature.tuning_seal',
      name: 'Sintonia: selo',
      tab: DebugTab.creatures,
      kind: DebugKind.choice,
      aliases: const ['cap.seal'],
      keywords: const ['seal', 'sintonia'],
      load: c.ensure,
      optionsOf: () => [for (final s in c.data?.seals ?? const <Seal>[]) DebugOption(s.id, s.name)],
      read: () => c.seal?.id,
      run: (call) => c.update(() => c.seal = data().seals.firstWhere((s) => s.id == call.value)),
    ),
    opt('tonic', 'Sintonia: tônico', 'cap.options', () => c.tonic, (v) => c.tonic = v, info: 'Soma o tempo do primeiro tônico do items.json.'),
    opt('target', 'Sintonia: alvo no dial', 'cap.target', () => c.showTarget && !c.hidden, (v) => c.showTarget = v, enabled: () => !c.hidden),
    opt('hidden', 'Sintonia: tipo oculto', 'cap.hidden', () => c.hidden, (v) => c.hidden = v, info: 'Sorteia o tipo entre os três do MVP. Você sente a vibração e dá o palpite antes de sintonizar.'),
    DebugEntry(
      id: 'creature.tuning_start',
      name: 'Iniciar sintonia',
      tab: DebugTab.creatures,
      kind: DebugKind.action,
      aliases: const ['cap.start'],
      keywords: const ['capturar', 'iniciar', 'dial', 'resistência'],
      load: c.ensure,
      status: () {
        final d = c.data, s = c.species;
        if (d == null || s == null) return null;
        final setup = c.setupFor(d, s);
        return 'Resistência ${setup.intensity(d.balance).toStringAsFixed(2)} · tolerância ${setup.tolerance(d.balance).toStringAsFixed(3)} · ${setup.timeLimitS(d.balance).toStringAsFixed(0)} s';
      },
      run: (call) {
        unawaited(c.start(call.screen, data()));
        return 'sintonia';
      },
    ),
    DebugEntry(
      id: 'creature.tuning_log',
      name: 'Registro das sessões',
      tab: DebugTab.creatures,
      kind: DebugKind.view,
      aliases: const ['cap.log'],
      keywords: const ['csv', 'sessões', 'log'],
      read: () => 'Sessões gravadas: ${c.sessions}',
    ),
    DebugEntry(
      id: 'creature.tuning_log_export',
      name: 'Exportar o registro das sessões',
      tab: DebugTab.creatures,
      kind: DebugKind.action,
      keywords: const ['exportar', 'csv', 'sessões', 'log', 'compartilhar'],
      run: (_) async {
        if (c.sessions == 0) throw const DebugError('Nenhuma sessão gravada ainda');
        await c.exporter.export(c.store!.file);
        return null;
      },
    ),
    DebugEntry(
      id: 'creature.vibration',
      name: 'Sentir a vibração',
      tab: DebugTab.creatures,
      kind: DebugKind.action,
      aliases: const ['cap.vibration'],
      keywords: const ['vibrar', 'haptic', 'identidade', 'alerta', 'fogo', 'água', 'planta'],
      info: 'A identidade de cada tipo (ferramenta do modo tipo oculto) e os alertas durante a sintonia.',
      params: [
        DebugParam('pattern', 'vibração', options: [
          for (final t in EcoType.values) DebugOption(t.name, typeLabel(t)),
          const DebugOption('fire_warning', 'Fogo: aviso'),
          const DebugOption('water_swell', 'Água: virada'),
          const DebugOption('plant_pulse', 'Planta: broto'),
        ], fallback: EcoType.values.first.name),
      ],
      run: (call) {
        final p = call['pattern'];
        c.vibration.play(switch (p) {
          'fire_warning' => fireWarningPattern,
          'water_swell' => waterSwellPattern,
          'plant_pulse' => plantPulsePattern(90),
          _ => identityPattern(EcoType.values.byName(p)),
        });
        return null;
      },
    ),
  ];
}
