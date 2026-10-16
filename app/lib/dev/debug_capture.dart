/// Itens da seção Captura do menu de debug: abrir a sintonia de qualquer espécie, com nível do Eco e do Conjurador,
/// selo, tônico, alvo no dial e tipo oculto; o registro das sessões; e sentir a vibração. O estado vive no
/// [CaptureDebug], então os itens podem ser fixados nos Favoritos sem perder a escolha.
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../capture/eco_type.dart';
import '../capture/seal.dart';
import '../capture/tuning_setup.dart';
import '../capture/vibe.dart';
import '../data/session_log_store.dart';
import '../data/tuning_data.dart';
import '../ui/sprites/sprite_image.dart';
import '../ui/tema.dart';
import '../ui/tuning/log_exporter.dart';
import '../ui/tuning/tuning_screen.dart';
import '../ui/tuning/vibration_driver.dart';
import '../ui/type_label.dart';
import 'debug_registry.dart';
import 'debug_widgets.dart';

class CaptureDebug extends ChangeNotifier {
  CaptureDebug({this.store, LogExporter? exporter}) : exporter = exporter ?? ShareLogExporter();

  SessionLogStore? store;
  final LogExporter exporter;
  final vibration = DeviceVibration();
  final sprites = <String, EcoSprite>{};

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

  Future<void> load() async {
    final d = await TuningData.load();
    final info = await PackageInfo.fromPlatform();
    for (final s in d.species) {
      sprites[s.id] = await EcoSprite.load(s.id);
    }
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
        pool: hidden ? d.species : [species!],
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

  Future<void> export(BuildContext context) async {
    if (sessions == 0) {
      debugSnack(context, 'Nenhuma sessão gravada ainda');
      return;
    }
    await exporter.export(store!.file);
  }

  @override
  void dispose() {
    _disposed = true;
    vibration.cancel();
    super.dispose();
  }
}

List<DebugItem> captureItems(CaptureDebug c) {
  Widget when(Widget Function(TuningData d) build) => ListenableBuilder(
        listenable: c,
        builder: (context, _) => c.data == null ? const DebugNote('Carregando...') : build(c.data!),
      );
  return [
    DebugItem(
      id: 'cap.species',
      title: 'Espécie',
      section: DebugSection.capture,
      keywords: const ['eco', 'criatura', 'sintonia', 'sootling', 'rillet', 'frondling'],
      builder: (_) => when((d) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [for (final s in d.species) _speciesTile(c, s)])),
    ),
    DebugItem(
      id: 'cap.levels',
      title: 'Níveis',
      section: DebugSection.capture,
      keywords: const ['eco', 'conjurador', 'nível', 'level'],
      builder: (_) => when((d) => DebugColumn([
            _slider('Nível do Eco', c.ecoLevel, 1, 20, (v) => c.update(() => c.ecoLevel = v)),
            _slider('Conjurador', c.playerLevel, 1, 15, (v) => c.update(() => c.playerLevel = v)),
          ])),
    ),
    DebugItem(
      id: 'cap.seal',
      title: 'Selo',
      section: DebugSection.capture,
      keywords: const ['seal', 'sintonia'],
      builder: (_) => when((d) => DropdownButton<Seal>(
            value: c.seal,
            isExpanded: true,
            dropdownColor: KCores.superficie2,
            style: KTexto.rotulo.copyWith(fontSize: 16),
            items: [for (final s in d.seals) DropdownMenuItem(value: s, child: Text(s.name))],
            onChanged: (s) => c.update(() => c.seal = s),
          )),
    ),
    DebugItem(
      id: 'cap.options',
      title: 'Opções da sintonia',
      section: DebugSection.capture,
      keywords: const ['tônico', 'tonico', 'alvo', 'dial', 'tipo oculto'],
      builder: (_) => when((d) => Column(children: [
            DebugSwitch(title: 'Tônico (+${d.tonics.first.extraTimeS.toStringAsFixed(0)} s)', value: c.tonic, onChanged: (v) => c.update(() => c.tonic = v)),
            DebugSwitch(
              title: 'Mostrar alvo no dial',
              value: c.showTarget && !c.hidden,
              color: KCores.sinalCiano,
              onChanged: c.hidden ? null : (v) => c.update(() => c.showTarget = v),
            ),
            DebugSwitch(
              title: 'Tipo oculto',
              subtitle: 'Sorteia o tipo. Você sente a vibração e dá o palpite antes de sintonizar.',
              value: c.hidden,
              onChanged: (v) => c.update(() => c.hidden = v),
            ),
          ])),
    ),
    DebugItem(
      id: 'cap.start',
      title: 'Abrir sintonia',
      section: DebugSection.capture,
      keywords: const ['capturar', 'iniciar', 'dial', 'ritual', 'resistência'],
      builder: (_) => when((d) {
        final setup = c.setupFor(d, c.species!);
        return DebugColumn([
          Text(
            'Resistência ${setup.intensity(d.balance).toStringAsFixed(2)}\n'
            'Tolerância ${setup.tolerance(d.balance).toStringAsFixed(3)}\n'
            'Tempo ${setup.timeLimitS(d.balance).toStringAsFixed(0)} s',
            style: KTexto.corpoPequeno,
          ),
          Builder(builder: (context) => DebugButton(label: 'Iniciar sintonia', color: KCores.sinalCiano, onTap: () => c.start(context, d))),
        ]);
      }),
    ),
    DebugItem(
      id: 'cap.log',
      title: 'Registro das sessões',
      section: DebugSection.capture,
      keywords: const ['exportar', 'csv', 'sessões', 'log'],
      builder: (_) => ListenableBuilder(
        listenable: c,
        builder: (context, _) => DebugColumn([
          Text('Sessões gravadas: ${c.sessions}', style: KTexto.corpoPequeno),
          DebugButton(label: 'Exportar registro', onTap: () => c.export(context)),
        ]),
      ),
    ),
    DebugItem(
      id: 'cap.vibration',
      title: 'Sentir a vibração',
      section: DebugSection.capture,
      keywords: const ['vibrar', 'haptic', 'identidade', 'alerta', 'fogo', 'água', 'planta'],
      builder: (_) => DebugColumn([
        const DebugNote('Identidade (ferramenta do modo tipo oculto)'),
        DebugWrap([for (final t in EcoType.values) DebugButton(label: typeLabel(t), onTap: () => c.vibration.play(identityPattern(t)))]),
        const DebugNote('Alertas (durante a sintonia)'),
        DebugWrap([
          DebugButton(label: 'Fogo: aviso', color: KCores.brasaLaranja, onTap: () => c.vibration.play(fireWarningPattern)),
          DebugButton(label: 'Água: virada', color: KCores.sinalCiano, onTap: () => c.vibration.play(waterSwellPattern)),
          DebugButton(label: 'Planta: broto', onTap: () => c.vibration.play(plantPulsePattern(90))),
        ]),
      ]),
    ),
  ];
}

