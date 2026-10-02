import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/core/tiles.dart';
import 'package:kenoma/world/chunks.dart';
import 'package:kenoma/world/map_camera.dart';

const unicampLat = -22.8174, unicampLon = -47.0697;

void main() {
  const view = (1080.0, 2400.0);
  final cam = MapCamera.atLatLon(unicampLat, unicampLon);

  group('câmera', () {
    test('o centro inicial é a coordenada pedida, na escala da spec (16 px por célula)', () {
      final (lat, lon) = cam.latLon;
      expect(lat, closeTo(unicampLat, 1e-9));
      expect(lon, closeTo(unicampLon, 1e-9));
      expect(cam.pixelsPerCell, 16);
      expect(cam.centerX.floor(), latLonToTile(unicampLat, unicampLon, 21).$1);
    });

    test('o centro da tela é o centro da câmera, e ida e volta de tela para célula fecha', () {
      final (cx, cy) = cam.screenToCell(view.$1 / 2, view.$2 / 2, view.$1, view.$2);
      expect((cx, cy), (cam.centerX, cam.centerY));
      final (cx2, cy2) = cam.screenToCell(123.0, 456.0, view.$1, view.$2);
      final (sx, sy) = cam.cellToScreen(cx2, cy2, view.$1, view.$2);
      expect(sx, closeTo(123.0, 1e-9));
      expect(sy, closeTo(456.0, 1e-9));
    });

    test('arrastar o dedo para a direita e para baixo leva o mapa junto: o centro vai para oeste e norte', () {
      final moved = cam.panned(32, 48);
      expect(moved.centerX, closeTo(cam.centerX - 2, 1e-12));
      expect(moved.centerY, closeTo(cam.centerY - 3, 1e-12));
      // A célula que estava sob o dedo agora aparece 32 px para a direita.
      final (cx, cy) = cam.screenToCell(500, 700, view.$1, view.$2);
      final (sx, sy) = moved.cellToScreen(cx, cy, view.$1, view.$2);
      expect((sx, sy), (532.0, 748.0));
    });

    test('o zoom prende a célula sob o ponto de ancoragem', () {
      for (final scale in [2.0, 5.0, 24.0, 32.0]) {
        final z = cam.zoomedAbout(scale, 300, 1700, view.$1, view.$2);
        final (cx, cy) = cam.screenToCell(300, 1700, view.$1, view.$2);
        final (sx, sy) = z.cellToScreen(cx, cy, view.$1, view.$2);
        expect(sx, closeTo(300, 1e-6), reason: 'escala $scale');
        expect(sy, closeTo(1700, 1e-6), reason: 'escala $scale');
        expect(z.pixelsPerCell, scale);
      }
    });

    test('a escala fica entre o mínimo e o máximo', () {
      expect(cam.zoomedAbout(0.1, 0, 0, view.$1, view.$2).pixelsPerCell, MapCamera.minScale);
      expect(cam.zoomedAbout(500, 0, 0, view.$1, view.$2).pixelsPerCell, MapCamera.maxScale);
      expect(MapCamera.atLatLon(unicampLat, unicampLon, pixelsPerCell: 1000).pixelsPerCell, MapCamera.maxScale);
      expect(MapCamera.minScale, lessThan(MapCamera.defaultScale));
      expect(MapCamera.maxScale, greaterThan(MapCamera.defaultScale));
    });
  });

  group('células visíveis', () {
    test('com 16 px por célula uma tela de 1080 x 2400 mostra 68 x 151 células', () {
      final r = cam.visibleRange(view.$1, view.$2);
      expect(r.width, inInclusiveRange(67, 69));
      expect(r.height, inInclusiveRange(150, 152));
    });

    test('a faixa cobre a tela e nada além de uma célula de folga', () {
      for (final scale in [2.0, 7.3, 16.0, 32.0]) {
        final c = MapCamera(centerX: 773324.5 + 100, centerY: 1184541.25 + 50, pixelsPerCell: scale);
        final r = c.visibleRange(view.$1, view.$2);
        final (l, t) = c.cellToScreen(r.x0.toDouble(), r.y0.toDouble(), view.$1, view.$2);
        final (rr, b) = c.cellToScreen(r.x1 + 1.0, r.y1 + 1.0, view.$1, view.$2);
        expect(l, lessThanOrEqualTo(0.0 + 1e-9));
        expect(t, lessThanOrEqualTo(0.0 + 1e-9));
        expect(rr, greaterThanOrEqualTo(view.$1 - 1e-9));
        expect(b, greaterThanOrEqualTo(view.$2 - 1e-9));
        expect(l, greaterThan(-scale - 1e-9), reason: 'no máximo uma célula de folga à esquerda');
        expect(t, greaterThan(-scale - 1e-9));
        expect(rr, lessThan(view.$1 + scale + 1e-9));
        expect(b, lessThan(view.$2 + scale + 1e-9));
      }
    });

    test('mais zoom, menos células; menos zoom, mais', () {
      int count(double s) => MapCamera(centerX: 1000, centerY: 1000, pixelsPerCell: s).visibleRange(view.$1, view.$2).count;
      expect(count(32), lessThan(count(16)));
      expect(count(16), lessThan(count(2)));
      expect(count(2), greaterThan(100000), reason: '540 x 1200 células em escala 2');
    });

    test('o centro está sempre dentro da faixa visível', () {
      for (final s in [2.0, 16.0, 32.0]) {
        final c = MapCamera(centerX: 12345.6, centerY: 54321.9, pixelsPerCell: s);
        expect(c.visibleRange(view.$1, view.$2).contains(12345, 54321), isTrue);
      }
    });

    test('CellRange: interseção e vazio', () {
      const a = CellRange(0, 0, 9, 9);
      expect(a.intersect(const CellRange(5, 5, 20, 20)), const CellRange(5, 5, 9, 9));
      expect(a.intersect(const CellRange(20, 20, 30, 30)).isEmpty, isTrue);
      expect(a.count, 100);
    });

    test('o centro limitado ao pacote não sai dele', () {
      const bounds = CellRange(773324, 1184541, 773324 + 2330, 1184541 + 2403);
      final far = const MapCamera(centerX: 0, centerY: 9e9).clampedTo(bounds);
      expect(far.centerX, 773324);
      expect(far.centerY, 1184541 + 2404);
      final inside = cam.clampedTo(bounds);
      expect((inside.centerX, inside.centerY), (cam.centerX, cam.centerY));
    });
  });

  group('chunks', () {
    test('uma célula pertence ao chunk de 64 x 64 que a contém, e o chunk cobre exatamente essas células', () {
      expect(chunkOfCell(0, 0), (0, 0));
      expect(chunkOfCell(63, 63), (0, 0));
      expect(chunkOfCell(64, 63), (1, 0));
      expect(chunkOfCell(773324, 1184541), (12083, 18508));
      final r = cellsOfChunk((12083, 18508));
      expect(r.contains(773324, 1184541), isTrue);
      expect((r.width, r.height), (64, 64));
      expect(chunkOfCell(r.x0, r.y0), (12083, 18508));
      expect(chunkOfCell(r.x1, r.y1), (12083, 18508));
      expect(chunkOfCell(r.x1 + 1, r.y1), (12084, 18508));
    });

    test('chunksIn devolve os chunks que tocam a faixa, sem repetir e sem faltar', () {
      final range = cam.visibleRange(1080, 2400);
      final chunks = chunksIn(range);
      expect(chunks.toSet().length, chunks.length);
      final covered = chunks.fold<int>(0, (n, c) => n + cellsOfChunk(c).intersect(range).count);
      expect(covered, range.count, reason: 'cada célula visível está em exatamente um chunk');
      expect(chunks.length, inInclusiveRange(4, 12), reason: 'em escala 16 são poucos chunks');
      expect(chunksIn(const CellRange(5, 5, 4, 4)), isEmpty);
    });

    test('nível de detalhe: o menor com ao menos um pixel por pixel de tela, no máximo 16', () {
      expect(lodLevels, [16, 8, 4, 2]);
      expect(lodFor(32), 16);
      expect(lodFor(16), 16);
      expect(lodFor(15.9), 16);
      expect(lodFor(8), 8);
      expect(lodFor(7.9), 8);
      expect(lodFor(4.1), 8);
      expect(lodFor(4), 4);
      expect(lodFor(2.5), 4);
      expect(lodFor(2), 2);
    });

    test('a memória por chunk cai com o zoom: 4 MB a 16 px, 1 MB a 8, 256 KB a 4, 64 KB a 2', () {
      for (final (p, bytes) in [(16, 4194304), (8, 1048576), (4, 262144), (2, 65536)]) {
        expect(chunkCells * p * chunkCells * p * 4, bytes);
      }
    });
  });
}
