/// O Laboratório visual do debug (0.21.0): o quarteirão fixo da Praça Ramos de Azevedo no estilo de hoje e no novo, com antes e
/// depois, a hora do dia, o clima e até dois eventos, o giro do mapa e o custo do quadro. A faixa do céu no topo da tela
/// (`docs/art/estilo-mapa.md`, Céu do horizonte) é onde mora a parte de céu dos eventos. Nada disso entra no mapa principal
/// até o estilo ser aprovado. Só desenho; o clima e os eventos são os da época 12 (`stackIdOf`), só neste aparelho.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kProfileMode, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../core/astro.dart';
import '../../core/biomes.dart';
import '../../core/climate.dart';
import '../../data/climate_catalog.dart';
import '../../data/game_data.dart';
import '../../world/lab_block.dart';
import '../../world/map_camera.dart';
import '../city/city_renderer.dart';
import '../city/city_sources.dart';
import '../game/climate_layers.dart';
import '../game/climate_painter.dart';
import 'lab_art.dart';
import 'lab_renderer.dart';

/// Pixel de arte do laboratório, em dp (a regra do guia).
const double labArtDp = 3;

/// A altura da faixa do céu, em pixels de arte.
const int labSkyPx = 36;

class VisualLabScreen extends StatefulWidget {
  const VisualLabScreen({required this.nowUtc, super.key});

  /// O relógio do debug: a data do laboratório (a hora vem do controle).
  final int Function() nowUtc;

  @override
  State<VisualLabScreen> createState() => _VisualLabScreenState();
}

class _VisualLabScreenState extends State<VisualLabScreen> with SingleTickerProviderStateMixin {
  LabRenderer? _renderer;

  /// 0.22.0: o "depois" é o renderizador do mapa (estilo Completo) sobre o quarteirão.
  CityRenderer? _city;
  LabCityTiles? _labTiles;
  ClimateCatalog? _catalog;
  ClimateModel? _model;
  String? _error;
  late final Ticker _ticker = createTicker(_tick);
  final _painter = ClimatePainter();
  Duration _last = Duration.zero;
  double _time = 0;

  bool after = true;
  double hour = 10;
  String climate = 'clear';
  final events = <String>[];
  double rotation = 0, zoom = 1.1, cx = -40, cy = -10; // casas à esquerda, a praça à direita, um lote embaixo

