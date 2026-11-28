import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/seed.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/crafting/home_actions.dart';
import 'package:kenoma/crafting/lot_actions.dart';
import 'package:kenoma/crafting/quality.dart';
import 'package:kenoma/crafting/stations.dart';
import 'package:kenoma/player/bestiary.dart';
import 'package:kenoma/player/game_state.dart';
import 'package:kenoma/player/home.dart';
import 'package:kenoma/save/backup.dart';
import 'package:kenoma/save/ksv1.dart';

import '../support/fixtures.dart';

/// 0.28.0: a Casa num mundo fixo: o lugar (Cambuí), o relógio e as criaturas de teste.
void main() {
  final data = loadGameData();
  final b = data.progress.home;
  const t0 = 1796000000;
  const home = (lat: -22.8936, lon: -47.0536);
  final cell = latLonToTile(home.lat, home.lon, biomeZoom);
  const far = (lat: -22.9056, lon: -47.0608); // o Centro, ~1,5 km
  const h = 3600;

  GameState make({int level = 10}) {
    final s = GameState(groupCode: 'KENOMA-TESTE', balance: data.progress)..levelOverride = level;
    s.collection.addAll(const [
      CreatureInstance(uid: 'e1', speciesId: 'frond.eco', level: 1, capturedUtc: t0),
      CreatureInstance(uid: 'e21', speciesId: 'frond.eco', level: 21, capturedUtc: t0),
      CreatureInstance(uid: 'sp', speciesId: 'frond.spirit', level: 1, capturedUtc: t0),
      CreatureInstance(uid: 'ri', speciesId: 'frond.ritual', level: 1, capturedUtc: t0),
      CreatureInstance(uid: 'mj', speciesId: 'frond.major', level: 1, capturedUtc: t0),
      CreatureInstance(uid: 'shy', speciesId: 'frond.eco', level: 1, capturedUtc: t0, shiny: true),
      CreatureInstance(uid: 'urb', speciesId: 'frond.eco', level: 1, capturedUtc: t0, variant: 'urban'),
      CreatureInstance(uid: 'soot', speciesId: 'soot.eco', level: 1, capturedUtc: t0),
      CreatureInstance(uid: 'sh', speciesId: 'shade.eco', level: 1, capturedUtc: t0),
      CreatureInstance(uid: 'rust', speciesId: 'rust.eco', level: 1, capturedUtc: t0),
      CreatureInstance(uid: 'wisp', speciesId: 'wisp.eco', level: 1, capturedUtc: t0),
    ]);
    return s;
  }

  /// Com casa e as seis estações colocadas no lote (0.29.0: fora do lote, estação não produz).
  GameState housed({int level = 10}) {
    final s = make(level: level)
      ..home.cell = cell
      ..home.setUtc = t0;
    ensureLotStarted(s, data);
    for (final (i, def) in data.home.stations.indexed) {
      expect(placePiece(s, data, data.home.pieceOfStation(def.id)!.item, -8 + 3 * (i % 5), 2 + 4 * (i ~/ 5), 0, t0), LotResult.ok, reason: def.id);
    }
    return s;
  }

  test('os números da Casa vêm do balance.json', () {
    expect((b.unlockLevel, b.moveCooldownS, b.radiusM, b.storageItems, b.storageCreatures), (10, 30 * 86400, 40.0, 40, 20));
    expect(b.slotLevels, [10, 15, 20]);
    expect([for (final id in ['frond.eco', 'frond.spirit', 'frond.ritual', 'frond.major']) b.periodOf(id, 1)], [3 * h, 2 * h, 5400, h]);
    expect(b.periodOf('frond.archetype', 1), isNull, reason: 'o Arquétipo não trabalha');
    expect(b.periodOf('frond.eco', 21), (3 * h / 1.2).round(), reason: '1% por nível');
    expect([for (final s in data.home.stations) '${s.id}:${s.family}'], ['forge:soot', 'garden:frond', 'still:rill', 'cellar:shade', 'archive:wisp', 'sealworks:rust']);
    expect(data.phone.apps.firstWhere((a) => a.id == 'home').unlockLevel, 10, reason: 'o app Casa abre no 10');
  });

  test('a casa só abre no nível 10, na célula de quem está lá, e trocar espera 30 dias', () {
    final s = make(level: 9);
    expect(setHome(s, cell, t0), HomeResult.locked);
    expect(s.home.cell, isNull);
    s.levelOverride = 10;
    expect(setHome(s, cell, t0), HomeResult.ok);
    expect((s.home.cell, s.story.count('home_set')), (cell, 1));
    expect(atHome(s, home), isTrue);
    expect(atHome(s, far), isFalse);
    expect(setHome(s, (cell.$1 + 9, cell.$2), t0 + 29 * 86400), HomeResult.cooldown);
    expect(cooldownLeftS(s, t0 + 29 * 86400), 86400);
    expect(setHome(s, (cell.$1 + 9, cell.$2), t0 - 86400), HomeResult.cooldown, reason: 'relógio para trás não encurta a espera');
    expect(setHome(s, (cell.$1 + 9, cell.$2), t0 + 30 * 86400), HomeResult.ok);
  });

  test('fora do raio, nada muda: o app só mostra o estado', () {
    final s = housed()..inventory['item.chalk'] = 5;
    expect(assign(s, data, home, 'garden', 'e1', t0), HomeResult.ok);
    final before = jsonEncode(s.toJson(t0));
    final results = [
      storeItem(s, data, far, 'item.chalk', 1),
      takeItem(s, far, 'item.chalk', 1),
      storeCreature(s, data, far, 'e21'),
      assign(s, data, far, 'garden', 'e21', t0 + h),
      unassign(s, data, far, 'garden', 'e1', t0 + h),
      collect(s, data, far, 'garden', t0 + 9 * h),
      choose(s, data, far, 'forge', null, t0 + h),
      storeItem(s, data, null, 'item.chalk', 1),
    ];
    expect(results.toSet(), {HomeResult.away});
    expect(jsonEncode(s.toJson(t0)), before);
    expect(stationView(s, data, data.home.station('garden')!, t0 + 9 * h).ready, 3, reason: 'mas a tela mostra o que a horta já fez');
  });

  test('a produção segue o ritmo de cada camada e para no depósito cheio', () {
    final s = housed(level: 20);
    final garden = data.home.station('garden')!;
    for (final uid in ['e1', 'sp', 'mj']) {
      expect(assign(s, data, home, 'garden', uid, t0), HomeResult.ok);
    }
    // 6 h: o Eco fez 2, o Espírito 3, a Entidade 6.
    var v = stationView(s, data, garden, t0 + 6 * h);
    expect(v.ready, 11);
    // O depósito: 24 h de produção (8 + 12 + 24).
    expect(v.cap, 44);
    expect(v.fullAtUtc, isNotNull);
    v = stationView(s, data, garden, t0 + 30 * 24 * h);
    expect((v.ready, v.full), (44, true), reason: 'cheio, ela para');
    expect(collect(s, data, home, 'garden', t0 + 30 * 24 * h), HomeResult.ok);
    expect(s.home.storage['item.herbs'], 44);
    expect(stationView(s, data, garden, t0 + 30 * 24 * h + 59 * 60).ready, 0, reason: 'parada, volta a contar do recolhimento');
    expect(stationView(s, data, garden, t0 + 30 * 24 * h + h).ready, 1);
  });

  test('a criatura de ritual faz uma peça a cada 1h30, e o nível acelera', () {
    final s = housed();
    assign(s, data, home, 'garden', 'ri', t0);
    expect(stationView(s, data, data.home.station('garden')!, t0 + 3 * h).ready, 2);
    final t = housed();
    assign(t, data, home, 'garden', 'e21', t0);
    expect(stationView(t, data, data.home.station('garden')!, t0 + 9000).ready, 1, reason: 'nível 21: 3 h / 1,2');
  });

  test('relógio voltando para trás não produz', () {
    final s = housed();
    final garden = data.home.station('garden')!;
    assign(s, data, home, 'garden', 'e1', t0 + 10 * h);
    expect(stationView(s, data, garden, t0).ready, 0);
    expect(stationView(s, data, garden, t0 + 10 * h - 1).ready, 0);
    expect(collect(s, data, home, 'garden', t0), HomeResult.ok);
    expect(s.home.storage, isEmpty);
    expect(s.home.stations['garden']!.since['e1'], t0 + 10 * h, reason: 'o relógio de volta não mexe no ponto de partida');
    expect(stationView(s, data, garden, t0 + 13 * h).ready, 1);
  });

  test('quem trabalha sai do Círculo e não entra de novo; não pode ser fundido nem destilado', () {
    final s = housed()..circle.add('e1');
    expect(assign(s, data, home, 'garden', 'e1', t0), HomeResult.ok);
    expect(s.circle, isNot(contains('e1')));
    expect(s.toggleCircle('e1'), isFalse);
    expect(s.removeCreature('e1'), isFalse);
    expect(assign(s, data, home, 'garden', 'soot', t0), HomeResult.invalid, reason: 'só a família da estação');
    expect(assign(s, data, home, 'garden', 'e21', t0), HomeResult.slotsFull, reason: 'uma vaga no nível 10');
    expect(retrieveCreature(s, data, home, 'e1', t0 + h), HomeResult.ok);
    expect(s.toggleCircle('e1'), isTrue);
  });

  test('os traços mudam a qualidade: Brilhante perfeita, variante boa', () {
    final s = housed(level: 20);
    for (final uid in ['shy', 'urb', 'e1']) {
      assign(s, data, home, 'garden', uid, t0);
    }
    collect(s, data, home, 'garden', t0 + 3 * h);
    expect({for (final q in Quality.values) q: s.home.storage[stackKey('item.herbs', q)] ?? 0}, {Quality.common: 1, Quality.good: 1, Quality.perfect: 1});
  });

  test('Forja, Adega, Fábrica de selos e Arquivo: carga do Armazém, qualidade da Essência e pesquisa', () {
    final s = housed()
      ..home.storage.addAll({'item.chalk': 20, 'item.ectoplasm': 4, 'item.essence.shadow': 3})
      ..crafting.known.add('recipe.refine.quicklime');
    expect(stationChoices(s, data, data.home.station('forge')!), ['recipe.refine.quicklime']);
    expect(assign(s, data, home, 'forge', 'soot', t0), HomeResult.ok);
    expect(choose(s, data, home, 'forge', 'recipe.refine.quicklime', t0), HomeResult.ok);
    expect(s.home.storage['item.chalk'], 4, reason: 'carga para o depósito inteiro: 8 peças de 2 Giz');
    collect(s, data, home, 'forge', t0 + 6 * h);
    expect(s.home.storage['item.ref.quicklime'], 2);

    expect(assign(s, data, home, 'cellar', 'sh', t0), HomeResult.ok);
    expect(choose(s, data, home, 'cellar', 'item.essence.shadow', t0), HomeResult.ok);
    collect(s, data, home, 'cellar', t0 + 24 * h);
    expect((s.home.storage['item.essence.shadow'], s.home.storage['item.essence.shadow@good']), (null, 3), reason: 'só envelhece o que entrou');

    expect(stationChoices(s, data, data.home.station('sealworks')!), contains('recipe.seal.simple'));
    expect(s.home.storage['item.chalk'], isNull, reason: 'recolher recarrega a Forja com o resto do Giz');
    s.home.storage['item.chalk'] = 4;
    expect(assign(s, data, home, 'sealworks', 'rust', t0), HomeResult.ok);
    expect(choose(s, data, home, 'sealworks', 'recipe.seal.simple', t0), HomeResult.ok);
    expect(s.home.stations['sealworks']!.load, {'item.chalk': 4, 'item.ectoplasm': 4});
    expect(collect(s, data, home, 'sealworks', t0 + 9 * h), HomeResult.ok);
    expect(s.home.storage['item.seal.simple'], 3, reason: 'Giz e Ectoplasma para 4; em 9 h saem 3');

    s.bestiary['soot.eco'] = const BestiaryEntry(seen: true);
    assign(s, data, home, 'archive', 'wisp', t0);
    choose(s, data, home, 'archive', 'soot.eco', t0);
    expect(researchLevelOf(s, data, 'soot.eco'), 0);
    collect(s, data, home, 'archive', t0 + 24 * h);
    expect((researchLevelOf(s, data, 'soot.eco'), s.bestiary['soot.eco']!.archived), (2, 2), reason: '8 pontos, 4 por tarefa');
  });

  test('o Armazém tem 40 espaços de item e 20 de criatura; a estante e o santuário colocados no lote ampliam, e saem', () {
    final s = housed()..inventory.addAll({'item.furniture.shelf': 1, 'item.furniture.sanctum': 1});
    expect((storageCap(s, data), sanctumCap(s, data)), (40, 20));
    expect(placePiece(s, data, 'item.furniture.shelf', -8, -8, 0, t0), LotResult.ok);
    expect(placePiece(s, data, 'item.furniture.sanctum', -5, -8, 0, t0), LotResult.ok);
    expect((storageCap(s, data), sanctumCap(s, data)), (60, 30));
    final shelf = s.home.lot.placed.firstWhere((p) => p.item == 'item.furniture.shelf').uid;
    expect(removePiece(s, data, shelf, t0).result, LotResult.ok);
    expect((storageCap(s, data), s.home.storage['item.furniture.shelf']), (40, 1), reason: 'móvel agora sai e volta ao Armazém');
    s.inventory['item.chalk'] = 5;
    expect(storeItem(s, data, home, 'item.chalk', 5), HomeResult.ok);
    expect((s.count('item.chalk'), s.home.storage['item.chalk']), (0, 5));
    expect(takeItem(s, home, 'item.chalk', 2), HomeResult.ok);
    expect((s.count('item.chalk'), s.home.storage['item.chalk']), (2, 3));
    expect(storeCreature(s, data, home, 'e21'), HomeResult.ok);
    expect(s.toggleCircle('e21'), isFalse, reason: 'guardada em casa');
  });

  test('privacidade: a célula da casa fica no save do aparelho, nunca no backup nem no QR', () {
    final s = housed();
    final json = s.toJson(t0);
    expect(json[kHomeCellKey], [cell.$1, cell.$2]);
    expect(GameState.fromJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>, data.progress).home.cell, cell);
    final backup = decodeKsv(exportBackup(json));
    expect(backup.containsKey(kHomeCellKey), isFalse);
    final text = jsonEncode(backup);
    expect(text, isNot(contains('${cell.$1}')));
    expect(text, isNot(contains('${cell.$2}')));
    expect(GameState.fromJson(backup, data.progress).home.cell, isNull, reason: 'restaurado, a casa volta sem lugar');
    final qr = groupQrPayload(s.groupCode);
    expect(qr, isNot(contains('${cell.$1}')));
    expect(qr, 'kenoma:group:${normalizeSeedCode(s.groupCode)}');
  });
}
