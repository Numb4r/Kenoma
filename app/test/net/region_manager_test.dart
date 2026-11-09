import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/epochs.dart';
import 'package:kenoma/data/region_loader.dart' show sha256Hex;
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/net/map_http.dart';
import 'package:kenoma/net/region_catalog.dart';
import 'package:kenoma/net/region_manager.dart';
import 'package:kenoma/net/signed_epochs.dart';
import 'package:kenoma/world/layered_world.dart';

import '../support/fixtures.dart';

const _fx = 'test/net/fixtures/region';
const _base = 'http://localhost:8000/';
const lat = -23.55, lon = -46.63;
final _pub = File('$_fx/region_pub.hex').readAsStringSync().trim();

Map<String, dynamic> _catalog() => jsonDecode(File('$_fx/regions.json').readAsStringSync()) as Map<String, dynamic>;

Map<String, dynamic> _fileOf(Map<String, dynamic> cat, String kind) =>
    (((cat['regions'] as List).single as Map<String, dynamic>)['files'] as Map<String, dynamic>)[kind] as Map<String, dynamic>;

Map<String, dynamic> _ref(Map<String, dynamic> f) => {'file': f['file'], 'sha256': f['sha256']};

/// As épocas reais, com a última listando a região de teste como a época 5 vai listar.
EpochSchedule _schedule({String? logicSha, bool listed = true}) {
  final json = jsonDecode(jsonEncode(epochsJson())) as Map<String, dynamic>;
  final cat = _catalog();
  final e = (json['epochs'] as List).last as Map<String, dynamic>;
  if (listed) {
    (e['region_packs'] as Map)['test_city'] = {..._ref(_fileOf(cat, 'logic')), 'sha256': ?logicSha};
    (e['visual_packs'] as Map)['test_city'] = _ref(_fileOf(cat, 'visual'));
    (e['walkable'] as Map)['exclude_packs'] = {'test_city': _ref(_fileOf(cat, 'nowalk'))};
  }
  return EpochSchedule.fromJson(json);
}

LayeredWorld _world() => LayeredWorld(regions: [
      LoadedRegion(id: kBundledRegion, grid: loadCampinasPack(), visual: VisualPack.parse(Uint8List.fromList(File('assets/regions/campinas_e0_vis.bin').readAsBytesSync()))),
    ]);

/// O servidor falso: serve os arquivos da fixture e conta os pedidos.
class _Server {
  final gets = <(String, int)>[];
  final overrides = <String, Uint8List>{};
  bool down = false;
  bool noRange = false;

  /// Bytes no lugar do `regions.json` da fixture.
  Uint8List? catalog;

  Future<Uint8List?> fetch(Uri url) async {
    if (down) return null;
    if (catalog != null && url.path.endsWith('regions.json')) return catalog;
    final f = File('$_fx/${url.pathSegments.last}');
    return f.existsSync() ? f.readAsBytesSync() : null;
  }

  Future<RangeReply> get(Uri url, int from) async {
    if (down) throw const SocketException('sem rede');
    final name = url.pathSegments.last;
    gets.add((name, from));
    final all = overrides[name] ?? File('$_fx/$name').readAsBytesSync();
    final resume = from > 0 && !noRange;
    return RangeReply(resume ? 206 : 200, Stream.value(resume ? all.sublist(from) : all));
  }
}

class _Rig {
  _Rig({EpochSchedule? schedule}) : schedule = schedule ?? _schedule();

  final EpochSchedule schedule;
  final server = _Server();
  final dir = Directory.systemTemp.createTempSync('regions');
  final notices = <String>[];
  late int now = schedule.epochs.last.startsUtc + 3600;
  late LayeredWorld world;

  RegionManager open({int confirmBytes = 1 << 30, RegionConfirm? confirm}) {
    world = _world();
    return RegionManager(
      world: world,
      schedule: schedule,
      dir: dir,
      confirmBytes: confirmBytes,
      retryS: 60,
      nowUtc: () => now,
      realNowUtc: () => now,
      baseUrl: () => _base,
      fetch: server.fetch,
      get: server.get,
      publicKeyHex: _pub,
      onNotice: notices.add,
      confirm: confirm,
    );
  }

