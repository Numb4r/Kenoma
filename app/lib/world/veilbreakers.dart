/// Os Outros Veilbreakers (0.24.5, docs/GDD.md, "Outros Veilbreakers"): NPCs de jogo, por regras, gerados pela seed e
/// iguais para amigos no mesmo lugar e hora. Quem está em cada célula z18 em cada fatia de tempo, o caminho de ida e volta
/// dele na calçada, onde ele está em cada instante e quais Ecos ele sintoniza. Só entram nas épocas com `veilbreakers`
/// (da 12 em diante). Dart puro.
///
/// **Mundo:** presença, identidade, posição e sintonia saem de `hash(seed, época, célula, fatia)` e da camada base dos
/// spawns, então dois aparelhos veem o mesmo NPC no mesmo lugar e o mesmo Eco sumir. A única exceção é local: um Eco a até
/// `protect_m` do jogador nunca some na frente dele (no outro aparelho, longe, some).
library;

import 'dart:math' as math;

import '../core/fnv.dart';
import '../core/veilbreaker_model.dart';
import '../core/walkable.dart';
import '../core/windows.dart';
import 'npc_data.dart';
import 'spawn_field.dart' show WorldSpawn;

const int _saltNpc = 0x56424b52; // 'VBKR'
const int _saltKnown = 0x4b4e574e;
const int _saltTune = 0x54554e45;

/// O deslocamento do fuso fixo do clima (UTC-3): hora e dia da semana locais, iguais para todo o grupo.
const int kVeilLocalOffsetS = -3 * 3600;

double _unit(int h) => (h >>> 11) / (1 << 53);

/// Uma sintonia: o NPC para e o Eco [eco] some a partir de [atUtc] (com a animação de [VeilbreakerModel.tuneAnimS]).
class VeilTune {
  const VeilTune(this.eco, this.atUtc);

  final WorldSpawn eco;
  final int atUtc;
}

class Veilbreaker {
  Veilbreaker._({
    required this.id,
    required this.known,
    required this.nameIndex,
    required this.nicknameIndex,
    required this.school,
    required this.outfit,
    required this.startUtc,
    required this.endUtc,
    required this.path,
    required this.walkCellsPerS,
    required this.tunes,
    required this.pauseS,
    required this.animS,
  }) : _len = _lengths(path);

  /// `npc.<cx>.<cy>.<fatia>` para os sorteados; o id do `npc.json` (`known.lorena`) para os conhecidos.
  final String id;
  final KnownNpc? known;

  /// Nos sorteados: o nome (`npc.json`, `names`) e o apelido (`nicknames`, -1: sem).
  final int nameIndex, nicknameIndex;
  final String school;
  final int outfit;

  /// A fatia em que ele está na célula: `[startUtc, endUtc)`.
  final int startUtc, endUtc;

  /// O caminho de ida e volta (células z21), andado em laço.
  final List<(double, double)> path;
  final double walkCellsPerS;
  final List<VeilTune> tunes;
  final double pauseS, animS;
  final List<double> _len;

  static List<double> _lengths(List<(double, double)> p) {
    final out = <double>[0];
    for (var i = 1; i < p.length; i++) {
      out.add(out.last + math.sqrt(math.pow(p[i].$1 - p[i - 1].$1, 2) + math.pow(p[i].$2 - p[i - 1].$2, 2)));
    }
    return out;
  }

  bool presentAt(double t) => t >= startUtc && t < endUtc;

  /// Os intervalos parados: de [pauseS] antes de cada sintonia até o fim da animação dela.
  Iterable<(double, double)> get _pauses => [for (final s in tunes) (s.atUtc - pauseS, s.atUtc + animS)];

  /// Onde ele está em [t] (células z21), o rumo em radianos (no plano das células) e se está andando.
  ({double x, double y, double heading, bool walking}) at(double t) {
    var walked = t - startUtc;
    var walking = true;
    for (final (a, b) in _pauses) {
      if (t <= a) continue;
      walked -= math.min(t, b) - a;
      if (t < b) walking = false;
    }
    final total = _len.last;
    if (total <= 0) return (x: path.first.$1, y: path.first.$2, heading: 0, walking: false);
    var d = (walked * walkCellsPerS) % total;
    var i = 1;
    while (i < _len.length - 1 && _len[i] < d) {
      i++;
    }
    final seg = _len[i] - _len[i - 1], u = seg <= 0 ? 0.0 : (d - _len[i - 1]) / seg;
    final (ax, ay) = path[i - 1];
    final (bx, by) = path[i];
    return (x: ax + (bx - ax) * u, y: ay + (by - ay) * u, heading: math.atan2(by - ay, bx - ax), walking: walking);
  }

  /// A sintonia em curso em [t] (a animação), ou `null`.
  VeilTune? tuningAt(double t) {
    for (final s in tunes) {
      if (t >= s.atUtc && t < s.atUtc + animS) return s;
    }
    return null;
  }
}

