/// Menu de debug: abre o mapa do jogo (M5) com o GPS real ou o simulador, o mapa livre (M4) em qualquer
/// coordenada e a sintonia (M3), escolhendo o Eco, os níveis, o selo e o tônico. Também tem o override do
/// relógio UTC. Fica em todas as builds de teste, inclusive as de release (CLAUDE.md).
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../capture/eco_type.dart';
import '../capture/seal.dart';
import '../capture/tuning_setup.dart';
import '../capture/vibe.dart';
import '../data/session_log_store.dart';
import '../data/tuning_data.dart';
import '../ui/colors.dart';
import '../ui/game/game_map_screen.dart';
import '../ui/map/map_screen.dart';
import '../world/places.dart';
import '../data/geolocator_source.dart';
import 'clock_input.dart';
import 'dev_tools.dart';
import 'gps_simulator.dart';
import '../ui/sprites/sprite_image.dart';
import '../ui/tuning/log_exporter.dart';
import '../ui/tuning/tuning_screen.dart';
import '../ui/tuning/vibration_driver.dart';
import '../ui/type_label.dart';

class TuningDebugMenu extends StatefulWidget {
  const TuningDebugMenu({this.store, this.exporter, this.devTools, super.key});

  /// A fonte de posição e o relógio. Por padrão, o GPS real e o relógio do aparelho.
  final DevTools? devTools;

  /// Registro das sessões. Por padrão, `sessions.csv` nos documentos do app.
  final SessionLogStore? store;
  final LogExporter? exporter;

  @override
  State<TuningDebugMenu> createState() => _TuningDebugMenuState();
}

class _TuningDebugMenuState extends State<TuningDebugMenu> {
  final _vibration = DeviceVibration();
  late final LogExporter _exporter = widget.exporter ?? ShareLogExporter();
  SessionLogStore? _store;
  String _appBuild = '';
  int _sessions = 0;
  TuningData? _data;
  final _sprites = <String, EcoSprite>{};
  EcoSpecies? _species;
  Seal? _seal;
  int _ecoLevel = 1;
  int _playerLevel = 1;
  bool _tonic = false;
  bool _showTarget = false;
  bool _hidden = false;

  /// Ferramentas de dev: GPS real ou simulador, e o relógio UTC.
  late final DevTools _tools = widget.devTools ?? DevTools(realSource: GeolocatorPositionSource());
  final _simLat = TextEditingController(text: kUnicamp.$1.toString());
  final _simLon = TextEditingController(text: kUnicamp.$2.toString());
  final _clockText = TextEditingController();

