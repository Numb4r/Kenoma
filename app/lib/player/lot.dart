/// O lote no Véu (0.29.0, GDD rev 402): a casa é um lote em grade, preso à célula da casa, onde o jogador constrói. Aqui
/// ficam as peças (`home.json`, `pieces`), o que está colocado e as regras de encaixe: dentro do lote, sem sobrepor,
/// parede que se liga nas quinas, porta e janela só em parede. Quem tira e põe do Armazém é `crafting/lot_actions.dart`.
/// Dart puro.
library;

/// A camada da peça: o piso cobre a casa; o chão de cima (tapete) fica sobre o piso e se anda por cima; a parede ocupa a
/// casa; porta, janela e quadro entram numa parede; o objeto ocupa as casas e não se atravessa.
enum PieceLayer { floor, flat, wall, attach, object }

/// Como a peça gira: não gira; chão de duas orientações (`_h`/`_v`); duas faces (`_s`/`_l`); quatro (`_s`, `_l`, `_n`, `_o`).
enum PieceTurn { none, floor2, two, four }

class PieceDef {
  const PieceDef({
    required this.item,
    required this.layer,
    required this.sprite,
    required this.tab,
    this.w = 1,
    this.h = 1,
    this.turn = PieceTurn.none,
    this.walk = false,
    this.station,
    this.opens,
    this.light,
    this.effect,
    this.frontOnly = false,
  });

  factory PieceDef.fromJson(Map<String, dynamic> j) => PieceDef(
        item: j['item'] as String,
        layer: PieceLayer.values.byName(j['layer'] as String),
        sprite: j['sprite'] as String,
        tab: j['tab'] as String,
        w: (j['w'] as int?) ?? 1,
        h: (j['h'] as int?) ?? 1,
        turn: PieceTurn.values.byName((j['turn'] as String?) ?? 'none'),
        walk: (j['walk'] as bool?) ?? false,
        station: j['station'] as String?,
        opens: j['opens'] as String?,
        light: j['light'] as String?,
        effect: j['effect'] as String?,
        frontOnly: (j['front_only'] as bool?) ?? false,
      );

  /// O id do item que vira esta peça (Bolsa e Armazém).
  final String item;
  final PieceLayer layer;

  /// O nome base do desenho em `assets/art/ui/lot/`.
  final String sprite;

  /// A aba da paleta do modo construir.
  final String tab;

  /// A pegada em casas, olhando de frente (giro 0).
  final int w, h;
  final PieceTurn turn;

  /// Passa por ela (a porta).
  final bool walk;

  /// A estação da Casa que esta peça é (`forge`...), ou `null`.
  final String? station;

  /// O que tocar abre (`bench`, `storage`), além das estações.
  final String? opens;

  /// A luz de noite (`lamp`, `candle`) ou `null`.
  final String? light;

  /// O efeito da estação trabalhando.
  final String? effect;

  /// O quadro: só em parede com a face para a frente.
  final bool frontOnly;

  bool get turns => turn != PieceTurn.none;

  /// A pegada no giro [rot] (0 frente, 1 lado, 2 costas, 3 o outro lado).
  (int, int) size(int rot) => rot.isOdd && turn != PieceTurn.none ? (h, w) : (w, h);

  /// O sufixo do desenho no giro [rot].
  String spriteFor(int rot) => switch (turn) {
        PieceTurn.none => sprite,
        PieceTurn.floor2 => '${sprite}_${rot.isOdd ? 'v' : 'h'}',
        PieceTurn.two => '${sprite}_${rot.isOdd ? 'l' : 's'}',
        PieceTurn.four => '${sprite}_${const ['s', 'l', 'n', 'o'][rot % 4]}',
      };
}

/// Uma peça colocada: [x], [y] é a casa de cima à esquerda da pegada.
class Placement {
  const Placement({required this.uid, required this.item, required this.x, required this.y, this.rot = 0});

  factory Placement.fromJson(List<dynamic> j) => Placement(uid: j[0] as int, item: j[1] as String, x: j[2] as int, y: j[3] as int, rot: j.length > 4 ? j[4] as int : 0);

  final int uid;
  final String item;
  final int x, y, rot;

  Placement at(int nx, int ny, int nrot) => Placement(uid: uid, item: item, x: nx, y: ny, rot: nrot);

  List<Object> toJson() => [uid, item, x, y, if (rot != 0) rot];
}

/// As casas de uma pegada.
Iterable<(int, int)> footprint(PieceDef d, int x, int y, int rot) sync* {
  final (w, h) = d.size(rot);
  for (var j = 0; j < h; j++) {
    for (var i = 0; i < w; i++) {
      yield (x + i, y + j);
    }
  }
}

/// Por que uma peça não entra, ou `null` se entra.
enum LotMiss { outside, occupied, needsWall, needsStraightWall, needsFrontWall }

/// O lote: o que está colocado e o tamanho. As casas vão de `-size ~/ 2` a `size ~/ 2 - 1` nos dois eixos, então o lote
/// cresce para todos os lados e nada já construído muda de lugar.
class LotState {
  LotState({List<Placement>? placed, this.next = 1, this.sizeBonus = 0, this.started = false}) : placed = placed ?? [];

  factory LotState.fromJson(Map<String, dynamic>? j) => j == null
      ? LotState()
      : LotState(
          placed: [for (final p in (j['p'] as List<dynamic>?) ?? const []) Placement.fromJson(p as List<dynamic>)],
          next: (j['next'] as int?) ?? 1,
          sizeBonus: (j['grow'] as int?) ?? 0,
          started: (j['started'] as bool?) ?? false,
        );

  final List<Placement> placed;
  int next;

