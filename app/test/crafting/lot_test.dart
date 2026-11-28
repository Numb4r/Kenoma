import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/crafting/home_actions.dart';
import 'package:kenoma/crafting/lot_actions.dart';
import 'package:kenoma/crafting/lot_example.dart';
import 'package:kenoma/crafting/stations.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/home.dart';
import 'package:kenoma/save/backup.dart';
import 'package:kenoma/save/ksv1.dart';
import 'package:kenoma/save/migrations.dart';
import 'package:kenoma/world/lot_path.dart';

import '../support/fixtures.dart';

/// 0.29.0: o lote no Véu, num mundo fixo (a casa no Cambuí, relógio fixo).
void main() {
  final data = loadGameData();
  const t0 = 1796000000, h = 3600;
  const home = (lat: -22.8936, lon: -47.0536);
  final cell = latLonToTile(home.lat, home.lon, biomeZoom);

  GameState housed({int level = 10}) {
    final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress)
      ..levelOverride = level
      ..home.cell = cell
      ..home.setUtc = t0;
    s.collection.add(const CreatureInstance(uid: 'e1', speciesId: 'frond.eco', level: 1, capturedUtc: t0));
    ensureLotStarted(s, data);
    return s;
  }

  void give(GameState s, String item, int n) => s.home.storage[item] = (s.home.storage[item] ?? 0) + n;

  test('o lote: 16 casas no começo, 24 no nível 20 e 32 no 30; já vem com piso e a Bancada, e as estações no Armazém', () {
    expect(lotSize(housed()), 16);
    expect(lotSize(housed(level: 20)), 24);
    expect(lotSize(housed(level: 30)), 32);
    final s = housed();
    final g = lotGrid(s, data);
    expect(g.floor.length, 16, reason: 'piso de 4 × 4');
    expect(s.home.lot.placed.where((p) => data.home.pieces[p.item]?.opens == 'bench'), hasLength(1));
    for (final def in data.home.stations) {
      expect(s.home.storage[data.home.pieceOfStation(def.id)!.item], 1, reason: def.id);
    }
    ensureLotStarted(s, data);
    expect(s.home.lot.placed.length, 17, reason: 'uma vez só');
  });

  test('a porta só abre a menos de 40 m da casa', () {
    final s = housed();
    final mpc = metersPerCell(home.lat);
    final c = s.home.center!;
    expect(canEnterLot(s, c.$1 + 39 / mpc, c.$2), isTrue);
    expect(canEnterLot(s, c.$1 + 41 / mpc, c.$2), isFalse);
    expect(canEnterLot(GameState(groupCode: 'KENOMA-TESTE', balance: data.progress), c.$1, c.$2), isFalse, reason: 'sem casa, sem porta');
  });

  test('a grade não deixa peças se sobreporem, nem saírem do lote', () {
    final s = housed();
    give(s, 'item.lot.table', 2);
    give(s, 'item.lot.vase', 1);
    expect(placePiece(s, data, 'item.lot.table', 3, 3, 0, t0), LotResult.ok);
    expect(placePiece(s, data, 'item.lot.table', 4, 3, 0, t0), LotResult.occupied);
    expect(placePiece(s, data, 'item.lot.vase', 4, 3, 0, t0), LotResult.occupied);
    expect(placePiece(s, data, 'item.lot.table', 7, 5, 0, t0), LotResult.outside, reason: 'a mesa de 2 passaria da borda');
    expect(placePiece(s, data, 'item.lot.table', 4, 4, 1, t0), LotResult.ok, reason: 'girada, ocupa 1 × 2');
    expect(lotGrid(s, data).object.keys.toSet(), containsAll({(3, 3), (4, 3), (4, 4), (4, 5)}));
    expect(placePiece(s, data, 'item.lot.vase', 3, 3, 0, t0), LotResult.occupied);
    expect(s.home.storage['item.lot.vase'], 1, reason: 'o que não entrou não sai do Armazém');
  });

  test('paredes se ligam nas quinas, e porta e janela só entram em trecho reto de parede', () {
    final s = housed();
    give(s, 'item.lot.wall', 5);
    give(s, 'item.lot.door', 2);
    for (final (x, y) in [(-6, -6), (-5, -6), (-4, -6), (-6, -5), (-6, -4)]) {
      expect(placePiece(s, data, 'item.lot.wall', x, y, 0, t0), LotResult.ok);
    }
    final g = lotGrid(s, data);
    expect(g.wallMask(-6, -6), 2 | 4, reason: 'a quina liga para o leste e para o sul');
    expect(g.wallMask(-5, -6), 2 | 8);
    expect(g.wallMask(-6, -5), 1 | 4);
    expect(g.wallMask(-4, -6), 8);
    expect(placePiece(s, data, 'item.lot.door', 0, 0, 0, t0), LotResult.needsWall);
    expect(placePiece(s, data, 'item.lot.door', -6, -6, 0, t0), LotResult.needsStraightWall, reason: 'na quina, não');
    expect(placePiece(s, data, 'item.lot.door', -5, -6, 0, t0), LotResult.ok);
    expect(lotGrid(s, data).walkable(-5, -6), isTrue, reason: 'pela porta se passa');
    expect(lotGrid(s, data).walkable(-4, -6), isFalse);
  });

  test('estação fora do lote não produz; colocada, produz', () {
    final s = housed();
    final garden = data.home.station('garden')!;
    expect(assign(s, data, home, 'garden', 'e1', t0), HomeResult.ok);
    var v = stationView(s, data, garden, t0 + 9 * h);
    expect((v.placed, v.ready), (false, 0));
    expect(collect(s, data, home, 'garden', t0 + 9 * h), HomeResult.ok);
    expect(s.home.storage['item.herbs'], isNull);
    expect(placePiece(s, data, 'item.station.garden', 3, 0, 0, t0 + 9 * h), LotResult.ok);
    v = stationView(s, data, garden, t0 + 15 * h);
    expect((v.placed, v.ready), (true, 2), reason: 'conta de quando entrou no lote');
    final uid = s.home.lot.placed.firstWhere((p) => p.item == 'item.station.garden').uid;
    expect(removePiece(s, data, uid, t0 + 15 * h).result, LotResult.ok);
    expect(stationView(s, data, garden, t0 + 30 * h).ready, 2, reason: 'tirada, para; o que fez fica no depósito');
  });

  test('retirar devolve ao Armazém (e a parede leva junto o que estava nela); mover e girar não gastam peça', () {
    final s = housed();
    give(s, 'item.lot.wall', 3);
    give(s, 'item.lot.window', 1);
    give(s, 'item.lot.lamp', 1);
    for (final x in [0, 1, 2]) {
      placePiece(s, data, 'item.lot.wall', x, -6, 0, t0);
    }
    expect(placePiece(s, data, 'item.lot.window', 1, -6, 0, t0), LotResult.ok);
    final wall = s.home.lot.placed.firstWhere((p) => p.item == 'item.lot.wall' && p.x == 1).uid;
    final r = removePiece(s, data, wall, t0);
    expect(r.result, LotResult.ok);
    expect(r.back, ['item.lot.wall', 'item.lot.window']);
    expect((s.home.storage['item.lot.wall'], s.home.storage['item.lot.window']), (1, 1));
    expect(placePiece(s, data, 'item.lot.lamp', 4, 4, 0, t0), LotResult.ok);
    final lamp = s.home.lot.placed.firstWhere((p) => p.item == 'item.lot.lamp').uid;
    expect(movePiece(s, data, lamp, 5, 5, 0), LotResult.ok);
    expect(piecesLeft(s, 'item.lot.lamp'), 0);
    expect(removePiece(s, data, lamp, t0).result, LotResult.ok);
    expect(s.home.storage['item.lot.lamp'], 1);
  });

  test('o caminho contorna paredes e objetos, sem cortar quina', () {
    final s = housed();
    give(s, 'item.lot.wall', 9);
    for (var y = -4; y <= 4; y++) {
      if (y != 4) placePiece(s, data, 'item.lot.wall', 0, y, 0, t0);
    }
    final g = lotGrid(s, data);
    final path = lotPath((-2, 0), (2, 0), g.walkable)!;
    expect(path.first, (-2, 0));
    expect(path.last, (2, 0));
    expect(path.every((c) => g.walkable(c.$1, c.$2)), isTrue);
    expect(path, contains((0, 4)), reason: 'só passa pela abertura de baixo');
    for (var i = 1; i < path.length; i++) {
      final (ax, ay) = path[i - 1];
      final (bx, by) = path[i];
      if (ax != bx && ay != by) expect(g.walkable(bx, ay) && g.walkable(ax, by), isTrue, reason: 'diagonal sem quina');
    }
    expect(lotPath((-2, 0), (0, 0), g.walkable), isNull, reason: 'parede não é destino');
  });

  test('o lote salva e volta igual depois de fechar o app; a privacidade do backup e do QR continua', () {
    final s = housed();
    expect(buildExampleHouse(s, data, t0), greaterThan(100));
    final json = s.toJson(t0);
    final back = GameState.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>, data.progress);
    expect(jsonEncode(back.home.lot.toJson()), jsonEncode(s.home.lot.toJson()));
    expect(back.home.cell, cell);
    final backup = decodeKsv(exportBackup(json));
    expect(backup.containsKey(kHomeCellKey), isFalse);
    final text = jsonEncode(backup);
    expect(text, isNot(contains('${cell.$1}')));
    expect(text, isNot(contains('${cell.$2}')));
    expect(jsonEncode(GameState.fromJson(backup, data.progress).home.lot.toJson()), jsonEncode(s.home.lot.toJson()), reason: 'o lote vai no backup; só o lugar não');
    expect(groupQrPayload(s.groupCode), 'kenoma:group:${normalizeSeedCode(s.groupCode)}');
  });

  test('a casa de exemplo cabe inteira, com as seis estações e a Bancada', () {
    final s = housed();
    final n = buildExampleHouse(s, data, t0);
    final g = lotGrid(s, data);
    for (final def in data.home.stations) {
      expect(g.hasStation(def.id), isTrue, reason: def.id);
    }
    expect(n, s.home.lot.placed.length, reason: 'nenhuma peça recusada');
    expect(g.attach.values.map((p) => p.item).toSet(), {'item.lot.door', 'item.lot.window', 'item.lot.picture'});
    expect(lotPath((-3, 1), (-3, -1), g.walkable), isNotNull, reason: 'entra pela porta');
  });

  test('v16 vira v17: os móveis instalados da 0.28.0 voltam para o Armazém', () {
    final v16 = {
      'schema_version': 16,
      'group_code': 'KENOMA-TESTE',
      'home': {'set_utc': t0, 'storage': {'item.chalk': 2}, 'furniture': {'item.furniture.shelf': 2, 'item.furniture.sanctum': 1}},
      kHomeCellKey: [cell.$1, cell.$2],
    };
    final out = migrateSave(v16);
    expect(out['schema_version'], 17);
    expect((out['home'] as Map)['storage'], {'item.chalk': 2, 'item.furniture.shelf': 2, 'item.furniture.sanctum': 1});
    expect((out['home'] as Map).containsKey('furniture'), isFalse);
    final s = GameState.fromJson(out, data.progress);
    expect(storageCap(s, data), 40, reason: 'até colocar no lote, não amplia');
  });
}
