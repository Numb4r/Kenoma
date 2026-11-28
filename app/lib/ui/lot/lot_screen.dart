/// O lote no Véu (0.29.0, GDD rev 402): a cena da casa. O Conjurador anda tocando no chão (o caminho contorna paredes e
/// objetos), o Familiar segue, as criaturas que trabalham ficam na frente da estação e as guardadas passeiam devagar.
/// Tocar numa estação abre o cartão dela (o mesmo do app Casa); na Bancada, a Bancada; no baú, na estante ou no santuário,
/// o Armazém. O modo construir abre a paleta por abas; peça escolhida entra na casa tocada, peça tocada pode girar, mover
/// ou voltar para o Armazém. A regra fica em `crafting/lot_actions.dart`; aqui só se desenha e se toca.
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../../core/astro.dart' show dayLightAt;
import '../../core/fnv.dart';
import '../../core/tiles.dart';
import '../../crafting/lot_actions.dart';
import '../../crafting/home_actions.dart' show ensureLotStarted;
import '../../crafting/stations.dart' show workersOf;
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../../player/lot.dart';
import '../../world/lot_path.dart';
import '../colors.dart';
import '../craft/bench_screen.dart';
import '../craft/craft_context.dart';
import '../craft/ui_art.dart';
import '../game/creature_anim.dart';
import '../game/creature_art.dart';
import '../menu/home_screen.dart';
import '../sprites/familiar_sprite.dart';
import '../sprites/sprite_image.dart';
import '../tuning/tuning_screen.dart' show PixelButton;
import 'lot_painter.dart';

class LotScreen extends StatefulWidget {
  const LotScreen({required this.state, required this.data, required this.ctx, this.startBuild = false, this.animate = true, super.key});

  final GameState state;
  final GameData data;
  final CraftContext ctx;

  /// Abre já no modo construir (o debug e as capturas).
  final bool startBuild;

  /// Sem o relógio de quadros (testes de widget: o ticker sem fim prende o `pumpAndSettle`).
  final bool animate;

  @override
  State<LotScreen> createState() => _LotScreenState();
}

class _Wander {
  _Wander(this.x, this.y);
  double x, y;
  List<(int, int)> path = [];
  double wait = 1;
  int step = 0;
  bool left = false;
}

class _LotScreenState extends State<LotScreen> with SingleTickerProviderStateMixin {
  GameState get _s => widget.state;
  GameData get _d => widget.data;
  String _t(String key) => _d.home.text(key);

  Ticker? _ticker;
  Duration _last = Duration.zero;
  double _time = 0;

  // O Conjurador (pés em casas) e o Familiar, atrás dele.
  double _px = 0.5, _py = 0.7, _fx = -0.5, _fy = 0.7;
  bool _left = false;
  List<(int, int)> _path = [];
  bool get _walking => _path.isNotEmpty;

  final _wander = <String, _Wander>{};
  List<ui.Image> _playerFrames = const [];
  ui.Image? _familiar;
  final _sprites = <String, ui.Image>{};

  // O modo construir.
  late bool _build = widget.startBuild;
  String _tab = 'floor';
  String? _piece;
  int _rot = 0;
  int? _selected;
  bool _moving = false;
  List<(int, int)>? _ghost;
  bool _ghostOk = true;

  @override
  void initState() {
    super.initState();
    ensureLotStarted(_s, _d);
    final start = nearestWalkable((0, 1), lotGrid(_s, _d).walkable, radius: 8) ?? (0, 1);
    _px = start.$1 + 0.5;
    _py = start.$2 + 0.7;
    _fx = start.$1 - 0.5;
    _fy = _py;
    if (_d.home.tabs.isNotEmpty) _tab = _d.home.tabs.first.$1;
    if (widget.animate) _ticker = createTicker(_tick)..start();
    unawaited(_load());
  }

