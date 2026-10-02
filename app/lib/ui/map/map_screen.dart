import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../core/biomes.dart';
import '../../data/region_loader.dart';
import '../../world/map_camera.dart';
import '../../world/region_map.dart';
import '../colors.dart';
import '../tuning/tuning_screen.dart' show PixelButton;
import 'biome_textures.dart';
import 'map_game.dart';
import 'map_hud.dart';
import 'map_renderer.dart';

/// Região do M4: a única com pacote.
const String kRegion = 'campinas';


/// Tela do mapa estático (M4): carrega e confere o pacote da região e mostra a grade de biomas em
/// torno de ([lat], [lon]), com câmera arrastável e zoom por pinça. É ferramenta do menu de debug.
///
/// Se o pacote não bate com a época vigente, mostra o erro em vez do mapa, e o app segue vivo.
class MapScreen extends StatefulWidget {
  const MapScreen({
    required this.lat,
    required this.lon,
    this.scale = MapCamera.defaultScale,
    this.nowUtc,
    this.bundle,
    super.key,
  });

  final double lat;
  final double lon;

  /// Escala inicial, em pixels lógicos por célula. Por padrão, a da spec (16).
  final double scale;

  /// Relógio em segundos UTC. Por padrão, agora.
  final int? nowUtc;

  /// De onde vêm os assets. Por padrão, os do app.
  final AssetBundle? bundle;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _Ready {
  _Ready(this.game, this.biomes, this.atlas, this.stale);

  final MapGame game;
  final BiomeSet biomes;
  final ui.Image atlas;
  final bool stale;
}

class _MapScreenState extends State<MapScreen> {
  late final Future<Object> _loading = _load();
  _Ready? _ready;

  Future<Object> _load() async {
    final now = widget.nowUtc ?? DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final assets = widget.bundle ?? rootBundle;
    final region = await loadRegion(region: kRegion, nowUtc: now, bundle: assets);
    if (region is RegionLoadError) return region.message;
    final loaded = region as RegionLoaded;
    final biomes = BiomeSet.fromJson(jsonDecode(await assets.loadString('assets/data/biomes.json')) as Map<String, dynamic>);
    final atlas = await buildBiomeAtlas(biomes);
    final renderer = MapRenderer(map: RegionMap(pack: loaded.pack, biomes: biomes), atlas: atlas);
    final game = MapGame(renderer: renderer, camera: MapCamera.atLatLon(widget.lat, widget.lon, pixelsPerCell: widget.scale));
    final ready = _Ready(game, biomes, atlas, loaded.stale);
    _ready = ready;
    return ready;
  }

  @override
  void dispose() {
    _ready?.game.renderer.dispose();
    _ready?.atlas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOutline,
      body: FutureBuilder<Object>(
        future: _loading,
        builder: (context, snap) {
          final data = snap.data;
          if (snap.hasError) return _Error(message: 'Erro ao abrir o mapa: ${snap.error}');
          if (data == null) return const Center(child: Text('Carregando mapa...', style: TextStyle(fontSize: 16, color: kDim)));
          if (data is String) return _Error(message: data);
          return _MapView(ready: data as _Ready);
        },
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('MAPA INDISPONÍVEL', style: TextStyle(fontSize: 24, color: kEssence)),
            const SizedBox(height: 16),
            Text(message, style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
            const SizedBox(height: 24),
            PixelButton(label: 'Voltar', color: kVeil, onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({required this.ready});

  final _Ready ready;

  @override
  Widget build(BuildContext context) {
    final game = ready.game;
    return Stack(
      children: [
        // O dedo: a sonda acompanha o toque, e o gesto de escala cobre arrastar e pinça.
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => game.touch(e.localPosition.dx, e.localPosition.dy),
          onPointerMove: (e) => game.touch(e.localPosition.dx, e.localPosition.dy),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: (_) => game.scaleStart(),
            onScaleUpdate: (d) => game.scaleUpdate(
              fx: d.localFocalPoint.dx,
              fy: d.localFocalPoint.dy,
              dx: d.focalPointDelta.dx,
              dy: d.focalPointDelta.dy,
              scale: d.scale,
            ),
            child: GameWidget(game: game),
          ),
        ),
        SafeArea(
          child: Stack(
            children: [
              MapHud(game: game, biomes: ready.biomes, stale: ready.stale),
              Positioned(
                left: 0,
                top: 0,
                width: 48,
                height: 48,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: const Center(child: Text('<', style: TextStyle(fontSize: 24, color: kText))),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
