/// A arte de interface da Bolsa e da Bancada (docs/art/estilo-ui.md): molduras em nove partes, ícones de 16 px e os pontos
/// de qualidade, desenhados no Aseprite e lidos de `assets/art/ui/`. Cada pixel de arte vira 3 × 3 dp, sem suavização.
/// O que faltar vira placeholder gerado: arte nunca bloqueia código.
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../capture/eco_type.dart';
import '../../crafting/crafting_data.dart';
import '../../crafting/quality.dart';
import '../colors.dart';

/// Pixel de arte em dp.
const double kUiPixel = 3;

class UiArt {
  UiArt._(this.images, this.insets);

  static UiArt? instance;

  /// Carrega uma vez tudo o que existir em `assets/art/ui/` (as bordas das nove partes vêm de `slices.json`).
  static Future<UiArt> load([AssetBundle? bundle]) async {
    if (instance != null) return instance!;
    return _loading ??= _load(bundle ?? rootBundle).whenComplete(() => _loading = null);
  }

  /// A carga em andamento (0.26.2: o `main` e a tela de carregamento do mapa pedem juntos; uma leitura só).
  static Future<UiArt>? _loading;

  /// Só para testes: esquece a carga em andamento (a de um teste anterior morre com a zona dele e nunca termina).
  @visibleForTesting
  static void resetLoading() => _loading = null;

  static Future<UiArt> _load(AssetBundle b) async {
    final images = <String, ui.Image>{};
    var insets = <String, List<int>>{};
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(b);
      // 0.26.2: todas em paralelo (uma por vez eram 0,7 a 1,7 s no g54; a decodificação corre fora da thread da interface).
      Future<ui.Image> decode(String path) async {
        final bytes = await b.load(path);
        return (await (await ui.instantiateImageCodec(bytes.buffer.asUint8List())).getNextFrame()).image;
      }

      final paths = manifest.listAssets().where((p) => p.startsWith('assets/art/ui/') && p.endsWith('.png')).toList();
      final decoded = await Future.wait(paths.map(decode));
      for (var i = 0; i < paths.length; i++) {
        images[paths[i].substring('assets/art/ui/'.length, paths[i].length - 4)] = decoded[i];
      }
      final raw = jsonDecode(await b.loadString('assets/art/ui/slices.json')) as Map<String, dynamic>;
      insets = {for (final e in raw.entries) e.key: [for (final v in e.value as List<dynamic>) v as int]};
    } on Exception {
      // sem arte ainda: tudo vira placeholder
    }
    return instance = UiArt._(images, insets);
  }

  final Map<String, ui.Image> images;
  final Map<String, List<int>> insets;

  ui.Image? image(String name) => images[name];

  /// O ícone de um item: `item.vessel.glass` → `icons/vessel_glass`; Essências e Pós usam o genérico tingido.
  ui.Image? icon(String itemId) {
    final id = parseStack(itemId).id;
    final own = images['icons/${id.replaceFirst('item.', '').replaceAll('.', '_')}'];
    if (own != null) return own;
    if (id.startsWith('item.essence')) return images['icons/essence'];
    if (id.startsWith('item.dust')) return images['icons/dust'];
    return null;
  }
}

/// Desenha [image] em nove partes com as bordas [insets] (esq, topo, dir, baixo, em pixels de arte), cada pixel de arte
/// com [pixel] dp: os cantos não deformam, as bordas e o miolo esticam.
class NineSlicePainter extends CustomPainter {
  const NineSlicePainter(this.image, this.insets, {this.pixel = kUiPixel});

  final ui.Image image;
  final List<int> insets;
  final double pixel;

  @override
  void paint(Canvas canvas, Size size) {
    final w = image.width.toDouble(), h = image.height.toDouble();
    final l = insets[0].toDouble(), t = insets[1].toDouble(), r = insets[2].toDouble(), b = insets[3].toDouble();
    final xs = [0.0, l, w - r, w], ys = [0.0, t, h - b, h];
    final dl = l * pixel, dt = t * pixel, dr = r * pixel, db = b * pixel;
    final dxs = [0.0, dl, size.width - dr, size.width], dys = [0.0, dt, size.height - db, size.height];
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    for (var j = 0; j < 3; j++) {
      for (var i = 0; i < 3; i++) {
        final src = Rect.fromLTRB(xs[i], ys[j], xs[i + 1], ys[j + 1]);
        final dst = Rect.fromLTRB(dxs[i], dys[j], dxs[i + 1], dys[j + 1]);
        if (src.isEmpty || dst.isEmpty) continue;
        canvas.drawImageRect(image, src, dst, paint);
      }
    }
  }

  @override
  bool shouldRepaint(NineSlicePainter old) => old.image != image;
}

/// Uma peça do kit em nove partes como `decoration` de um `Container` (0.26.0): desenha pelo [NineSlicePainter], que estica
/// certo (o `DecorationImage` com `centerSlice` e `scale` deixava o miolo em blocos). [line] pinta um aro de 1 pixel de arte
/// por cima (destaque, aviso). Sem a arte carregada, uma caixa com [fallbackFill] e contorno.
class KitDecoration extends Decoration {
  const KitDecoration(this.name, {this.line, this.fallbackFill = kPanel});