  Future<void> _load() async {
    final frames = await loadPlayerFramesMap();
    final fam = await loadFamiliarImage(school: _s.conjurer.school);
    if (!mounted) return;
    setState(() {
      _playerFrames = frames;
      _familiar = fam;
    });
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  void _tick(Duration now) {
    final dt = ((now - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = now;
    _time += dt;
    _stepPlayer(dt);
    _stepWanderers(dt, lotGrid(_s, _d));
    setState(() {});
  }

  void _stepPlayer(double dt) {
    final cps = _s.balance.home.walkCps;
    var budget = cps * dt;
    while (_path.isNotEmpty && budget > 0) {
      final (cx, cy) = _path.first;
      final tx = cx + 0.5, ty = cy + 0.7;
      final dx = tx - _px, dy = ty - _py;
      final dist = (dx * dx + dy * dy);
      if (dist < 1e-6) {
        _path.removeAt(0);
        continue;
      }
      final d = dist < budget * budget ? 1.0 : budget / math.sqrt(dist);
      if (dx.abs() > 1e-3) _left = dx < 0;
      _px += dx * d;
      _py += dy * d;
      budget -= math.sqrt(dist) * d;
      if (d >= 1) _path.removeAt(0);
    }
    // O Familiar vai atrás, a uma casa, sem pressa.
    final fx = _px + (_left ? 0.9 : -0.9), fy = _py;
    _fx += (fx - _fx) * (dt * 3).clamp(0, 1);
    _fy += (fy - _fy) * (dt * 3).clamp(0, 1);
  }

  /// As guardadas no santuário passeiam: um destino perto a cada poucos segundos, pelo caminho, devagar.
  void _stepWanderers(double dt, LotGrid grid) {
    final stored = _s.home.stored;
    _wander.removeWhere((k, _) => !stored.contains(k));
    for (final uid in stored) {
      final w = _wander.putIfAbsent(uid, () {
        final h = fnv1a64([for (final c in uid.codeUnits) c]);
        final c = nearestWalkable((hashMod(h, 8) - 4, hashMod(fnv1a64([h, 1]), 8) - 4), grid.walkable, radius: 10) ?? (0, 0);
        return _Wander(c.$1 + 0.5, c.$2 + 0.7);
      });
      if (w.path.isEmpty) {
        w.wait -= dt;
        if (w.wait > 0) continue;
        final h = fnv1a64([for (final c in uid.codeUnits) c, w.step++]);
        final from = (w.x.floor(), w.y.floor());
        final target = nearestWalkable((from.$1 + hashMod(h, 7) - 3, from.$2 + hashMod(fnv1a64([h, 2]), 7) - 3), grid.walkable, radius: 3);
        w.path = target == null ? [] : (lotPath(from, target, grid.walkable) ?? []);
        w.wait = 3 + hashMod(fnv1a64([h, 3]), 4).toDouble();
        continue;
      }
      var budget = _s.balance.home.wanderCps * dt;
      while (w.path.isNotEmpty && budget > 0) {
        final (cx, cy) = w.path.first;
        final dx = cx + 0.5 - w.x, dy = cy + 0.7 - w.y;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist <= budget) {
          w.x += dx;
          w.y += dy;
          budget -= dist;
          w.path.removeAt(0);
        } else {
          if (dx.abs() > 1e-3) w.left = dx < 0;
          w.x += dx / dist * budget;
          w.y += dy / dist * budget;
          budget = 0;
        }
      }
    }
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));

  String _piece_(String item) => _d.itemName(item);

  void _lotResult(LotResult r, String item) {
    final msg = switch (r) {
      LotResult.ok => null,
      LotResult.outside => _t('lot_no_fit'),
      LotResult.occupied => _t('lot_occupied'),
      LotResult.needsWall => _t('lot_needs_wall').replaceAll('{peca}', _piece_(item)),
      LotResult.needsStraightWall => _t('lot_needs_straight_wall').replaceAll('{peca}', _piece_(item)),
      LotResult.needsFrontWall => _t('lot_needs_front_wall'),
      LotResult.storageFull => _t('lot_storage_full'),
      LotResult.noneLeft => _t('lot_none_left'),
      LotResult.noHome || LotResult.invalid => 'Não deu.',
    };
    if (msg != null) _say(msg);
  }

  /// Anda até [cell] (ou a casa livre mais perto dela).
  void _walkTo((int, int) cell) {
    final g = lotGrid(_s, _d);
    final target = nearestWalkable(cell, g.walkable, radius: 4);
    if (target == null) return;
    final from = (_px.floor(), _py.floor());
    final path = lotPath(g.walkable(from.$1, from.$2) ? from : (nearestWalkable(from, g.walkable) ?? from), target, g.walkable);
    if (path != null) _path = path.skip(1).toList();
  }

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _onTap(Size view, Offset at) {
    final (cx, cy) = LotPainter.cellAt(view, _px, _py - 1, at);
    final g = lotGrid(_s, _d);
    if (!_build) {
      final hit = g.object[(cx, cy)];
      final d = hit == null ? null : _d.home.pieces[hit.item];
      _walkTo((cx, cy));
      if (d?.station != null) _open(HomeScreen(state: _s, data: _d, ctx: widget.ctx, inLot: true, focus: 'station:${d!.station}'));
      if (d?.opens == 'bench') _open(CraftBenchScreen(state: _s, data: _d, ctx: widget.ctx));
      if (d?.opens == 'storage') _open(HomeScreen(state: _s, data: _d, ctx: widget.ctx, inLot: true, focus: 'storage'));
      return;
    }
    final now = widget.ctx.nowUtc();
    final sel = _selected;
    if (sel != null && _moving) {
      final p = _s.home.lot.placed.firstWhere((q) => q.uid == sel);
      final r = movePiece(_s, _d, sel, cx, cy, p.rot);
      _lotResult(r, p.item);
      setState(() {
        _moving = false;
        if (r == LotResult.ok) _selected = null;
      });
      return;
    }
    final item = _piece;
    if (item != null) {
      final d = _d.home.pieces[item]!;
      final r = placePiece(_s, _d, item, cx, cy, _rot, now);
      _lotResult(r, item);
      setState(() {
        _ghost = footprint(d, cx, cy, d.turns ? _rot : 0).toList();
        _ghostOk = r == LotResult.ok;
      });
      return;
    }
    final hit = g.topAt(cx, cy);
    setState(() {
      _selected = hit?.uid;
      _ghost = null;
    });
  }

  List<LotBeing> _beings(LotGrid g) {
    final out = <LotBeing>[];
    final frame = _playerFrames.isEmpty ? null : _playerFrames[_walking ? ((_time * 8).floor() % _playerFrames.length) : 0];
    out.add(LotBeing(image: frame, src: frame == null ? Rect.zero : Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()), x: _px, y: _py, sizePx: mapPlayerPx, flip: _left));
    final fam = _familiar;
    out.add(LotBeing(image: fam, src: fam == null ? Rect.zero : Rect.fromLTWH(0, 0, fam.width.toDouble(), fam.height.toDouble()), x: _fx, y: _fy, sizePx: 16, flip: _left));
    // Quem trabalha fica na frente da estação, uma casa para cada; quem passa da largura fica ao lado.
    for (final p in g.state.placed) {
      final station = _d.home.pieces[p.item]?.station;
      if (station == null) continue;
      final ws = workersOf(_s, _s.home.station(station));
      final front = g.frontOf(p);
      for (final (i, w) in ws.indexed) {
        final c = _s.creature(w.uid);
        if (c == null) continue;
        final (x, y) = front[i % front.length];
        out.add(_creature(c, x + 0.5 + (i ~/ front.length) * 0.4, y + 0.7, flip: false));
      }
    }
    for (final e in _wander.entries) {
      final c = _s.creature(e.key);
      if (c != null) out.add(_creature(c, e.value.x, e.value.y, flip: e.value.left));
    }
    return out;
  }