class VeilbreakerField {
  VeilbreakerField({
    required this.seed,
    required this.modelAt,
    required this.epochAt,
    required this.biomeAt,
    required this.ecosNear,
    required this.mpcAt,
    required this.data,
    this.snapper,
    this.nicknameChance = 0.4,
  });

  final int seed;

  /// O modelo da época vigente em [t] (`null`: a época não tem NPCs) e o id dela.
  final VeilbreakerModel? Function(int t) modelAt;
  final int Function(int t) epochAt;

  /// O bioma de spawn (`urban`, `green`, `lit`...) da célula z21.
  final String Function(int cx, int cy) biomeAt;

  /// Os spawns da camada base (igual para todos) a até [radiusM] de ([x], [y]) (células z21) em [t].
  final List<WorldSpawn> Function(double x, double y, int t, double radiusM) ecosNear;

  /// Metros por célula z21 na linha [y].
  final double Function(double y) mpcAt;
  final NpcData data;
  final PathSnapper? snapper;
  final double nicknameChance;

  final _cache = <(int, int, int), List<Veilbreaker>>{};
  final _knownAnchors = <(int, int), List<(int, KnownNpc, int, int)>>{};

  /// Esquece o que já calculou (o debug trocou o modelo).
  void clear() {
    _cache.clear();
    _knownAnchors.clear();
  }

  static int localHour(int t) => ((t + kVeilLocalOffsetS) ~/ 3600) % 24;
  static int localWeekday(int t) => DateTime.fromMillisecondsSinceEpoch((t + kVeilLocalOffsetS) * 1000, isUtc: true).weekday;

  /// Os NPCs presentes em [t] a até [radiusM] de ([x], [y]) (células z21).
  List<Veilbreaker> around(double x, double y, int t, double radiusM) {
    final m = modelAt(t);
    if (m == null) return const [];
    final slot = t ~/ m.slotS, r = (radiusM / mpcAt(y) / 8).ceil() + 1;
    final cx = (x / 8).floor(), cy = (y / 8).floor();
    return [
      for (var j = cy - r; j <= cy + r; j++)
        for (var i = cx - r; i <= cx + r; i++) ...inCell(i, j, slot, m),
    ];
  }