  /// O debug cresce o lote além do nível ("crescer o lote"): degraus a mais na escada de tamanhos.
  int sizeBonus;

  /// O lote já recebeu o piso inicial e a Bancada.
  bool started;

  Map<String, dynamic> toJson() => {
        'p': [for (final p in placed) p.toJson()],
        'next': next,
        if (sizeBonus != 0) 'grow': sizeBonus,
        if (started) 'started': true,
      };

  bool get isEmpty => placed.isEmpty && !started;
}

/// A grade lida de um [LotState]: o que há em cada casa, para encaixar, desenhar e andar.
class LotGrid {
  LotGrid(this.state, this.defs, this.size) {
    for (final p in state.placed) {
      final d = defs[p.item];
      if (d == null) continue;
      switch (d.layer) {
        case PieceLayer.floor:
          floor[(p.x, p.y)] = p;
        case PieceLayer.wall:
          wall[(p.x, p.y)] = p;
        case PieceLayer.attach:
          attach[(p.x, p.y)] = p;
        case PieceLayer.flat:
          for (final c in footprint(d, p.x, p.y, p.rot)) {
            flat[c] = p;
          }
        case PieceLayer.object:
          for (final c in footprint(d, p.x, p.y, p.rot)) {
            object[c] = p;
          }
      }
    }
  }

  final LotState state;
  final Map<String, PieceDef> defs;
  final int size;
  final floor = <(int, int), Placement>{};
  final flat = <(int, int), Placement>{};
  final wall = <(int, int), Placement>{};
  final attach = <(int, int), Placement>{};
  final object = <(int, int), Placement>{};

  int get min => -size ~/ 2;
  int get max => size ~/ 2 - 1;
  bool inside(int x, int y) => x >= min && x <= max && y >= min && y <= max;

  /// A máscara da parede em ([x], [y]): N=1, L=2, S=4, O=8 (a vizinha do lado é parede).
  int wallMask(int x, int y) =>
      (wall.containsKey((x, y - 1)) ? 1 : 0) | (wall.containsKey((x + 1, y)) ? 2 : 0) | (wall.containsKey((x, y + 1)) ? 4 : 0) | (wall.containsKey((x - 1, y)) ? 8 : 0);

  /// Dá para andar na casa: dentro, sem parede (a porta passa) e sem objeto.
  bool walkable(int x, int y) {
    if (!inside(x, y) || object.containsKey((x, y))) return false;
    if (!wall.containsKey((x, y))) return true;
    final a = attach[(x, y)];
    return a != null && (defs[a.item]?.walk ?? false);
  }

  /// Por que [d] não entra em ([x], [y]) no giro [rot]. [ignore]: a própria peça, quando ela está sendo movida.
  LotMiss? miss(PieceDef d, int x, int y, int rot, {int? ignore}) {
    final cells = footprint(d, x, y, rot).toList();
    if (cells.any((c) => !inside(c.$1, c.$2))) return LotMiss.outside;
    bool other(Placement? p) => p != null && p.uid != ignore;
    switch (d.layer) {
      case PieceLayer.floor:
        return other(floor[(x, y)]) ? LotMiss.occupied : null;
      case PieceLayer.wall:
        return other(wall[(x, y)]) || other(object[(x, y)]) || other(flat[(x, y)]) ? LotMiss.occupied : null;
      case PieceLayer.attach:
        if (!wall.containsKey((x, y))) return LotMiss.needsWall;
        if (other(attach[(x, y)])) return LotMiss.occupied;
        final m = wallMask(x, y);
        if (d.frontOnly) return m & 4 != 0 ? LotMiss.needsFrontWall : null;
        return m == 10 || m == 5 ? null : LotMiss.needsStraightWall; // trecho reto: L+O (de frente) ou N+S (de lado)
      case PieceLayer.flat:
        return cells.any((c) => other(wall[c]) || other(flat[c])) ? LotMiss.occupied : null;
      case PieceLayer.object:
        return cells.any((c) => other(wall[c]) || other(object[c])) ? LotMiss.occupied : null;
    }
  }

  /// A peça que está em ([x], [y]) para o toque: o que está por cima primeiro (porta/janela, objeto, parede, tapete, piso).
  Placement? topAt(int x, int y) => attach[(x, y)] ?? object[(x, y)] ?? wall[(x, y)] ?? flat[(x, y)] ?? floor[(x, y)];

  /// A estação [id] está colocada no lote.
  bool hasStation(String id) => state.placed.any((p) => defs[p.item]?.station == id);

  /// As casas da frente de [p] (onde a criatura que trabalha fica): a fileira encostada no lado da frente.
  List<(int, int)> frontOf(Placement p) {
    final d = defs[p.item]!;
    final (w, h) = d.size(p.rot);
    return switch (p.rot % 4) {
      0 => [for (var i = 0; i < w; i++) (p.x + i, p.y + h)],
      1 => [for (var j = 0; j < h; j++) (p.x + w, p.y + j)],
      2 => [for (var i = 0; i < w; i++) (p.x + i, p.y - 1)],
      _ => [for (var j = 0; j < h; j++) (p.x - 1, p.y + j)],
    };
  }
}

/// O tamanho do lote no nível [level], com [bonus] degraus a mais (o debug): `lot_sizes` do `balance.json`, pares
/// `[nível, casas]` em ordem.
int lotSizeAt(List<(int, int)> steps, int level, {int bonus = 0}) {
  var i = -1;
  for (var k = 0; k < steps.length; k++) {
    if (level >= steps[k].$1) i = k;
  }
  i = (i + bonus).clamp(0, steps.length - 1);
  return steps[i].$2;
}