  /// Centro inicial do mapa. O padrão é a Unicamp.
  final _lat = TextEditingController(text: kUnicamp.$1.toString());
  final _lon = TextEditingController(text: kUnicamp.$2.toString());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await TuningData.load();
    final info = await PackageInfo.fromPlatform();
    for (final s in data.species) {
      _sprites[s.id] = await EcoSprite.load(s.id);
    }
    final store = widget.store ?? await SessionLogStore.inDocuments();
    await store.migrate(); // quem exporta logo depois já leva o formato atual
    final sessions = await store.count();
    if (!mounted) return;
    setState(() {
      _store = store;
      _appBuild = '${info.version}+${info.buildNumber}';
      _sessions = sessions;
      _data = data;
      _species = data.species.first;
      _seal = data.seals.first;
    });
  }

  TuningSetup _setupFor(TuningData d, EcoSpecies species) => TuningSetup(
        type: species.type,
        ecoLevel: _ecoLevel,
        playerLevel: _playerLevel,
        seal: _seal!,
        tonic: _tonic ? d.tonics.first : null,
      );

  Future<void> _start(TuningData d) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TuningScreen(
        pool: _hidden ? d.species : [_species!],
        buildSetup: (s) => _setupFor(d, s),
        balance: d.balance,
        balanceVersion: d.balanceVersion,
        appBuild: _appBuild,
        store: _store!,
        hidden: _hidden,
        showTarget: _showTarget,
      ),
    ));
    final n = await _store!.count();
    if (mounted) setState(() => _sessions = n);
  }

  void _setCenter((double, double) c) => setState(() {
        _lat.text = c.$1.toString();
        _lon.text = c.$2.toString();
      });

  Future<void> _openMap() async {
    final lat = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(_lon.text.trim().replaceAll(',', '.'));
    if (lat == null || lon == null || lat.abs() > 85 || lon.abs() > 180) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coordenada inválida')));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MapScreen(lat: lat, lon: lon, nowUtc: _tools.clock.nowUtc)));
  }

  Widget _coordField(String label, TextEditingController c) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: const TextStyle(fontSize: 16, color: kText),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 8, color: kDim),
            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: kPanelLine, width: 2), borderRadius: BorderRadius.zero),
            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: kSignal, width: 2), borderRadius: BorderRadius.zero),
          ),
        ),
      );

  Future<void> _openGame() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GameMapScreen(tools: _tools)));

  void _teleport() {
    final lat = double.tryParse(_simLat.text.trim().replaceAll(',', '.'));
    final lon = double.tryParse(_simLon.text.trim().replaceAll(',', '.'));
    if (lat == null || lon == null || lat.abs() > 85 || lon.abs() > 180) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coordenada inválida')));
      return;
    }
    _tools.simulator.teleport(lat, lon);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Teleportado')));
  }

  void _applyClock() {
    final t = parseUtcInput(_clockText.text);
    if (t == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Use aaaa-mm-dd hh:mm em UTC')));
      return;
    }
    _tools.clock.setUtc(t);
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(title, style: const TextStyle(fontSize: 24, color: kVeil)),
      );

  Widget _simSection() => ListenableBuilder(
        listenable: Listenable.merge([_tools, _tools.clock]),
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _section('JOGO · MAPA'),
            Text('Fonte de posição: ${_tools.useSimulator ? 'simulador' : 'GPS real'}', style: const TextStyle(fontSize: 8, color: kDim)),
            const SizedBox(height: 8),
            PixelButton(label: 'Abrir mapa do jogo', color: kSignal, onTap: _openGame),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Simulador de GPS', style: TextStyle(fontSize: 16)),
              subtitle: const Text('No lugar do GPS real. Joystick, velocidade e teleporte no mapa do jogo.', style: TextStyle(fontSize: 8, color: kDim)),
              value: _tools.useSimulator,
              activeThumbColor: kSignal,
              onChanged: (v) => _tools.setUseSimulator(v),
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in SimSpeed.values)
                GestureDetector(
                  onTap: () => setState(() => _tools.simulator.speedMps = s.mps),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: _tools.simulator.speedMps == s.mps ? kSignal : kPanelLine, width: 3),
                      color: _tools.simulator.speedMps == s.mps ? kPanel : null,
                    ),
                    child: Text('${s.label} ${s.mps.toStringAsFixed(1)} m/s', style: const TextStyle(fontSize: 8, color: kText)),
                  ),
                ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ruído de GPS (5 m)', style: TextStyle(fontSize: 8)),
              value: _tools.simulator.noiseM > 0,
              activeThumbColor: kVeil,
              onChanged: (v) => setState(() => _tools.simulator.noiseM = v ? 5 : 0),
            ),
            const SizedBox(height: 8),
            Row(children: [_coordField('Latitude', _simLat), const SizedBox(width: 8), _coordField('Longitude', _simLon)]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              PixelButton(label: 'Unicamp', color: kDim, onTap: () => setState(() {
                    _simLat.text = kUnicamp.$1.toString();
                    _simLon.text = kUnicamp.$2.toString();
                  })),
              PixelButton(label: 'Centro', color: kDim, onTap: () => setState(() {
                    _simLat.text = kCentroCampinas.$1.toString();
                    _simLon.text = kCentroCampinas.$2.toString();
                  })),
              PixelButton(label: 'Teleportar', color: kVeil, onTap: _teleport),
            ]),
            const SizedBox(height: 24),
            const Text('RELÓGIO UTC', style: TextStyle(fontSize: 16, color: kDim)),
            const SizedBox(height: 4),
            Text('${formatUtc(_tools.clock.now)}${_tools.clock.overridden ? '  (OVERRIDE)' : ''}',
                style: TextStyle(fontSize: 8, color: _tools.clock.overridden ? kEssence : kText)),
            const SizedBox(height: 8),
            TextField(
              controller: _clockText,
              style: const TextStyle(fontSize: 16, color: kText),
              decoration: const InputDecoration(
                labelText: 'aaaa-mm-dd hh:mm (UTC)',
                labelStyle: TextStyle(fontSize: 8, color: kDim),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: kPanelLine, width: 2), borderRadius: BorderRadius.zero),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: kSignal, width: 2), borderRadius: BorderRadius.zero),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              PixelButton(label: 'Aplicar', color: kEssence, onTap: _applyClock),
              PixelButton(label: 'Relógio real', color: kDim, onTap: _tools.clock.clear),
            ]),
            const SizedBox(height: 32),
          ],
        ),
      );

  Future<void> _export() async {
    if (_sessions == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma sessão gravada ainda')));
      return;
    }
    await _exporter.export(_store!.file);
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: kOutline,
      body: SafeArea(
        child: d == null ? const Center(child: Text('Carregando...')) : _body(context, d),
      ),
    );
  }

  Widget _body(BuildContext context, TuningData d) {
    final setup = _setupFor(d, _species!);
    final intensity = setup.intensity(d.balance);
    // O menu é curto: uma coluna que rola constrói tudo, e a seção do mapa fica no topo.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        _simSection(),
        const Text('MAPA LIVRE · DEBUG', style: TextStyle(fontSize: 24, color: kVeil)),
        const SizedBox(height: 12),
        Row(children: [_coordField('Latitude', _lat), const SizedBox(width: 8), _coordField('Longitude', _lon)]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          PixelButton(label: 'Unicamp', color: kDim, onTap: () => _setCenter(kUnicamp)),
          PixelButton(label: 'Centro', color: kDim, onTap: () => _setCenter(kCentroCampinas)),
        ]),
        const SizedBox(height: 8),
        PixelButton(label: 'Abrir mapa', color: kSignal, onTap: _openMap),
        const SizedBox(height: 24),
        const Text('SINTONIA · DEBUG', style: TextStyle(fontSize: 24, color: kVeil)),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (final s in d.species) _speciesTile(s)],
        ),
        const SizedBox(height: 16),
        _slider('Nível do Eco', _ecoLevel, 1, 20, (v) => setState(() => _ecoLevel = v)),
        _slider('Conjurador', _playerLevel, 1, 15, (v) => setState(() => _playerLevel = v)),
        const SizedBox(height: 8),
        const Text('Selo', style: TextStyle(fontSize: 16, color: kDim)),
        DropdownButton<Seal>(
          value: _seal,
          isExpanded: true,
          dropdownColor: kPanel,
          style: const TextStyle(fontFamily: 'Silkscreen', fontSize: 16, color: kText),
          items: [for (final s in d.seals) DropdownMenuItem(value: s, child: Text(s.name))],
          onChanged: (s) => setState(() => _seal = s),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Tônico (+${d.tonics.first.extraTimeS.toStringAsFixed(0)} s)', style: const TextStyle(fontSize: 16)),
          value: _tonic,
          activeThumbColor: kVeil,
          onChanged: (v) => setState(() => _tonic = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mostrar alvo no dial', style: TextStyle(fontSize: 16)),
          value: _showTarget && !_hidden,
          activeThumbColor: kSignal,
          onChanged: _hidden ? null : (v) => setState(() => _showTarget = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Tipo oculto', style: TextStyle(fontSize: 16)),
          subtitle: const Text('Sorteia o tipo. Você sente a vibração e dá o palpite antes de sintonizar.', style: TextStyle(fontSize: 8, color: kDim)),
          value: _hidden,
          activeThumbColor: kVeil,
          onChanged: (v) => setState(() => _hidden = v),
        ),
        const SizedBox(height: 8),
        Text(
          'Resistência ${intensity.toStringAsFixed(2)}\n'
          'Tolerância ${setup.tolerance(d.balance).toStringAsFixed(3)}\n'
          'Tempo ${setup.timeLimitS(d.balance).toStringAsFixed(0)} s',
          style: const TextStyle(fontSize: 16, color: kDim, height: 1.5),
        ),
        const SizedBox(height: 16),
        PixelButton(
          label: 'Iniciar sintonia',
          color: kSignal,
          onTap: () => _start(d),
        ),
        const SizedBox(height: 16),
        Text('Sessões gravadas: $_sessions', style: const TextStyle(fontSize: 16, color: kDim)),
        const SizedBox(height: 8),
        PixelButton(label: 'Exportar registro', color: kVeil, onTap: _export),
        const SizedBox(height: 24),
        const Text('Sentir a vibração', style: TextStyle(fontSize: 16, color: kDim)),
        const SizedBox(height: 8),
        const Text('Identidade (ferramenta do modo tipo oculto)', style: TextStyle(fontSize: 8, color: kDim)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in EcoType.values)
            PixelButton(label: typeLabel(t), color: kVeil, onTap: () => _vibration.play(identityPattern(t))),
        ]),
        const SizedBox(height: 16),
        const Text('Alertas (durante a sintonia)', style: TextStyle(fontSize: 8, color: kDim)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          PixelButton(label: 'Fogo: aviso', color: kEssence, onTap: () => _vibration.play(fireWarningPattern)),
          PixelButton(label: 'Água: virada', color: kSignal, onTap: () => _vibration.play(waterSwellPattern)),
          PixelButton(label: 'Planta: broto', color: kVeil, onTap: () => _vibration.play(plantPulsePattern(90))),
        ]),
        ],
      ),
    );
  }

  Widget _speciesTile(EcoSpecies s) {
    final selected = !_hidden && s.id == _species?.id;
    return GestureDetector(
      onTap: _hidden ? null : () => setState(() => _species = s),
      child: Opacity(
        opacity: _hidden ? 0.35 : 1,
        child: Container(
        width: 104,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: selected ? kSignal : kPanelLine, width: 3),
          color: selected ? kPanel : null,
        ),
        child: Column(children: [
          RawImage(image: _sprites[s.id]?.normal, width: 72, height: 72, filterQuality: FilterQuality.none, fit: BoxFit.contain),
          const SizedBox(height: 4),
          Text(s.name, style: const TextStyle(fontSize: 8, color: kText)),
          Text(typeLabel(s.type), style: const TextStyle(fontSize: 8, color: kDim)),
        ]),
      ),
      ),
    );
  }

  Widget _slider(String label, int value, int min, int max, ValueChanged<int> onChanged) {
    return Row(children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 8, color: kDim))),
      Expanded(
        child: Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: kVeil,
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
      SizedBox(width: 32, child: Text('$value', textAlign: TextAlign.right, style: const TextStyle(fontSize: 16))),
    ]);
  }

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    _simLat.dispose();
    _simLon.dispose();
    _clockText.dispose();
    _vibration.cancel();
    super.dispose();
  }
}