Widget _speciesTile(CaptureDebug c, EcoSpecies s) {
  final selected = !c.hidden && s.id == c.species?.id;
  return GestureDetector(
    onTap: c.hidden ? null : () => c.update(() => c.species = s),
    child: Opacity(
      opacity: c.hidden ? 0.35 : 1,
      child: Container(
        width: 96,
        padding: const EdgeInsets.all(KEspaco.s1),
        decoration: BoxDecoration(border: Border.all(color: selected ? KCores.sinalCiano : KCores.contorno, width: kContornoDp), color: selected ? KCores.superficie2 : null),
        child: Column(children: [
          RawImage(image: c.sprites[s.id]?.normal, width: 72, height: 72, filterQuality: FilterQuality.none, fit: BoxFit.contain),
          const SizedBox(height: 4),
          Text(s.name, style: KTexto.corpoPequeno.copyWith(color: KCores.texto)),
          Text(typeLabel(s.type), style: KTexto.corpoPequeno),
        ]),
      ),
    ),
  );
}

Widget _slider(String label, int value, int min, int max, ValueChanged<int> onChanged) => Row(children: [
      SizedBox(width: 120, child: Text(label, style: KTexto.corpoPequeno)),
      Expanded(
        child: Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: KCores.veuVioleta,
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
      SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.right, style: KTexto.rotulo.copyWith(fontSize: 16))),
    ]);
