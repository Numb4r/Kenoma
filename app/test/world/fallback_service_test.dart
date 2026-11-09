import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/block_cache.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/world/fallback/block.dart';
import 'package:kenoma/world/fallback_service.dart';
import 'package:kenoma/world/geo_fix.dart';
import 'package:kenoma/world/layered_world.dart';
import 'package:kenoma/world/map_fallback_balance.dart';

import '../support/fallback_fixtures.dart';
import '../support/fixtures.dart';

const lat = -23.55, lon = -46.63;

class _Call {
  _Call(this.url, this.body, this.userAgent);
  final Uri url;
  final String body;
  final String userAgent;
}

/// O relógio, a rede falsa e um serviço novo sobre a mesma pasta: "abrir o app de novo" é chamar [open].
class _Rig {
  _Rig() : dir = Directory.systemTemp.createTempSync('blocks');

  final Directory dir;
  final balance = MapFallbackBalance(loadJson('assets/data/balance.json'));
  final schedule = loadEpochs();
  final pack = loadCampinasPack();
  final calls = <_Call>[];
  late int now = schedule.epochs.last.startsUtc + 86400;
  late LayeredWorld world;
  HttpReply Function(Uri url) reply = (_) => okReply();

  Future<HttpReply> _post(Uri url, String body, {required String userAgent, required Duration timeout, required int maxBytes}) async {
    calls.add(_Call(url, body, userAgent));
    return reply(url);
  }

  FallbackService open({int? limitBytes}) {
    world = LayeredWorld(regions: [LoadedRegion(id: 'campinas', grid: pack, visual: VisualPack.parse(_emptyVisual))]);
    return FallbackService(
      world: world,
      schedule: schedule,
      codec: fakeCodec,
      balance: balance,
      post: _post,
      cache: BlockCache(dir, limitBytes: limitBytes ?? balance.diskLimitBytes),
      appVersion: '0.15.1+24',
      nowUtc: () => now,
      realNowUtc: () => now,
    );
  }

  int get epoch => schedule.epochs.last.id;
}

/// Pacote visual sem tiles: a região embutida do teste só precisa ficar longe do bloco.
final Uint8List _emptyVisual = Uint8List.fromList([
  ...'VIS1'.codeUnits, 2, 0, 15, 0, 16, 0, 0, 0, 0, // versão 2, zoom 15, extent 4096, 0 tiles
  ...gzip.encode([0]), // tabela de nomes vazia
]);