  List<String> get names => [for (final f in dir.listSync().whereType<File>()) f.path.split('/').last]..sort();
}

Future<RegionEntry> _entryOf(RegionManager m) async {
  await m.refreshCatalog(force: true);
  return m.catalog!.regions.single;
}

void main() {
  test('o catálogo assinado entra; adulterado ou com assinatura errada, não', () async {
    final r = _Rig();
    final m = r.open();
    await m.refreshCatalog(force: true);
    expect(m.catalog?.regions.single.name, 'Cidade Teste');
    expect(r.names, containsAll(['regions.json', 'regions.json.sig']));

    final bad = _Rig();
    bad.server.catalog = Uint8List.fromList([...File('$_fx/regions.json').readAsBytesSync(), 32]);
    final tampered = bad.open();
    await tampered.refreshCatalog(force: true);
    expect(tampered.catalog, isNull);
    expect(bad.names, isEmpty);
  });

  test('pacote certo: confere SHA e assinatura, grava com rename e entra no mundo sem reiniciar', () async {
    final r = _Rig();
    final m = r.open();
    final entry = await _entryOf(m);
    expect(m.statusOf(entry), RegionStatus.available);
    final rev = r.world.revision;
    expect(r.world.sourceAt(lat, lon), MapSourceKind.floor);
    expect(await m.download(entry), isTrue);
    expect(r.world.sourceAt(lat, lon), MapSourceKind.pack);
    expect(r.world.revision, greaterThan(rev));
    expect(m.statusOf(entry), RegionStatus.ready);
    expect(r.names, containsAll(['test_e5.bin', 'test_e5_vis.bin', 'test_e5_nowalk.bin']));
    expect(r.names.where((n) => n.endsWith('.part')), isEmpty);
    expect(r.notices, ['Mapa de Cidade Teste pronto']);
  });

  test('SHA errado: nada entra, a parte é apagada e fica o aviso', () async {
    final r = _Rig();
    final m = r.open();
    final entry = await _entryOf(m);
    final bytes = File('$_fx/test_e5.bin').readAsBytesSync();
    r.server.overrides['test_e5.bin'] = Uint8List.fromList(bytes)..[bytes.length - 1] ^= 1;
    expect(await m.download(entry), isFalse);
    expect(r.world.sourceAt(lat, lon), MapSourceKind.floor);
    expect(m.statusOf(entry), RegionStatus.failed);
    expect(r.names, isNot(contains('test_e5.bin.part')));
    expect(r.names, isNot(contains('test_e5.bin')));
    expect(r.notices, ['Não consegui baixar Cidade Teste']);
  });

  test('assinatura errada: o SHA bate, mas nada entra', () async {
    final r = _Rig();
    final m = r.open();
    final cat = _catalog();
    _fileOf(cat, 'visual')['sig'] = _fileOf(cat, 'logic')['sig'];
    final entry = RegionCatalog.fromJson(cat).regions.single;
    expect(await m.download(entry), isFalse);
    expect(r.world.sourceAt(lat, lon), MapSourceKind.floor);
    expect(r.names, isNot(contains('test_e5_vis.bin')));
  });

  test('SHA divergente de epochs.json: epochs.json manda e nada é baixado', () async {
    final r = _Rig(schedule: _schedule(logicSha: 'a' * 64));
    final m = r.open();
    final entry = await _entryOf(m);
    expect(m.statusOf(entry), RegionStatus.blocked);
    expect(await m.download(entry), isFalse);
    expect(r.server.gets, isEmpty);
  });

  test('região que a época vigente não lista também não baixa', () async {
    final r = _Rig(schedule: _schedule(listed: false));
    final m = r.open();
    final entry = await _entryOf(m);
    expect(m.statusOf(entry), RegionStatus.blocked);
    await m.tick(lat, lon);
    expect(r.server.gets, isEmpty);
  });

  test('entrar na bbox com internet baixa sozinho; fora dela, não', () async {
    final r = _Rig();
    final m = r.open();
    await m.tick(lat + 1, lon);
    expect(r.server.gets, isEmpty);
    await m.tick(lat, lon);
    expect(r.world.sourceAt(lat, lon), MapSourceKind.pack);
  });

  test('acima do limite pede confirmação nos dois caminhos; recusar não baixa nem pergunta de novo no automático', () async {
    final r = _Rig();
    final asked = <int>[];
    var answer = false;
    final m = r.open(confirmBytes: 10, confirm: (e, bytes) async {
      asked.add(bytes);
      return answer;
    });
    final entry = await _entryOf(m);
    await m.tick(lat, lon);
    expect(asked, [entry.totalBytes]);
    expect(r.server.gets, isEmpty);
    await m.tick(lat, lon);
    expect(asked.length, 1);
    // O botão dos Ajustes pergunta de novo e, com sim, baixa.
    answer = true;
    expect(await m.download(entry), isTrue);
    expect(asked.length, 2);
  });

  test('retoma do .part com 206, e recomeça sem corromper se o servidor responder 200', () async {
    for (final noRange in [false, true]) {
      final r = _Rig();
      final m = r.open();
      final entry = await _entryOf(m);
      final bytes = File('$_fx/test_e5.bin').readAsBytesSync();
      File('${r.dir.path}/test_e5.bin.part').writeAsBytesSync(bytes.sublist(0, 20));
      r.server.noRange = noRange;
      expect(await m.download(entry), isTrue);
      expect(r.server.gets.first, ('test_e5.bin', 20));
      expect(sha256Hex(File('${r.dir.path}/test_e5.bin').readAsBytesSync()), sha256Hex(bytes));
    }
  });

  test('falha de rede guarda a parte, avisa uma vez e o automático tenta de novo depois de retry_s', () async {
    final r = _Rig();
    final m = r.open();
    final entry = await _entryOf(m);
    r.server.down = true;
    expect(await m.download(entry), isFalse);
    expect(m.statusOf(entry), RegionStatus.failed);
    await m.tick(lat, lon);
    expect(r.notices.length, 1);
    r.server.down = false;
    await m.tick(lat, lon);
    expect(r.server.gets, isEmpty, reason: 'ainda dentro de retry_s');
    r.now += 60;
    await m.tick(lat, lon);
    expect(r.world.sourceAt(lat, lon), MapSourceKind.pack);
  });

  test('ao abrir o app recarrega do disco sem rede; arquivo adulterado não entra e sai do disco', () async {
    final r = _Rig();
    final first = r.open();
    expect(await first.download(await _entryOf(first)), isTrue);
    r.server.down = true;
    r.server.gets.clear();
    final again = r.open();
    await again.loadInstalled();
    expect(r.world.sourceAt(lat, lon), MapSourceKind.pack);
    expect(again.catalog, isNotNull);
    expect(r.server.gets, isEmpty);

    final f = File('${r.dir.path}/test_e5.bin');
    f.writeAsBytesSync([...f.readAsBytesSync(), 0]);
    final third = r.open();
    await third.loadInstalled();
    expect(r.world.sourceAt(lat, lon), MapSourceKind.floor);
    expect(f.existsSync(), isFalse);
  });

  test('catálogo com nome de arquivo fora da pasta é rejeitado', () {
    final cat = _catalog();
    _fileOf(cat, 'logic')['file'] = '../save.bin';
    expect(() => RegionCatalog.fromJson(cat), throwsFormatException);
  });

  group('épocas', () {
    test('o parser aceita walkable.exclude_packs, e exclude_pack continua valendo', () {
      final w = _schedule().epochs.last.walkable!;
      expect(w.exclude, isNotNull);
      expect(w.excludePacks['test_city']?.file, 'test_e5_nowalk.bin');
      final real = loadEpochs().epochs;
      expect(real.firstWhere((e) => e.id == 4).walkable!.excludePacks, isEmpty, reason: 'a época 4 não muda');
      expect(real.firstWhere((e) => e.id == 5).walkable!.excludePacks.keys, ['sao_paulo']);
    });

    test('época do feed com região baixável não exige o pacote nos assets; a embutida continua exigindo', () {
      final json = _schedule().source!;
      final e = (json['epochs'] as List).last as Map<String, dynamic>;
      expect(epochPackFiles(e), isNot(contains('test_e5.bin')));
      expect(epochPackFiles(e), containsAll(['campinas_e0.bin', 'campinas_e0_vis.bin', 'campinas_e2_nowalk.bin']));
    });
  });
}
