import 'package:flutter/material.dart';

import '../../core/biomes.dart';
import '../colors.dart';
import 'map_game.dart';

/// Painel de debug do mapa: centro, escala, o que há sob o dedo e a opção da grade z20.
class MapHud extends StatefulWidget {
  const MapHud({required this.game, required this.biomes, this.stale = false, super.key});

  final MapGame game;
  final BiomeSet biomes;

  /// O relógio está fora das épocas: o mapa funciona, mas o mundo está desatualizado.
  final bool stale;

  @override
  State<MapHud> createState() => _MapHudState();
}

class _MapHudState extends State<MapHud> {
  MapGame get game => widget.game;
  BiomeSet get biomes => widget.biomes;

  String _deg(double v) => v.toStringAsFixed(5);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.88), border: Border.all(color: kPanelLine, width: 2)),
        child: ValueListenableBuilder<MapHudData>(
          valueListenable: game.hud,
          builder: (context, d, _) {
            final p = d.probe;
            final style = const TextStyle(fontSize: 8, color: kText, height: 1.6);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.stale) const Text('MUNDO DESATUALIZADO', style: TextStyle(fontSize: 8, color: kEssence, height: 1.6)),
                Text('CENTRO ${_deg(d.lat)}, ${_deg(d.lon)}', style: style),
                Text('Z21 ${d.cellX},${d.cellY} · ZOOM ${d.pixelsPerCell.toStringAsFixed(1)} PX/CÉL', style: style),
                if (p == null)
                  Text('TOQUE NO MAPA PARA VER O QUE HÁ SOB O DEDO', style: style.copyWith(color: kDim))
                else ...[
                  Text('DEDO ${_deg(p.lat)}, ${_deg(p.lon)}', style: style.copyWith(color: kSignal)),
                  Text('Z21 ${p.x21},${p.y21} · ${biomes.byId(p.biome21).name.toUpperCase()}', style: style.copyWith(color: kSignal)),
                  Text('Z20 ${p.x20},${p.y20} · SPAWN ${biomes.byId(p.spawnBiome20).name.toUpperCase()}',
                      style: style.copyWith(color: kVeil)),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('GRADE Z20', style: style),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 32,
                      child: FittedBox(
                        child: Switch(
                          value: game.grid20,
                          activeThumbColor: kVeil,
                          onChanged: (v) => setState(() => game.setGrid20(v)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
