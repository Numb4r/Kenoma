import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/player/game_session.dart';
import 'package:kenoma/save/founder.dart';
import 'package:kenoma/save/fresh_start.dart';
import 'package:kenoma/save/ksv1.dart';
import 'package:kenoma/save/ksv_save_store.dart';
import 'package:kenoma/world/device_sensors.dart';

import '../support/fixtures.dart';

/// Recomeçar do zero num disco de verdade (pasta temporária): o save real da 0.15.0 com progresso, o rodízio cheio,
/// sobras do formato antigo, o diário da Patrulha e os caches.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final real = jsonDecode(File('test/fixtures/save_v5_0150.json').readAsStringSync()) as Map<String, dynamic>;
  const start = {'item.seal.simple': 5, 'item.chalk': 3};
  const t0 = 1793000000;
  late Directory root, docs, support, temp;
  late List<String> systemCalls;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('kenoma-fresh');
    docs = await Directory('${root.path}/docs').create();
    support = await Directory('${root.path}/support').create();
    temp = await Directory('${root.path}/temp').create();
    systemCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('kenoma/system'), (call) async {
      systemCalls.add(call.method);
      return true;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('kenoma/system'), null);
    await root.delete(recursive: true);
  });

  Future<GameSession> open(KsvSaveStore store, {int t = t0}) =>
      GameSession.open(store: store, startInventory: start, balance: loadProgressBalance(), nowUtc: () => t, nextInt: (n) => 7, appVersion: '0.16.0+25');

  Set<String> names(Directory d) => {for (final e in d.listSync()) e.uri.pathSegments.lastWhere((s) => s.isNotEmpty)};

  test('apaga o progresso e o rodízio, mantém player_id, log, certificados, Ajustes e grupo; pede backup e encerra a Patrulha', () async {
    final store = KsvSaveStore(docs);
    await store.write(real);
    final session = await open(store);
    session.state
      ..add('item.chalk', 1)
      ..setSetting('phone_seen_radar', true);
    await session.flush();
    await session.save(); // o rodízio cheio: save.ksv, .1 e .2
    await session.flush();
    expect(names(docs), containsAll(['save.ksv', 'save.ksv.1', 'save.ksv.2']));
    await File('${docs.path}/save.json.migrated').writeAsString(jsonEncode(real)); // sobra do formato antigo
    await File('${docs.path}/patrulha.jsonl').writeAsString('{"uid":"1"}\n');
    await File('${(await Directory('${support.path}/blocks').create()).path}/a.blk').writeAsString('x');
    await File('${(await Directory('${support.path}/regions').create()).path}/sp.bin').writeAsString('pacote');
    await File('${temp.path}/kenoma-backup-20261101-120000.ksv').writeAsBytes(encodeKsv(real));
    final before = session.state;
    var patrolStops = 0;

    await FreshStart(
      store: store,
      targets: () => freshStartTargets(documents: docs, support: support, temp: temp),
      requestBackup: const DeviceSensors().requestBackup,
      stopPatrol: () async => patrolStops++,
    ).run(session, t0 + 60);

    expect(systemCalls, ['requestBackup'], reason: 'BackupManager.dataChanged pelo canal kenoma/system');
    expect(patrolStops, 1);
    expect(names(docs), {'save.ksv'}, reason: 'o rodízio antigo, o legado e o diário da Patrulha saem');
    expect(names(support), {'regions'}, reason: 'o cache de blocos sai; os pacotes de região ficam');
    expect(File('${support.path}/regions/sp.bin').existsSync(), isTrue);
    expect(names(temp), isEmpty, reason: 'a cópia do exportar também era o save antigo');

    final seed = decodeKsv(await store.current.readAsBytes());
    expect(seed.keys.toSet(), {'schema_version', 'founder', 'settings', kFreshStartGroupKey}, reason: 'nada do progresso fica no disco');

    // Reabre: o jogo nasce como numa instalação nova, com a identidade e os Ajustes de antes.
    final again = await open(store, t: t0 + 120);
    await again.flush();
    final s = again.state;
    expect(s.founder!.playerId, before.founder!.playerId);
    expect(s.founder!.firstInstallVersion, before.founder!.firstInstallVersion);
    expect(s.founder!.chainValid, isTrue, reason: 'o verificador da cadeia aceita a linha de recomeço');
    expect(s.founder!.versionsSeen.map((e) => e.version).toList().sublist(before.founder!.versionsSeen.length - 1), ['0.16.0+25', kRestartEntry],
        reason: 'a mesma versão reaberta depois do recomeço não repete a linha');
    expect(s.founder!.versionsSeen.last.utc, t0 + 60);
    expect(s.groupCode, before.groupCode);
    expect((s.setting('street_names'), s.settingOr('veil_traffic', true), s.setting('phone_seen_radar')), (true, false, false));
    expect((s.progress.level, s.progress.xp, s.collection.length, s.circle.length, s.bestiary.length, s.marks.length), (1, 0, 0, 0, 0, 0));
    expect(s.inventory, start);
    expect(s.conjurer.school, isNull);
    expect(s.story.events, isEmpty, reason: 'o tutorial do mentor recomeça: a noite das Fendas');
    expect(s.visitedCells, isEmpty);
    expect(s.registrySize, 0);
    for (final f in docs.listSync().whereType<File>()) {
      final j = decodeKsv(f.readAsBytesSync());
      expect((j['collection'] as List?) ?? const [], isEmpty, reason: '${f.path}: nenhuma criatura do jogo antigo');
      expect(j['conjurer'] == null || (j['conjurer'] as Map)['school'] == null, isTrue);
    }

    // Abrir de novo a mesma versão não repete a linha.
    final third = await open(store, t: t0 + 300);
    expect(third.state.founder!.versionsSeen.length, s.founder!.versionsSeen.length);
  });

  test('a semente é pura: só identidade, Ajustes sem o progresso disfarçado e o grupo', () {
    final seed = freshStartSeed({...real, 'settings': {'rain_fx': false, 'ritual_viewed_soot.ritual': 2, 'profile_seen_talent': 3}}, nowUtc: 5);
    expect(seed['settings'], {'rain_fx': false});
    expect(seed[kFreshStartGroupKey], real['group_code']);
    final f = Founder.fromJson(seed['founder'] as Map<String, dynamic>);
    expect((f.versionsSeen.last.version, f.versionsSeen.last.utc, f.chainValid), (kRestartEntry, 5, true));
  });
}