  /// O custo de desenhar o quarteirão (média dos últimos 60 quadros, ms), separado por estilo.
  final _costs = {true: <double>[], false: <double>[]};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await GameData.load();
      final block = LabBlock.fromJson(jsonDecode(await rootBundle.loadString('assets/lab/centro_bloco.json')) as Map<String, dynamic>);
      final biomes = BiomeSet.fromJson(jsonDecode(await rootBundle.loadString('assets/data/biomes.json')) as Map<String, dynamic>);
      final model = data.schedule.epochs.reversed.map((e) => e.climate).firstWhere((m) => m?.layered ?? false, orElse: () => null);
      if (!mounted) return;
      setState(() {
        final art = LabArt.build();
        _renderer = LabRenderer(block, art, biomes);
        final tiles = _labTiles = LabCityTiles(block);
        _city = CityRenderer(art: art, tileAt: tiles.tileAt, biomeAt: tiles.biomeAt, cellsPerTile: LabCityTiles.cellsPerTile);
        _catalog = data.climates;
        _model = model;
      });
      _ticker.start();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  void _tick(Duration d) {
    final dt = ((d - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = d;
    _time += dt;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _renderer?.art.dispose();
    super.dispose();
  }

  /// A data de hoje do relógio do debug, na hora local escolhida (UTC−3, o fuso fixo do clima).
  int get _utc {
    final now = widget.nowUtc();
    final local = DateTime.fromMillisecondsSinceEpoch((now - 3 * 3600) * 1000, isUtc: true);
    return DateTime.utc(local.year, local.month, local.day).millisecondsSinceEpoch ~/ 1000 + (hour * 3600).round() + 3 * 3600;
  }

  String get _stack => _model == null ? climate : stackIdOf(_model!, climate, events);

  void _preset(double h, {String? c, List<String>? e}) => setState(() {
        hour = h;
        if (c != null) climate = c;
        if (e != null) {
          events
            ..clear()
            ..addAll(e);
        }
      });

  @override
  Widget build(BuildContext context) {
    final r = _renderer, cat = _catalog;
    if (_error != null) return Scaffold(body: Center(child: Text('Laboratório: $_error')));
    if (r == null || cat == null) return const Scaffold(body: Center(child: Text('Carregando o laboratório...')));
    final t = _utc;
    const lat = -22.9038, lon = -47.0678;
    final alt = sunAltitudeDeg(lat, lon, t), az = sunAzimuthDeg(lat, lon, t);
    final info = cat.of(_stack);
    final costs = _costs[after]!;
    final avg = costs.isEmpty ? 0.0 : costs.reduce((a, b) => a + b) / costs.length;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1424),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: GestureDetector(
              key: const Key('lab-view'),
              onPanUpdate: (d) => setState(() {
                final c = math.cos(-rotation), s = math.sin(-rotation);
                final dx = -d.delta.dx / labArtDp / zoom, dy = -d.delta.dy / labArtDp / zoom;
                cx += dx * c - dy * s;
                cy += dx * s + dy * c;
              }),
              child: LayoutBuilder(builder: (context, box) {
                final view = LabView(cx: cx, cy: cy, rotation: rotation, pxPerM: zoom, sunAltDeg: alt, sunAzDeg: az, localHour: hour.floor() % 24);
                return CustomPaint(
                  size: box.biggest,
                  painter: _LabPainter(
                    renderer: r,
                    city: _city!,
                    tiles: _labTiles!,
                    dpr: MediaQuery.devicePixelRatioOf(context),
                    month: DateTime.fromMillisecondsSinceEpoch(t * 1000, isUtc: true).month,
                    view: view,
                    after: after,
                    info: info,
                    climatePainter: _painter,
                    time: _time,
                    utc: t,
                    onCost: (ms) {
                      costs.add(ms);
                      if (costs.length > 60) costs.removeAt(0);
                    },
                  ),
                );
              }),
            ),
          ),
          Container(
            color: const Color(0xFF241C33),
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                '${after ? 'DEPOIS' : 'ANTES'} · ${hour.floor().toString().padLeft(2, '0')}h${((hour % 1) * 60).round().toString().padLeft(2, '0')} · SOL ${alt.round()}° · ${info.name.toUpperCase()} · QUADRO ${avg.toStringAsFixed(1)} MS (${kReleaseMode ? 'RELEASE' : kProfileMode ? 'PROFILE' : 'DEBUG, NÃO VALE'})',
                key: const Key('lab-status'),
                style: const TextStyle(fontSize: 8, color: Color(0xFFE8E4F4), height: 1.6),
              ),
              Wrap(spacing: 4, runSpacing: 2, children: [
                _chip('Antes', !after, () => setState(() => after = false), key: 'lab-before'),
                _chip('Depois', after, () => setState(() => after = true), key: 'lab-after'),
                _chip('Manhã', hour == 7.5, () => _preset(7.5), key: 'lab-morning'),
                _chip('Meio-dia', hour == 12.5, () => _preset(12.5), key: 'lab-noon'),
                _chip('Pôr do sol', hour == 18.75, () => _preset(18.75), key: 'lab-sunset'),
                _chip('Noite', hour == 22, () => _preset(22), key: 'lab-night'),
                _chip('Chuva', climate == 'rain' && events.isEmpty, () => _preset(hour, c: 'rain', e: const []), key: 'lab-rain'),
                _chip('Vigília + Tempestade', climate == 'storm' && events.contains('vigil'), () => _preset(hour, c: 'storm', e: const ['vigil']), key: 'lab-vigil-storm'),
                _chip('Limpo', climate == 'clear' && events.isEmpty, () => _preset(hour, c: 'clear', e: const []), key: 'lab-clear'),
              ]),
              Row(children: [
                const Text('HORA', style: TextStyle(fontSize: 8, color: Color(0xFF9A93AC))),
                Expanded(child: Slider(value: hour, min: 0, max: 23.75, divisions: 95, onChanged: (v) => setState(() => hour = v))),
                const Text('GIRO', style: TextStyle(fontSize: 8, color: Color(0xFF9A93AC))),
                Expanded(child: Slider(value: rotation, min: -math.pi, max: math.pi, onChanged: (v) => setState(() => rotation = v))),
              ]),
              SizedBox(
                height: 26,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final c in cat.climates.values)
                    if (!c.id.startsWith('crimson_rain') && c.id != 'prismatic_drizzle') _chip(c.name, climate == c.id, () => setState(() => climate = c.id)),
                ]),
              ),
              SizedBox(
                height: 26,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final e in cat.eventInfos.values)
                    _chip(e.name, events.contains(e.id), () => setState(() {
                          if (!events.remove(e.id)) {
                            events.add(e.id);
                            if (events.length > 2) events.removeAt(0);
                          }
                        }), color: const Color(0xFFFF7A45)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label, bool on, VoidCallback onTap, {String? key, Color color = const Color(0xFF9B7BFF)}) => Padding(
        padding: const EdgeInsets.only(right: 4),
        child: GestureDetector(
          key: key == null ? null : Key(key),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(color: on ? color : const Color(0xFF1A1424), border: Border.all(color: color)),
            child: Text(label.toUpperCase(), style: TextStyle(fontSize: 8, color: on ? const Color(0xFF1A1424) : const Color(0xFFE8E4F4))),
          ),
        ),
      );
}

