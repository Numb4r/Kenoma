/// Construir no lote (0.29.0, GDD rev 402): pôr uma peça tira o item do Armazém (ou da Bolsa, se o Armazém não tem);
/// mover e girar não gastam nada; retirar devolve ao Armazém (ou à Bolsa, se ele está cheio; se os dois estão, a peça
/// fica). Tirar uma parede devolve junto o que estava nela. Estação colocada ou tirada fecha a conta da produção antes.
/// Dart puro.
library;

import '../data/game_data.dart';
import '../player/game_state.dart';
import '../player/lot.dart';
import 'bag.dart' show acceptable;
import 'home_actions.dart' show storageRoom;
import 'quality.dart';
import 'stations.dart';

enum LotResult { ok, noHome, noneLeft, outside, occupied, needsWall, needsStraightWall, needsFrontWall, storageFull, invalid }

LotResult _ofMiss(LotMiss m) => switch (m) {
      LotMiss.outside => LotResult.outside,
      LotMiss.occupied => LotResult.occupied,
      LotMiss.needsWall => LotResult.needsWall,
      LotMiss.needsStraightWall => LotResult.needsStraightWall,
      LotMiss.needsFrontWall => LotResult.needsFrontWall,
    };

/// O tamanho do lote agora (o nível do jogador e o que o debug cresceu).
int lotSize(GameState s) => lotSizeAt(s.balance.home.lotSizes, s.playerLevel, bonus: s.home.lot.sizeBonus);

/// A grade do lote agora.
LotGrid lotGrid(GameState s, GameData data) => LotGrid(s.home.lot, data.home.pieces, lotSize(s));

/// Quantas peças [item] há para pôr: Armazém e Bolsa, todas as qualidades.
int piecesLeft(GameState s, String item) => [for (final k in stackKeys(item)) s.home.storage[k] ?? 0].fold(0, (a, b) => a + b) + s.count(item);

bool _takeOne(GameState s, String item) {
  for (final k in stackKeys(item)) {
    final n = s.home.storage[k] ?? 0;
    if (n <= 0) continue;
    if (n == 1) {
      s.home.storage.remove(k);
    } else {
      s.home.storage[k] = n - 1;
    }
    return true;
  }
  return s.take(item);
}

/// Devolve uma peça: Armazém, senão Bolsa. `false` se nenhum dos dois tem lugar.
bool _giveBack(GameState s, GameData data, String item) {
  if (storageRoom(s, data, item, 1) >= 1) {
    s.home.storage[item] = (s.home.storage[item] ?? 0) + 1;
    return true;
  }
  return s.add(item, 1) == 1;
}

/// Fecha a conta da estação que [item] é (se é uma), antes de ela entrar ou sair do lote.
void _settleStation(GameState s, GameData data, String item, int now) {
  final id = data.home.pieces[item]?.station;
  final def = id == null ? null : data.home.station(id);
  if (def != null) settle(s, data, def, s.home.station(def.id), now);
}

/// Põe [item] em ([x], [y]) no giro [rot].
LotResult placePiece(GameState s, GameData data, String item, int x, int y, int rot, int now) {
  if (s.home.cell == null) return LotResult.noHome;
  final d = data.home.pieces[item];
  if (d == null) return LotResult.invalid;
  final r = d.turns ? rot % 4 : 0;
  final miss = lotGrid(s, data).miss(d, x, y, r);
  if (miss != null) return _ofMiss(miss);
  if (piecesLeft(s, item) <= 0) return LotResult.noneLeft;
  _settleStation(s, data, item, now);
  _takeOne(s, item);
  final lot = s.home.lot;
  lot.placed.add(Placement(uid: lot.next++, item: item, x: x, y: y, rot: r));
  s.changed();
  return LotResult.ok;
}

/// Leva a peça [uid] para ([x], [y]) no giro [rot] (girar é mover para o mesmo lugar).
LotResult movePiece(GameState s, GameData data, int uid, int x, int y, int rot) {
  final lot = s.home.lot;
  final i = lot.placed.indexWhere((p) => p.uid == uid);
  if (i < 0) return LotResult.invalid;
  final p = lot.placed[i], d = data.home.pieces[p.item];
  if (d == null) return LotResult.invalid;
  final r = d.turns ? rot % 4 : 0;
  final grid = lotGrid(s, data);
  // O que está preso numa parede vai junto com ela.
  final riders = d.layer == PieceLayer.wall ? [for (final q in lot.placed) if (data.home.pieces[q.item]?.layer == PieceLayer.attach && q.x == p.x && q.y == p.y) q] : const <Placement>[];
  final miss = grid.miss(d, x, y, r, ignore: uid);
  if (miss != null) return _ofMiss(miss);
  lot.placed[i] = p.at(x, y, r);
  for (final q in riders) {
    lot.placed[lot.placed.indexWhere((o) => o.uid == q.uid)] = q.at(x, y, q.rot);
  }
  s.changed();
  return LotResult.ok;
}

/// Retira a peça [uid] e o que estava preso nela. Devolve os itens que voltaram (para o aviso).
({LotResult result, List<String> back}) removePiece(GameState s, GameData data, int uid, int now) {
  final lot = s.home.lot;
  final p = lot.placed.where((q) => q.uid == uid).firstOrNull;
  if (p == null) return (result: LotResult.invalid, back: const []);
  final d = data.home.pieces[p.item];
  final going = [
    p,
    if (d?.layer == PieceLayer.wall)
      for (final q in lot.placed)
        if (q.uid != uid && data.home.pieces[q.item]?.layer == PieceLayer.attach && q.x == p.x && q.y == p.y) q,
  ];
  // Cabe tudo de volta (Armazém ou Bolsa)? Confere antes de mexer, para nunca perder peça.
  final room = <String, int>{};
  for (final q in going) {
    room[q.item] = (room[q.item] ?? 0) + 1;
  }
  for (final e in room.entries) {
    if (storageRoom(s, data, e.key, e.value) + acceptable(s, data.craft, now, e.key, e.value) < e.value) return (result: LotResult.storageFull, back: const []);
  }
  _settleStation(s, data, p.item, now);
  final back = <String>[];
  for (final q in going) {
    if (!_giveBack(s, data, q.item)) return (result: LotResult.storageFull, back: back);
    lot.placed.removeWhere((o) => o.uid == q.uid);
    back.add(q.item);
  }
  s.changed();
  return (result: LotResult.ok, back: back);
}
