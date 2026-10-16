/// Seção do menu de debug (sempre acessível, CLAUDE.md) para a "Rua viva": forçar o comportamento, a variante, o Brilhante
/// e o clima do próximo spawn; revelar ou limpar a névoa; zerar a recarga do Radar. Forçar vale para o próximo Eco novo
/// desta sessão; a névoa e o Radar mexem no `save.json` (valem na próxima vez que o mapa abrir).
library;

import 'package:flutter/material.dart';

import '../core/behavior.dart';
import '../core/tiles.dart';
import '../core/weather.dart';
import '../save/ksv_save_store.dart';
import '../save/migrations.dart';
import '../save/save_store.dart';
import '../ui/colors.dart';
import '../ui/tuning/tuning_screen.dart' show PixelButton;
import '../world/fog.dart';
import 'dev_tools.dart';

/// Revela a névoa num círculo de [radiusM] em torno de ([lat], [lon]) no conjunto de debug (que dá para limpar). Devolve
/// o save novo. Puro: o menu só lê e grava.
Map<String, dynamic> revealDebugFog(Map<String, dynamic> save, double lat, double lon, double radiusM) {
  final out = migrateSave(save);
  final fog = FogState.fromJson(out['fog'] as Map<String, dynamic>?);
  final (x, y) = latLonToTileFraction(lat, lon, biomeZoom);
  fog.reveal(x, y, radiusM, metersPerCell(lat), debug: true);
  return {...out, 'fog': fog.toJson()};
}

/// Apaga só a névoa que veio do simulador ou do debug: o caminho real fica.
Map<String, dynamic> clearDebugFog(Map<String, dynamic> save) {
  final out = migrateSave(save);
  final fog = FogState.fromJson(out['fog'] as Map<String, dynamic>?)..clearDebug();
  return {...out, 'fog': fog.toJson()};
}

/// Zera a recarga do Radar e esquece os Ocultos que ele tinha revelado.
Map<String, dynamic> resetRadar(Map<String, dynamic> save) => {
      ...migrateSave(save),
      'radar': {'last_utc': 0, 'revealed': <String, dynamic>{}},
    };

class StreetDebugSection extends StatefulWidget {
  const StreetDebugSection({required this.tools, required this.center, this.store, super.key});

  final DevTools tools;

  /// O ponto em torno do qual "revelar névoa" age (o centro do menu: Unicamp por padrão).
  final (double, double) Function() center;
  final SaveStore? store;

  @override
  State<StreetDebugSection> createState() => _StreetDebugSectionState();
}

class _StreetDebugSectionState extends State<StreetDebugSection> {
  String _status = '';

  Future<void> _edit(Map<String, dynamic> Function(Map<String, dynamic>) change, String done) async {
    try {
      final store = widget.store ?? await KsvSaveStore.inDocuments();
      final raw = await store.read();
      if (raw == null) {
        setState(() => _status = 'Ainda não há jogo salvo: abra o mapa uma vez.');
        return;
      }
      await store.write(change(raw));
      if (mounted) setState(() => _status = done);
    } catch (e) {
      if (mounted) setState(() => _status = 'Erro: $e');
    }
  }

  Widget _chip(String label, bool on, VoidCallback tap, {Color color = kSignal}) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(border: Border.all(color: on ? color : kPanelLine, width: 2)),
          child: Text(label.toUpperCase(), style: TextStyle(fontSize: 8, color: on ? color : kDim)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final force = widget.tools.force;
    return ListenableBuilder(
      listenable: force,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('RUA VIVA · DEBUG', style: TextStyle(fontSize: 24, color: kVeil))),
          const Text('PRÓXIMO ECO NOVO À VISTA', style: TextStyle(fontSize: 8, color: kDim)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final b in EcoBehavior.values)
              _chip(b.label, force.nextBehavior == b, () => force.set(behavior: b), color: kEssence),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('Variante de bioma', force.nextVariant, () => force.set(variant: !force.nextVariant)),
            _chip('Brilhante', force.nextShiny, () => force.set(shiny: !force.nextShiny)),
            _chip('Limpar pedidos', false, () {
              force.nextBehavior = null;
              force.set(variant: false, shiny: false);
            }, color: kDim),
          ]),
          const SizedBox(height: 16),
          const Text('CLIMA FORÇADO (HUD, CHUVA E SPAWNS)', style: TextStyle(fontSize: 8, color: kDim)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('Real', force.weather == null, () => force.set(clearWeather: true), color: kVeil),
            for (final w in Weather.values) _chip(w.label, force.weather == w, () => force.set(weather: w), color: kVeil),
          ]),
          const SizedBox(height: 16),
          PixelButton(
            label: 'Revelar névoa (600 m)',
            color: kSignal,
            onTap: () {
              final (lat, lon) = widget.center();
              _edit((j) => revealDebugFog(j, lat, lon, 600), 'Névoa revelada em 600 m (debug).');
            },
          ),
          const SizedBox(height: 8),
          PixelButton(label: 'Limpar névoa de debug', color: kDim, onTap: () => _edit(clearDebugFog, 'Névoa de debug apagada; o caminho real ficou.')),
          const SizedBox(height: 8),
          PixelButton(label: 'Zerar recarga do Radar', color: kEssence, onTap: () => _edit(resetRadar, 'Radar pronto.')),
          if (_status.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status.toUpperCase(), style: const TextStyle(fontSize: 8, color: kText, height: 1.8))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
