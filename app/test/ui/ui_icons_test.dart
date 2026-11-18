import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/capture/eco_type.dart';
import 'package:kenoma/core/astro.dart';
import 'package:kenoma/ui/game/traffic_art.dart';

import '../support/fixtures.dart';

class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(Uint8List.fromList(await File(key).readAsBytes()));
}

/// 0.26.0: os ícones do Aseprite cobrem tudo o que os dados listam (app, clima, evento, tipo, as oito luas), em 16 px, e os
/// extras do tráfego (barco, canoa, cachorro e o carro da corrida) carregam.
void main() {
  (int, int) sizeOf(String path) {
    final b = File(path).readAsBytesSync();
    return (b.buffer.asByteData().getUint32(16), b.buffer.asByteData().getUint32(20)); // o IHDR do PNG
  }

  void icon16(String path) {
    expect(File(path).existsSync(), isTrue, reason: path);
    expect(sizeOf(path), (16, 16), reason: path);
  }

  test('todo app do celular tem ícone, e o bloqueado é uma tira de 3 quadros', () {
    for (final a in loadGameData().phone.apps) {
      icon16('assets/art/ui/apps/${a.id}.png');
    }
    for (final extra in ['collection', 'distill', 'fusion']) {
      icon16('assets/art/ui/apps/$extra.png');
    }
    expect(sizeOf('assets/art/ui/apps/locked.png'), (48, 16));
  });

  test('todo clima e todo evento dos dados têm ícone', () {
    for (final id in (loadJson('assets/data/clima.json')['climates'] as Map<String, dynamic>).keys) {
      icon16('assets/art/ui/climate/$id.png');
    }
    final ev = loadJson('assets/data/eventos.json');
    for (final id in ((ev['events'] ?? ev) as Map<String, dynamic>).keys) {
      icon16('assets/art/ui/event/$id.png');
    }
  });

  test('as oito luas e os doze tipos (em 16 e em 8)', () {
    for (var i = 0; i < 8; i++) {
      icon16('assets/art/ui/moon/moon_$i.png');
    }
    for (final t in EcoType.values) {
      icon16('assets/art/ui/types/${t.name}.png');
      expect(sizeOf('assets/art/ui/types/${t.name}_8.png'), (8, 8));
    }
  });

  test('a fase da lua cai no ícone certo: cada um cobre 1/8 do ciclo, centrado no nome', () {
    expect([for (var i = 0; i < 8; i++) moonPhaseIndex(i / 8)], [0, 1, 2, 3, 4, 5, 6, 7]);
    expect(moonPhaseIndex(0.97), 0, reason: 'quase nova de novo');
    expect(moonPhaseIndex(0.06), 0);
    expect(moonPhaseIndex(0.07), 1);
  });

  testWidgets('os extras do tráfego carregam com os papéis de cor somados', (tester) async {
    TrafficArt.testing = null;
    await tester.runAsync(() => TrafficArt.load(_DiskBundle()));
    final art = TrafficArt.current!;
    for (final n in ['boat', 'canoe', 'dog', 'ride_hatch', 'ride_sedan', 'ride_suv']) {
      expect(art.sprites[n], isNotNull, reason: n);
    }
    expect(art.outfits['dog_leash'], isNotNull, reason: 'a guia');
    expect(art.keys['dog']?['fur']?['kind'], 'key');
    expect(art.keys['vehicle']?['body'], isNotNull, reason: 'os papéis antigos continuam');
    expect(jsonDecode(File('assets/art/traffic/traffic_extra.json').readAsStringSync()), isA<Map<String, dynamic>>());
  });
}