class _LabPainter extends CustomPainter {
  _LabPainter({required this.renderer, required this.city, required this.tiles, required this.dpr, required this.month, required this.view, required this.after, required this.info, required this.climatePainter, required this.time, required this.utc, required this.onCost});

  final LabRenderer renderer;
  final CityRenderer city;
  final LabCityTiles tiles;
  final double dpr;
  final int month;
  final LabView view;
  final bool after;
  final ClimateInfo info;
  final ClimatePainter climatePainter;
  final double time;
  final int utc;
  final void Function(double ms) onCost;

  @override
  void paint(Canvas canvas, Size size) {
    final sw = Stopwatch()..start();
    final climate = info.id.split('+').first;
    if (after) {
      final (x, y) = tiles.toCells(view.cx, view.cy);
      final cam = MapCamera(centerX: x, centerY: y, pixelsPerCell: view.pxPerM * labArtDp * tiles.mpc, rotation: view.rotation);
      final wet = const {'drizzle', 'rain', 'storm', 'deluge', 'acid_rain', 'freezing_rain'}.contains(climate);
      city.paintGround(canvas, size, cam, dpr: dpr, artPixelDp: labArtDp, mpc: tiles.mpc, sunAltDeg: view.sunAltDeg, sunAzDeg: view.sunAzDeg, wet: wet, touching: false);
      city.paintUpright(canvas, size, cam,
          dpr: dpr, artPixelDp: labArtDp, mpc: tiles.mpc, sunAltDeg: view.sunAltDeg, sunAzDeg: view.sunAzDeg, localHour: view.localHour, month: month,
          snowRoofs: const {'snow', 'blizzard', 'veil_snow', 'frost'}.contains(climate), items: [size.center(Offset.zero)], skyFraction: 0.06, skyClimate: climate);
    } else {
      final w = (size.width / labArtDp).ceil(), h = (size.height / labArtDp).ceil();
      final rec = ui.PictureRecorder();
      final c = Canvas(rec);
      renderer.paint(c, Size(w.toDouble(), h.toDouble()), view);
      final img = rec.endRecording().toImageSync(w, h);
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Rect.fromLTWH(0, 0, w * labArtDp, h * labArtDp), Paint()..filterQuality = FilterQuality.none);
      img.dispose();
    }
    onCost(sw.elapsedMicroseconds / 1000);
    // O clima: no estilo novo, o céu do evento fica na faixa do topo e o resto (precipitação, tom) cobre a tela; no de hoje,
    // tudo cobre a tela, como no mapa.
    final skyRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.06);
    final screen = after ? ClimateInfo(id: '${info.id}#tela', name: info.name, base: info.base, hud: info.hud, layers: [for (final l in info.layers) if (!l.flag('sky')) l]) : info;
    climatePainter.update(1 / 60, size, screen);
    climatePainter.paint(canvas, size);
    if (after) {
      canvas.save();
      canvas.clipRect(skyRect);
      for (final l in info.layers) {
        if (l.flag('sky')) paintClimateLayer(canvas, skyRect.size, l, l.val('alpha', 0.8), time, player: skyRect.center);
      }
      if (info.id.split('+').contains('rainbow')) _rainbow(canvas, skyRect);
      canvas.restore();
    }
  }

  void _rainbow(Canvas c, Rect band) {
    const colors = [0xFFE86A5A, 0xFFF2B45A, 0xFFF2E36A, 0xFF7AD36A, 0xFF5AA8E8, 0xFF8A6AE8];
    for (final (i, col) in colors.indexed) {
      c.drawArc(
        Rect.fromCircle(center: Offset(band.center.dx, band.bottom + band.height * 0.6), radius: band.height * 1.25 - i * labArtDp),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = labArtDp
          ..isAntiAlias = false
          ..color = Color(col).withValues(alpha: 0.55),
      );
    }
  }

  @override
  bool shouldRepaint(_LabPainter old) => true;
}