  final String name;
  final Color? line;
  final Color fallbackFill;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _KitBoxPainter(this);

  @override
  bool operator ==(Object other) => other is KitDecoration && other.name == name && other.line == line && other.fallbackFill == fallbackFill;

  @override
  int get hashCode => Object.hash(name, line, fallbackFill);
}

class _KitBoxPainter extends BoxPainter {
  _KitBoxPainter(this.d);

  final KitDecoration d;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final art = UiArt.instance;
    final img = art?.image(d.name), ins = art?.insets[d.name];
    final rect = offset & size;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kUiPixel
      ..isAntiAlias = false;
    if (img == null || ins == null) {
      canvas.drawRect(rect, Paint()..color = d.fallbackFill);
      canvas.drawRect(rect.deflate(kUiPixel / 2), stroke..color = d.line ?? kPanelLine);
      return;
    }
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    NineSlicePainter(img, ins).paint(canvas, size);
    canvas.restore();
    if (d.line != null) canvas.drawRect(rect.deflate(kUiPixel / 2), stroke..color = d.line!);
  }
}

/// Um painel com a moldura [name] (`panel`, `sheet`, `tab_on`, `button`...). Sem a arte, uma caixa com contorno.
class UiFrame extends StatelessWidget {
  const UiFrame({required this.name, required this.child, this.padding = const EdgeInsets.all(12), this.fallbackLine = kPanelLine, this.fallbackFill = kPanel, super.key});

  final String name;
  final Widget child;
  final EdgeInsets padding;
  final Color fallbackLine;
  final Color fallbackFill;

  @override
  Widget build(BuildContext context) {
    final art = UiArt.instance;
    final img = art?.image(name);
    final ins = art?.insets[name];
    if (img == null || ins == null) {
      return Container(padding: padding, decoration: BoxDecoration(color: fallbackFill, border: Border.all(color: fallbackLine, width: kUiPixel)), child: child);
    }
    // 0.24.1: o conteúdo fica sempre fora da borda da moldura, com 3 dp de folga (as etiquetas cortadas da 0.24.0).
    double at(int i, double p) => p == 0 ? 0 : (p > ins[i] * kUiPixel + 3 ? p : ins[i] * kUiPixel + 3);
    final pad = EdgeInsets.fromLTRB(at(0, padding.left), at(1, padding.top), at(2, padding.right), at(3, padding.bottom));
    return CustomPaint(painter: NineSlicePainter(img, ins), child: Padding(padding: pad, child: child));
  }
}

/// A cor de um nível de qualidade no placeholder.
Color qualityColor(Quality q) => switch (q) {
      Quality.common => kText,
      Quality.good => kSignal,
      Quality.perfect => kVeil,
    };

/// De 1 a 3 pontos de qualidade: a quantidade diferencia, não só a cor.
class QualityDots extends StatelessWidget {
  const QualityDots(this.quality, {super.key});

  final Quality quality;

  @override
  Widget build(BuildContext context) {
    final img = UiArt.instance?.image('dot_${quality.name}');
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < quality.dots; i++)
        Padding(
          padding: const EdgeInsets.only(left: kUiPixel),
          child: img == null
              ? Container(width: 2 * kUiPixel, height: 2 * kUiPixel, color: qualityColor(quality))
              : RawImage(image: img, width: img.width * kUiPixel, height: img.height * kUiPixel, filterQuality: FilterQuality.none, fit: BoxFit.fill),
        ),
    ]);
  }
}

/// O ícone de 16 px de um item (48 dp). Sem arte, um quadrado com a inicial do nome.
class ItemIcon extends StatelessWidget {
  const ItemIcon({required this.itemId, required this.name, this.tint, this.size = 16 * kUiPixel, this.silhouette = false, super.key});

  final String itemId;
  final String name;
  final Color? tint;
  final double size;

  /// A silhueta do grimório: só o contorno escuro, sem cor.
  final bool silhouette;

  @override
  Widget build(BuildContext context) {
    final img = UiArt.instance?.icon(itemId);
    Widget w = img == null
        ? Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint?.withValues(alpha: 0.35) ?? kPanelLine, border: Border.all(color: kOutline, width: kUiPixel)),
            child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: TextStyle(fontSize: 16, color: tint ?? kText)),
          )
        : RawImage(image: img, width: size, height: size, filterQuality: FilterQuality.none, fit: BoxFit.fill);
    if (silhouette) w = ColorFiltered(colorFilter: const ColorFilter.mode(kOutline, BlendMode.srcIn), child: w);
    if (img != null && tint != null && !silhouette && (itemId.contains('essence') || itemId.contains('dust'))) {
      w = ColorFiltered(colorFilter: ColorFilter.mode(tint!.withValues(alpha: 0.55), BlendMode.srcATop), child: w);
    }
    return w;
  }
}

/// A cor do tipo de um item (Essências e Pós tingem o ícone genérico); `null` sem tipo.
Color? itemTint(CraftingBook book, String id) {
  final type = book.item(id)?.type;
  final t = EcoType.values.where((e) => e.name == type).firstOrNull;
  return t == null ? null : typeColor(t);
}
