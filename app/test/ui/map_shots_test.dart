import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/ui/map/map_screen.dart';
import 'package:kenoma/world/map_camera.dart';

import '../data/region_preview_test.dart' show loadPreview;
import '../support/fixtures.dart';

/// Gera as capturas do M4 em `KENOMA_SHOTS_DIR` (desligado sem a variável):
///
///     KENOMA_SHOTS_DIR=../docs/m4 flutter test test/ui/map_shots_test.dart
///
/// Renderiza a tela real do mapa (Flame + HUD) numa tela de 1080 x 2400 a 2,625 de densidade, igual ao
/// moto g54: a captura de tela do aparelho, só que sem aparelho. Por local, duas imagens:
/// a tela na escala da spec (16 px/célula, com o dedo no centro) e a tela no zoom mínimo ao lado do
/// recorte do preview do M1, que cobre as mesmas células, para comparar.
void main() {
  final dir = Platform.environment['KENOMA_SHOTS_DIR'];
  const places = [('unicamp', -22.8174, -47.0697), ('centro', -22.9056, -47.0608)];
  const dpr = 2.625;
  const phone = Size(1080, 2400);

  Future<ui.Image> screen(WidgetTester tester, double lat, double lon, double scale, {bool touch = false}) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = dpr;
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(debugShowCheckedModeBanner: false, home: MapScreen(lat: lat, lon: lon, scale: scale)),
    ));
    for (var i = 0; i < 200 && find.text('Carregando mapa...').evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    TestGesture? finger;
    if (touch) finger = await tester.startGesture(tester.getCenter(find.byType(Scaffold)).translate(0, -250));
    // Os chunks entram aos poucos (8 por quadro): deixa montar tudo.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: dpr)))!;
    await finger?.up();
    await tester.pumpWidget(const SizedBox.shrink());
    return image;
  }

  Future<void> save(ui.Image image, String name) async {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    File('$dir/$name').writeAsBytesSync(data.buffer.asUint8List());
  }

  testWidgets('capturas do mapa na Unicamp e no centro de Campinas', skip: dir == null, (tester) async {
    addTearDown(tester.view.reset);
    Directory(dir!).createSync(recursive: true);
    final preview = await tester.runAsync(loadPreview);
    final pack = loadCampinasPack();
    for (final (name, lat, lon) in places) {
      // 1. A escala da spec, com o dedo no centro: HUD com a sonda.
      final close = await screen(tester, lat, lon, MapCamera.defaultScale, touch: true);
      expect((close.width, close.height), (1080, 2400));
      await save(close, 'mapa_${name}_16px.png');

      // 2. O zoom mínimo ao lado do preview, na mesma área.
      final far = await screen(tester, lat, lon, MapCamera.minScale);
      final cam = MapCamera.atLatLon(lat, lon, pixelsPerCell: MapCamera.minScale);
      final range = cam.visibleRange(phone.width / dpr, phone.height / dpr);
      final rec = ui.PictureRecorder();
      final canvas = ui.Canvas(rec);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 2 * 1080 + 24, 2400), Paint()..color = const Color(0xFF1A1424));
      // O recorte do preview, célula a célula, ampliado para a mesma escala do aparelho (2,625 px por célula).
      final crop = Paint()
        ..filterQuality = FilterQuality.none
        ..isAntiAlias = false;
      final previewImage = await tester.runAsync(() async {
        final c = await ui.instantiateImageCodec(File('test/fixtures/campinas_e0_preview.png').readAsBytesSync());
        return (await c.getNextFrame()).image;
      });
      final (l, t) = cam.cellToScreen(range.x0.toDouble(), range.y0.toDouble(), phone.width / dpr, phone.height / dpr);
      canvas.save();
      canvas.clipRect(const Rect.fromLTWH(0, 0, 1080, 2400));
      canvas.translate(0, 0);
      canvas.drawImageRect(
        previewImage!,
        Rect.fromLTWH((range.x0 - pack.x0).toDouble(), (range.y0 - pack.y0).toDouble(), range.width.toDouble(), range.height.toDouble()),
        Rect.fromLTWH(l * dpr, t * dpr, range.width * MapCamera.minScale * dpr, range.height * MapCamera.minScale * dpr),
        crop,
      );
      canvas.restore();
      canvas.drawImage(far, const Offset(1080 + 24, 0), Paint());
      final both = rec.endRecording().toImageSync(2 * 1080 + 24, 2400);
      await save(both, 'mapa_${name}_zoom_minimo_vs_preview.png');
      expect(preview!.width, pack.width);
    }
  });
}
