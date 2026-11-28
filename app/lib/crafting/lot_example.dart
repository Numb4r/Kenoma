/// A casa de exemplo do debug (0.29.0): limpa o lote e monta uma casa de um cômodo com piso, paredes, porta, duas janelas,
/// quadro, luzes, tapete, mesa e vaso, quatro estações dentro, a Horta e a Fábrica de selos fora, e os móveis do Armazém.
/// As peças que faltarem são dadas antes. Serve para as capturas e para ver o lote cheio. Dart puro.
library;

import '../data/game_data.dart';
import '../player/game_state.dart';
import 'lot_actions.dart';

/// Monta a casa num lote de 16 × 16 (casas de -8 a 7). Devolve quantas peças entraram.
int buildExampleHouse(GameState s, GameData data, int now) {
  final lot = s.home.lot;
  // Tudo o que estava colocado volta para o Armazém sem passar pelo limite: é o debug.
  for (final p in lot.placed) {
    s.home.storage[p.item] = (s.home.storage[p.item] ?? 0) + 1;
  }
  lot.placed.clear();
  lot.started = true;
  final plan = <(String, int, int, int)>[
    for (var y = -6; y <= -1; y++)
      for (var x = -6; x <= 5; x++) (x < 2 ? 'item.lot.floor_plank' : 'item.lot.floor_tile', x, y, 0),
    for (var x = -7; x <= 6; x++) ('item.lot.wall', x, -7, 0),
    for (var x = -7; x <= 6; x++) ('item.lot.wall', x, 0, 0),
    for (var y = -6; y <= -1; y++) ('item.lot.wall', -7, y, 0),
    for (var y = -6; y <= -1; y++) ('item.lot.wall', 6, y, 0),
    ('item.lot.door', -3, 0, 0),
    ('item.lot.window', -5, -7, 0),
    ('item.lot.window', 3, -7, 0),
    ('item.lot.picture', 0, -7, 0),
    ('item.station.forge', -6, -6, 0),
    ('item.station.still', -3, -6, 0),
    ('item.station.cellar', 0, -6, 0),
    ('item.station.archive', 3, -6, 0),
    ('item.station.workbench', -6, -2, 0),
    ('item.lot.rug', -2, -3, 0),
    ('item.lot.table', 2, -2, 0),
    ('item.lot.lamp', 5, -3, 0),
    ('item.lot.candle', 1, -1, 0),
    ('item.lot.vase', 5, -1, 0),
    ('item.station.garden', -6, 2, 0),
    ('item.station.sealworks', -2, 2, 0),
    ('item.furniture.chest', 2, 2, 0),
    ('item.furniture.shelf', 3, 2, 0),
    ('item.furniture.sanctum', 6, 2, 0),
  ];
  final need = <String, int>{};
  for (final (item, _, _, _) in plan) {
    need[item] = (need[item] ?? 0) + 1;
  }
  for (final e in need.entries) {
    final missing = e.value - piecesLeft(s, e.key);
    if (missing > 0) s.home.storage[e.key] = (s.home.storage[e.key] ?? 0) + missing;
  }
  var n = 0;
  for (final (item, x, y, rot) in plan) {
    if (placePiece(s, data, item, x, y, rot, now) == LotResult.ok) n++;
  }
  s.changed();
  return n;
}