  LotBeing _creature(CreatureInstance c, double x, double y, {required bool flip}) {
    final art = CreatureArt.of(c.speciesId);
    final px = mapPxOf(c.speciesId);
    if (art != null) {
      final strip = art.anims[CreatureAnim.idle]!;
      final body = art.bodyOf(CreatureAnim.idle, c.shiny ? null : c.variant);
      final k = loopFrame(_time, strip.frames, strip.fps, uid: c.uid.hashCode & 0xFFFF);
      final f = art.frame.toDouble();
      return LotBeing(image: body, src: Rect.fromLTWH(k * f, 0, f, f), x: x, y: y, sizePx: px, flip: flip);
    }
    final img = _sprites[c.speciesId];
    if (img == null && !_sprites.containsKey('loading:${c.speciesId}')) {
      unawaited(EcoSprite.loadMap(c.speciesId).then((s) {
        if (mounted) setState(() => _sprites[c.speciesId] = s.normal);
      }));
    }
    return LotBeing(image: img, src: img == null ? Rect.zero : Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), x: x, y: y, sizePx: px, flip: flip);
  }

  @override
  Widget build(BuildContext context) {
    final g = lotGrid(_s, _d);
    final c = _s.home.center;
    final (lat, lon) = c == null ? (-22.9, -47.06) : tileFractionToLatLon(c.$1, c.$2, biomeZoom);
    final working = {
      for (final p in g.state.placed)
        if (_d.home.pieces[p.item]?.station case final st? when (_s.home.stations[st]?.workers.isNotEmpty ?? false)) p.uid,
    };
    return Scaffold(
      key: const Key('lot-screen'),
      backgroundColor: const Color(0xFF120E1A),
      body: Stack(children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, box) => GestureDetector(
              key: const Key('lot-scene'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _onTap(box.biggest, d.localPosition),
              child: CustomPaint(
                size: box.biggest,
                painter: LotPainter(LotFrame(
                  grid: g,
                  camX: _px,
                  camY: _py - 1,
                  time: _time,
                  light: dayLightAt(lat, lon, widget.ctx.nowUtc()),
                  beings: _beings(g),
                  working: working,
                  ghost: _build ? _ghost : null,
                  ghostOk: _ghostOk,
                  selected: _build ? _selected : null,
                  build: _build,
                )),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 8, children: [
              PixelButton(key: const Key('lot-exit'), label: _t('lot_exit'), color: kVeil, onTap: () => Navigator.of(context).maybePop()),
              PixelButton(
                key: const Key('lot-build'),
                label: _build ? _t('lot_done') : _t('lot_build'),
                color: _build ? kSignal : kDim,
                onTap: () => setState(() {
                  _build = !_build;
                  _piece = null;
                  _selected = null;
                  _moving = false;
                  _ghost = null;
                }),
              ),
            ]),
          ),
        ),
        ),
        if (_build) Positioned(left: 0, right: 0, bottom: 0, child: SafeArea(top: false, child: _palette())),
      ]),
    );
  }

  Widget _palette() {
    final pieces = [for (final p in _d.home.pieces.values) if (p.tab == _tab) p];
    final sel = _selected;
    final selPiece = sel == null ? null : _s.home.lot.placed.where((p) => p.uid == sel).firstOrNull;
    final selDef = selPiece == null ? null : _d.home.pieces[selPiece.item];
    return Container(
      key: const Key('lot-palette'),
      color: kOutline.withValues(alpha: 0.92),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Abas só com ícone; o rótulo aparece na ativa.
        Row(children: [
          for (final (id, _) in _d.home.tabs)
            Expanded(
              child: GestureDetector(
                key: Key('lot-tab-$id'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _tab = id;
                  _piece = null;
                }),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: id == _tab ? kVeil : Colors.transparent, width: 2))),
                  child: _icon(_d.home.pieces.values.where((p) => p.tab == id).firstOrNull?.item, 24, dim: id != _tab),
                ),
              ),
            ),
        ]),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text((_d.home.tabs.where((t) => t.$1 == _tab).firstOrNull?.$2 ?? '').toUpperCase(), style: const TextStyle(fontSize: 8, color: kVeil)),
        ),
        SizedBox(
          height: 64,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final p in pieces)
              GestureDetector(
                key: Key('lot-piece-${p.item}'),
                onTap: () => setState(() {
                  _piece = _piece == p.item ? null : p.item;
                  _selected = null;
                  _moving = false;
                }),
                child: Container(
                  width: 64,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(color: kPanel, border: Border.all(color: _piece == p.item ? kSignal : kPanelLine, width: 2)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _icon(p.item, 32),
                    Text('${piecesLeft(_s, p.item)}', key: Key('lot-count-${p.item}'), style: const TextStyle(fontSize: 8, color: kText)),
                  ]),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (_piece != null && (_d.home.pieces[_piece]?.turns ?? false))
            PixelButton(key: const Key('lot-turn'), label: _t('lot_turn'), color: kVeil, onTap: () => setState(() => _rot = (_rot + 1) % 4)),
          if (selPiece != null && selDef != null) ...[
            if (selDef.turns)
              PixelButton(
                key: const Key('lot-turn-selected'),
                label: _t('lot_turn'),
                color: kVeil,
                onTap: () {
                  final r = movePiece(_s, _d, selPiece.uid, selPiece.x, selPiece.y, selPiece.rot + 1);
                  _lotResult(r, selPiece.item);
                  setState(() {});
                },
              ),
            PixelButton(key: const Key('lot-move'), label: _t('lot_move'), color: _moving ? kSignal : kVeil, onTap: () => setState(() => _moving = !_moving)),
            PixelButton(
              key: const Key('lot-store'),
              label: _t('lot_store'),
              color: kEssence,
              onTap: () {
                final r = removePiece(_s, _d, selPiece.uid, widget.ctx.nowUtc());
                _lotResult(r.result, selPiece.item);
                if (r.result == LotResult.ok) {
                  _say(r.back.length > 1 ? _t('lot_wall_removed').replaceAll('{peca}', _piece_(r.back.last)) : _t('lot_returned').replaceAll('{peca}', _piece_(selPiece.item)));
                }
                setState(() => _selected = null);
              },
            ),
          ],
        ]),
      ]),
    );
  }

  Widget _icon(String? item, double size, {bool dim = false}) {
    final img = item == null ? null : UiArt.instance?.icon(item);
    if (img == null) return SizedBox(width: size, height: size, child: Container(color: dim ? kPanelLine : kVeil));
    return Opacity(opacity: dim ? 0.5 : 1, child: SizedBox(width: size, height: size, child: RawImage(image: img, filterQuality: FilterQuality.none, fit: BoxFit.contain)));
  }
}