  /// Quem está na célula z18 ([cx], [cy]) na fatia [slot]: o sorteado (se houver) e os conhecidos com rotina agora.
  List<Veilbreaker> inCell(int cx, int cy, int slot, VeilbreakerModel m) {
    final key = (cx, cy, slot);
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 600) _cache.clear();
    final start = slot * m.slotS, mid = start + m.slotS ~/ 2, epoch = epochAt(mid);
    final out = <Veilbreaker>[];
    final h = fnv1a64([seed, epoch, cx, cy, slot, _saltNpc]);
    final chance = m.baseChance * m.biomeFactor(biomeAt(cx * 8 + 4, cy * 8 + 4)) * m.hourFactor(localHour(mid));
    if (_unit(h) < chance && data.names.isNotEmpty) {
      final h2 = fnv1a64([h, 1]);
      final nick = data.nicknames.isNotEmpty && _unit(fnv1a64([h, 2])) < nicknameChance ? (h2 >>> 40) % data.nicknames.length : -1;
      out.add(_build('npc.$cx.$cy.$slot', null, (h2 >>> 32) % data.names.length, nick, kNpcSchools[(h >>> 20) % 4], (h >>> 24) & 1, cx, cy, slot, h, m));
    }
    final wd = localWeekday(mid), hour = localHour(mid);
    for (final (k, npc, ax, ay) in _knownIn(cx >>> 3, cy >>> 3, m)) {
      if (ax != cx || ay != cy || !npc.activeAt(wd, hour)) continue;
      out.add(_build(npc.id, npc, -1, -1, npc.school, npc.outfit, cx, cy, slot, fnv1a64([seed, epoch, cx, cy, slot, _saltKnown, k]), m));
    }
    return _cache[key] = out;
  }

  /// Os conhecidos do tile z15 ([tx], [ty]): [VeilbreakerModel.knownPerTile] entradas distintas do `npc.json`, cada uma
  /// presa à primeira célula z18 do tile (em ordem sorteada) com o bioma do lugar dela.
  List<(int, KnownNpc, int, int)> _knownIn(int tx, int ty, VeilbreakerModel m) => _knownAnchors.putIfAbsent((tx, ty), () {
        final n = data.known.length;
        if (n == 0) return const [];
        final out = <(int, KnownNpc, int, int)>[];
        final used = <int>{};
        for (var k = 0; k < m.knownPerTile && used.length < n; k++) {
          var idx = (fnv1a64([seed, tx, ty, k, _saltKnown]) >>> 32) % n;
          while (used.contains(idx)) {
            idx = (idx + 1) % n;
          }
          used.add(idx);
          final npc = data.known[idx];
          (int, int)? first, match;
          final order = (fnv1a64([seed, tx, ty, k, 7]) >>> 32) % 64;
          for (var c = 0; c < 64 && match == null; c++) {
            final cell = (order + c * 37) % 64, ax = tx * 8 + cell % 8, ay = ty * 8 + cell ~/ 8;
            first ??= (ax, ay);
            if (biomeAt(ax * 8 + 4, ay * 8 + 4) == npc.biome) match = (ax, ay);
          }
          final (ax, ay) = match ?? first!;
          out.add((k, npc, ax, ay));
        }
        return out;
      });

  Veilbreaker _build(String id, KnownNpc? known, int name, int nick, String school, int outfit, int cx, int cy, int slot, int h, VeilbreakerModel m) {
    final start = slot * m.slotS, end = start + m.slotS;
    // O caminho: três células z20 em fila (de uma das 16 da célula z18, numa das 8 direções), cada ponto levado para a
    // calçada mais perto dentro da célula dele; anda de ida e volta.
    final sx = cx * 4 + (h >>> 8) % 4, sy = cy * 4 + (h >>> 12) % 4;
    const dirs = [(1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1), (0, -1), (1, -1)];
    final (dx, dy) = dirs[(h >>> 16) % 8];
    final pts = <(double, double)>[];
    for (var i = 0; i < 3; i++) {
      final zx = sx + dx * i, zy = sy + dy * i;
      final s = snapper?.snap(zx, zy, 0.5, 0.5, maxDistM: 35);
      final (px, py) = s == null || !s.keep ? (0.5, 0.5) : (s.px, s.py);
      pts.add(((zx + px) * 2, (zy + py) * 2));
    }
    final path = [pts[0], pts[1], pts[2], pts[1], pts[0]];
    final mpc = mpcAt(pts[1].$2);
    // A sintonia: Ecos da camada base perto do meio do caminho cuja janela termina dentro da fatia (com a antecedência).
    final tunes = <VeilTune>[];
    final q = start + m.tuneLeadS.round();
    final idHash = fnv1a64([for (final c in id.codeUnits) c]);
    final cands = [
      for (final e in ecosNear(pts[1].$1, pts[1].$2, q, m.tuneRadiusM))
        if (e.isEco)
          if ((e.window + 1) * windowSeconds - windowOffset(seed, e.cellX, e.cellY) case final end2 when end2 >= q && end2 < end + m.tuneLeadS)
            if (_unit(fnv1a64([seed, e.uid, idHash, _saltTune])) < m.tuneChance) (e, end2 - m.tuneLeadS.round()),
    ]..sort((a, b) => a.$2 != b.$2 ? a.$2.compareTo(b.$2) : a.$1.uid.compareTo(b.$1.uid));
    for (final (e, at) in cands) {
      if (tunes.length >= m.tuneMax) break;
      // Duas sintonias não se sobrepõem: a parada de uma não começa antes de a outra acabar.
      if (tunes.isNotEmpty && at - m.tunePauseS < tunes.last.atUtc + m.tuneAnimS) continue;
      tunes.add(VeilTune(e, at));
    }
    return Veilbreaker._(id: id, known: known, nameIndex: name, nicknameIndex: nick, school: school, outfit: outfit, startUtc: start, endUtc: end, path: path, walkCellsPerS: m.walkMps / mpc, tunes: tunes, pauseS: m.tunePauseS, animS: m.tuneAnimS);
  }

  /// O instante em que [s] foi sintonizado por um NPC (some depois da animação), ou `null`: ninguém o sintoniza. Só Ecos
  /// da camada base; procura nas células z18 em volta, na fatia em que a janela dele fecha.
  int? tunedAt(WorldSpawn s, int t) {
    if (!s.isEco) return null;
    final m = modelAt(t);
    if (m == null) return null;
    final end = (s.window + 1) * windowSeconds - windowOffset(seed, s.cellX, s.cellY);
    final at = end - m.tuneLeadS.round();
    final slot = at ~/ m.slotS, r = (m.tuneRadiusM / mpcAt(s.y) / 8).ceil() + 1;
    final cx = (s.x / 8).floor(), cy = (s.y / 8).floor();
    for (var j = cy - r; j <= cy + r; j++) {
      for (var i = cx - r; i <= cx + r; i++) {
        for (final v in inCell(i, j, slot, m)) {
          for (final tu in v.tunes) {
            if (tu.eco.uid == s.uid) return tu.atUtc;
          }
        }
      }
    }
    return null;
  }

  /// Se [s] já sumiu em [t] (a sintonia e a animação acabaram). [playerDistM]: a distância do jogador até o Eco; perto
  /// dele ([VeilbreakerModel.protectM]), o Eco nunca some.
  bool goneAt(WorldSpawn s, int t, {required double playerDistM}) {
    final m = modelAt(t);
    if (m == null || playerDistM <= m.protectM) return false;
    final at = tunedAt(s, t);
    return at != null && t >= at + m.tuneAnimS;
  }
}
