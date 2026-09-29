/// Menu de debug do M3: escolhe o Eco, os níveis, o selo e o tônico e abre a sintonia.
library;

import 'package:flutter/material.dart';

import '../capture/eco_type.dart';
import '../capture/seal.dart';
import '../capture/tuning_setup.dart';
import '../capture/vibe.dart';
import '../data/tuning_data.dart';
import '../ui/colors.dart';
import '../ui/sprites/sprite_image.dart';
import '../ui/tuning/tuning_screen.dart';
import '../ui/tuning/vibration_driver.dart';

class TuningDebugMenu extends StatefulWidget {
  const TuningDebugMenu({super.key});

  @override
  State<TuningDebugMenu> createState() => _TuningDebugMenuState();
}

class _TuningDebugMenuState extends State<TuningDebugMenu> {
  final _vibration = DeviceVibration();
  TuningData? _data;
  final _sprites = <String, EcoSprite>{};
  EcoSpecies? _species;
  Seal? _seal;
  int _ecoLevel = 1;
  int _playerLevel = 1;
  bool _tonic = false;
  bool _showTarget = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await TuningData.load();
    for (final s in data.species) {
      _sprites[s.id] = await EcoSprite.load(s.id);
    }
    if (!mounted) return;
    setState(() {
      _data = data;
      _species = data.species.first;
      _seal = data.seals.first;
    });
  }

  TuningSetup _setup(TuningData d) => TuningSetup(
        type: _species!.type,
        ecoLevel: _ecoLevel,
        playerLevel: _playerLevel,
        seal: _seal!,
        tonic: _tonic ? d.tonics.first : null,
      );

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
    final setup = _setup(d);
    final intensity = setup.intensity(d.balance);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
          value: _showTarget,
          activeThumbColor: kSignal,
          onChanged: (v) => setState(() => _showTarget = v),
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
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => TuningScreen(setup: setup, species: _species!, balance: d.balance, showTarget: _showTarget),
          )),
        ),
        const SizedBox(height: 24),
        const Text('Sentir a vibração', style: TextStyle(fontSize: 16, color: kDim)),
        const SizedBox(height: 8),
        const Text('Identidade (início da sintonia)', style: TextStyle(fontSize: 8, color: kDim)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final t in EcoType.values)
            PixelButton(label: _typeLabel(t), color: kVeil, onTap: () => _vibration.play(identityPattern(t))),
        ]),
        const SizedBox(height: 16),
        const Text('Resistência (durante)', style: TextStyle(fontSize: 8, color: kDim)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          PixelButton(label: 'Fogo: aviso', color: kEssence, onTap: () => _vibration.play(fireWarningPattern)),
          PixelButton(label: 'Água: onda', color: kSignal, onTap: () => _vibration.play(waterSwellPattern)),
          PixelButton(label: 'Planta: pulso', color: kVeil, onTap: () => _vibration.play(plantPulsePattern(90))),
        ]),
      ],
    );
  }

  String _typeLabel(EcoType t) => switch (t) {
        EcoType.fire => 'Fogo',
        EcoType.water => 'Água',
        EcoType.plant => 'Planta',
      };

  Widget _speciesTile(EcoSpecies s) {
    final selected = s.id == _species?.id;
    return GestureDetector(
      onTap: () => setState(() => _species = s),
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
          Text(_typeLabel(s.type), style: const TextStyle(fontSize: 8, color: kDim)),
        ]),
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
    _vibration.cancel();
    super.dispose();
  }
}
