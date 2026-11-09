// O fallback de ponta a ponta com o codec real, em Isolate, sobre uma resposta no formato da Overpass.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/data/block_cache.dart';
import 'package:kenoma/data/visual_pack.dart';
import 'package:kenoma/ui/map/map_assets.dart';
import 'package:kenoma/world/fallback/block.dart';
import 'package:kenoma/world/fallback_service.dart';
import 'package:kenoma/world/layered_world.dart';
import 'package:kenoma/world/map_fallback_balance.dart';

import '../../support/fixtures.dart';

// Um bloco de São Paulo: fora do pacote embutido de Campinas, então o fallback é quem responde por ele.
const int tx = 12134, ty = 18574;

/// Pacote visual sem tiles: a região embutida do teste só precisa ficar longe do bloco.
final Uint8List _emptyVisual = Uint8List.fromList([
  ...'VIS1'.codeUnits, 2, 0, 15, 0, 16, 0, 0, 0, 0,
  ...gzip.encode([0]),
]);

class _Rig {
  _Rig(this.reply) : dir = Directory.systemTemp.createTempSync('kenoma_real_codec');

  final Directory dir;
  final HttpReply Function() reply;
  final world = LayeredWorld(regions: [LoadedRegion(id: 'campinas', grid: loadCampinasPack(), visual: VisualPack.parse(_emptyVisual))]);
  final queries = <String>[];
  final schedule = loadEpochs();
  late final balance = MapFallbackBalance(loadJson('assets/data/balance.json'));

  FallbackService service() {
    final now = schedule.epochs.last.startsUtc + 86400;
    return FallbackService(
      world: world,
      schedule: schedule,
      codec: fallbackCodec(loadJson('assets/data/biomes.json')),
      balance: balance,
      post: (url, body, {required userAgent, required timeout, required maxBytes}) async {
        queries.add(Uri.decodeQueryComponent(body));
        return reply();
      },
      cache: BlockCache(dir, limitBytes: balance.diskLimitBytes),
      appVersion: 'teste',
      nowUtc: () => now,
      realNowUtc: () => now,
    );
  }

  Iterable<File> get cached => dir.listSync(recursive: true).whereType<File>();
}

Uint8List _fixture() => Uint8List.fromList(gzip.decode(File('test/fixtures/fallback/${tx}_$ty.json.gz').readAsBytesSync()));

(double, double) _center() => tileFractionToLatLon(tx + 0.5, ty + 0.5, blockZoom);

void main() {
  test('resposta da Overpass vira bloco igual ao oráculo, no mundo e no cache', () async {
    final r = _Rig(() => HttpReply(200, _fixture()));
    addTearDown(() => r.dir.deleteSync(recursive: true));
    final (lat, lon) = _center();
    await r.service().tick(lat, lon);
    expect(r.queries, hasLength(1));
    expect(r.queries.single, contains('[timeout:120]'));
    final expected = File('test/fixtures/fallback/${tx}_$ty.grid').readAsBytesSync();
    var diff = 0;
    for (var row = 0; row < blockCells; row++) {
      for (var col = 0; col < blockCells; col++) {
        if (r.world.biomeAt(tx * blockCells + col, ty * blockCells + row) != expected[row * blockCells + col]) diff++;
      }
    }
    expect(diff, 0);
    expect(r.cached, isNotEmpty);
  });

  test('corpo cortado com HTTP 200 não entra no mundo nem no cache', () async {
    final full = _fixture();
    final r = _Rig(() => HttpReply(200, Uint8List.sublistView(full, 0, full.length ~/ 2)));
    addTearDown(() => r.dir.deleteSync(recursive: true));
    final (lat, lon) = _center();
    await r.service().tick(lat, lon);
    expect(r.queries, hasLength(1));
    expect(r.world.block(tx, ty), isNull);
    expect(r.cached, isEmpty);
  });
}