void main() {
  final (tx, ty) = latLonToTile(lat, lon, blockZoom);

  test('data fixa: a consulta usa o início da época vigente, em qualquer dia, por POST form e User-Agent genérico', () async {
    final r = _Rig();
    final s = r.open();
    await s.tick(lat, lon);
    final call = r.calls.single;
    final body = Uri.decodeQueryComponent(call.body);
    final start = r.schedule.epochs.last.startsUtc;
    final iso = DateTime.fromMillisecondsSinceEpoch(start * 1000, isUtc: true).toIso8601String().replaceFirst('.000Z', 'Z');
    expect(body, 'data=[date:"$iso"];tile $tx $ty');
    expect(call.userAgent, 'Kenoma/0.15.1+24');
    expect(call.url.toString(), 'https://overpass-api.de/api/interpreter');

    // Noutro dia, noutro aparelho: a mesma data.
    final other = _Rig()..now = start + 40 * 86400;
    await other.open().tick(lat, lon);
    expect(Uri.decodeQueryComponent(other.calls.single.body), body);
    expect(isoUtc(1790000000), '2026-09-21T14:13:20Z');
  });

  test('limite de velocidade: acima de 30 km/h só piso, e consulta quando o ônibus para', () async {
    final r = _Rig();
    final s = r.open();
    GeoFix fix(int ms, double speed, [double dLon = 0]) => GeoFix(lat: lat, lon: lon + dLon, accuracyM: 5, timeMs: ms, speedMps: speed);
    s.noteFix(fix(0, 12));
    s.noteFix(fix(4000, 12, 0.0005));
    expect(s.speedMps * 3.6, greaterThan(30));
    await s.tick(lat, lon);
    expect(r.calls, isEmpty);
    expect(r.world.sourceAt(lat, lon), MapSourceKind.floor);
    s.noteFix(fix(8000, 0, 0.0005));
    await s.tick(lat, lon);
    expect(r.calls.length, 1);
  });

  test('velocidade sem Doppler: vem da diferença entre posições', () async {
    final r = _Rig();
    final s = r.open();
    s.noteFix(const GeoFix(lat: lat, lon: lon, accuracyM: 5, timeMs: 0));
    s.noteFix(const GeoFix(lat: lat, lon: lon + 0.001, accuracyM: 5, timeMs: 4000)); // ~102 m em 4 s
    expect(s.speedMps * 3.6, closeTo(92, 3));
  });

  test('uma consulta por bloco e espera entre consultas', () async {
    final r = _Rig();
    final s = r.open();
    await s.tick(lat, lon);
    expect(r.calls.length, 1);
    expect(r.world.block(tx, ty)?.epochId, r.epoch);
    // O mesmo bloco nunca volta à rede, nem passada a espera.
    r.now += r.balance.minGapS * 3;
    await s.tick(lat, lon);
    expect(r.calls.length, 1);
    // Outro bloco, passada a espera: consulta.
    final (nextLat, nextLon) = tileFractionToLatLon(tx + 1.5, ty + 0.5, blockZoom);
    await s.tick(nextLat, nextLon);
    expect(r.calls.length, 2);
    await s.tick(lat, lon);
    final (lat3, lon3) = tileFractionToLatLon(tx + 2.5, ty + 0.5, blockZoom);
    await s.tick(lat3, lon3);
    expect(r.calls.length, 2, reason: 'dentro de min_gap_s');
    r.now += r.balance.minGapS;
    await s.tick(lat3, lon3);
    expect(r.calls.length, 3);
  });

  test('vizinhos na direção do movimento, depois do bloco do jogador', () async {
    final r = _Rig();
    final s = r.open();
    expect(s.wanted(lat, lon), [(tx, ty)]);
    s.noteFix(const GeoFix(lat: lat, lon: lon, accuracyM: 5, timeMs: 0));
    s.noteFix(const GeoFix(lat: lat, lon: lon + 0.0001, accuracyM: 5, timeMs: 5000)); // para leste, a pé
    expect(s.wanted(lat, lon), [(tx, ty), (tx + 1, ty)]);
    s.noteFix(const GeoFix(lat: lat + 0.0001, lon: lon + 0.0002, accuracyM: 5, timeMs: 10000)); // nordeste
    expect(s.wanted(lat, lon), [(tx, ty), (tx + 1, ty), (tx, ty - 1), (tx + 1, ty - 1)]);
  });

  test('servidor alternativo: troca no 429, no 504, no timeout e no erro', () async {
    final r = _Rig();
    final s = r.open();
    final hosts = <String>[];
    r.reply = (u) {
      hosts.add(u.host);
      if (u.host == 'overpass-api.de') return HttpReply(429, Uint8List(0));
      if (u.host == 'overpass.kumi.systems') throw const SocketException('timeout');
      return okReply();
    };
    await s.tick(lat, lon);
    expect(r.world.block(tx, ty), isNull);
    r.now += r.balance.minGapS;
    await s.tick(lat, lon);
    r.now += r.balance.minGapS;
    await s.tick(lat, lon);
    expect(hosts, ['overpass-api.de', 'overpass.kumi.systems', 'overpass.private.coffee']);
    expect(r.world.block(tx, ty), isNotNull);
  });

  test('resposta 200 cortada pela Overpass (remark) ou não JSON não entra no cache', () async {
    final r = _Rig();
    final s = r.open();
    r.reply = (_) => HttpReply(200, Uint8List.fromList(utf8.encode('{"elements":[],"remark":"runtime error: Query timed out"}')));
    await s.tick(lat, lon);
    expect(r.world.block(tx, ty), isNull);
    r.now += r.balance.minGapS;
    r.reply = (_) => HttpReply(200, Uint8List.fromList(utf8.encode('<html>erro</html>')));
    await s.tick(lat, lon);
    expect(r.world.block(tx, ty), isNull);
    expect(r.dir.listSync(recursive: true).whereType<File>(), isEmpty);
  });

  test('cache offline: a segunda abertura lê do disco, sem rede', () async {
    final r = _Rig();
    await r.open().tick(lat, lon);
    expect(File('${r.dir.path}/e${r.epoch}/${tx}_$ty.blk').existsSync(), isTrue);
    expect(r.dir.listSync(recursive: true).where((f) => f.path.endsWith('.tmp')), isEmpty);
    r.calls.clear();
    r.reply = (_) => throw const SocketException('sem rede');
    final again = r.open();
    expect(r.world.sourceAt(lat, lon), MapSourceKind.floor);
    await again.tick(lat, lon);
    expect(r.world.sourceAt(lat, lon), MapSourceKind.overpass);
    expect(r.calls, isEmpty, reason: 'bloco da época vigente: nada a pedir');
  });

  test('bloco de época anterior serve sem rede, e a rede nova o substitui', () async {
    final r = _Rig();
    final old = r.epoch - 1;
    await BlockCache(r.dir, limitBytes: 1 << 20).write(old, tx, ty, fakeCodec.encode(fakeBlock(tx, ty, old)));
    r.reply = (_) => throw const SocketException('sem rede');
    final s = r.open();
    await s.tick(lat, lon);
    expect(r.world.block(tx, ty)?.epochId, old);
    r.now += r.balance.retryS;
    r.reply = (_) => okReply();
    await s.tick(lat, lon);
    expect(r.world.block(tx, ty)?.epochId, r.epoch);
    expect(File('${r.dir.path}/e${r.epoch}/${tx}_$ty.blk').existsSync(), isTrue);
  });

  test('arquivo corrompido é apagado e o bloco volta da rede', () async {
    final r = _Rig();
    final f = File('${r.dir.path}/e${r.epoch}/${tx}_$ty.blk')..createSync(recursive: true);
    f.writeAsStringSync('lixo');
    await r.open().tick(lat, lon);
    expect(r.calls.length, 1);
    expect(r.world.block(tx, ty), isNotNull);
  });

  test('volta da internet refaz o bloco sozinho: passa por todos os servidores e tenta de novo a cada retry_s', () async {
    final r = _Rig();
    final s = r.open();
    r.reply = (_) => throw const SocketException('sem rede');
    for (var i = 0; i < r.balance.servers.length; i++) {
      await s.tick(lat, lon);
      r.now += r.balance.minGapS;
    }
    final tried = r.calls.length;
    expect(tried, r.balance.servers.length);
    expect(r.world.sourceAt(lat, lon), MapSourceKind.floor);
    await s.tick(lat, lon);
    expect(r.calls.length, tried, reason: 'espera retry_s');
    final rev = r.world.revision;
    r.reply = (_) => okReply();
    r.now += r.balance.retryS;
    await s.tick(lat, lon);
    expect(r.world.sourceAt(lat, lon), MapSourceKind.overpass);
    expect(r.world.revision, greaterThan(rev));
  });

  test('limite em disco: saem os mais antigos', () async {
    final dir = Directory.systemTemp.createTempSync('blocks');
    final cache = BlockCache(dir, limitBytes: 25);
    for (var i = 0; i < 4; i++) {
      await cache.write(1, i, 0, Uint8List(10));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      File('${dir.path}/e1/${i}_0.blk').setLastModifiedSync(DateTime.utc(2026, 1, 1 + i));
    }
    await cache.write(1, 9, 0, Uint8List(10));
    final names = dir.listSync(recursive: true).whereType<File>().map((f) => f.path.split('/').last).toSet();
    expect(names.length, 2);
    expect(names, contains('9_0.blk'));
  });

  test('o balance.json traz os servidores e os limites pedidos', () {
    final b = MapFallbackBalance(loadJson('assets/data/balance.json'));
    expect(b.servers.map((u) => u.host), ['overpass-api.de', 'overpass.kumi.systems', 'overpass.private.coffee']);
    expect(b.timeoutS, 150);
    expect(b.maxQuerySpeedKmh, 30);
    expect(b.regionConfirmBytes, 10 << 20);
  });
}
