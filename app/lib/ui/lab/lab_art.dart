/// As imagens do Laboratório visual (0.21.0): os carimbos e os chãos de `ui/sprites/map_style.dart` (do `criativo`, regras
/// em `docs/art/estilo-mapa.md`) rasterizados uma vez em pixels de arte. Os chãos são módulos de 64 × 64 com o pontilhado e
/// os carimbos por hash da posição no módulo: repetidos e ancorados no mundo, nunca na tela. Só desenho.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import '../sprites/map_style.dart';

const int labPatternPx = 96; // 0.25.0: os módulos de chão na grade de 2 dp (12, 6, 24, 8) dividem 96

int _hash(int x, int y, int salt) {
  var h = (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791) ^ 0x5bd1e995;
  h = (h * 1103515245 + 12345) & 0x7fffffff;
  h = (h * 1103515245 + 12345) & 0x7fffffff;
  return h;
}

ui.Paint _px(int argb) => ui.Paint()
  ..color = ui.Color(argb)
  ..isAntiAlias = false;

/// Os neon trocados pelo `neon_off` (de dia, com as luzes apagadas).
const _neonKeys = {'neon_a', 'neon_b', 'neon_c'};

class LabArt {
  LabArt._(this.stamps, this.stampsOff, this.patterns, this.farPatterns, [this._shared = const {}]);

  /// As imagens que vieram de fora (o Aseprite): quem carregou é quem libera.
  final Set<ui.Image> _shared;

  /// Monta tudo (pouco mais de cem imagens pequenas). [overrides] (0.22.2): os carimbos e módulos desenhados no Aseprite
  /// pelo `criativo` (`assets/art/map/<nome>.png`), no lugar dos de código com o mesmo nome.
  factory LabArt.build({Map<String, ui.Image> overrides = const {}}) {
    final stamps = <String, ui.Image>{}, off = <String, ui.Image>{};
    for (final e in mapStamps.entries) {
      final o = overrides[e.key];
      if (o != null) {
        stamps[e.key] = o;
        continue;
      }
      stamps[e.key] = _stamp(e.key, e.value, lightsOn: true);
      if ((mapStampLegend[e.key] ?? const {}).values.any(_neonKeys.contains)) off[e.key] = _stamp(e.key, e.value, lightsOn: false);
    }
    // 0.22.0: o asfalto molhado (chuva) e os chãos de longe (zoom aberto: metade do
    // pontilhado e nenhum carimbo).
    final recipes = {
      ...groundRecipes,
      'road_wet': GroundRecipe(base: labColor('asphalt_wet'), dark: labColor('asphalt_wet_dark'), light: labColor('wet_shine'), ditherPct: 9, stamps: const [], stampsPer100Px: 0),
    };
    final patterns = {for (final e in recipes.entries) e.key: _pattern(e.key, e.value, module: overrides[groundPatterns[e.key]])};
    final far = {
      for (final e in recipes.entries)
        e.key: _pattern(e.key, GroundRecipe(base: e.value.base, dark: e.value.dark, light: e.value.light, ditherPct: e.value.ditherPct ~/ 2, stamps: const [], stampsPer100Px: 0), far: true),
    };
    return LabArt._(stamps, off, patterns, far, overrides.values.toSet());
  }

  final Map<String, ui.Image> stamps;

  /// Os carimbos com neon, apagados.
  final Map<String, ui.Image> stampsOff;
  final Map<String, ui.Image> patterns;

  /// Os chãos de longe (nível de detalhe do zoom aberto).
  final Map<String, ui.Image> farPatterns;

  ui.Image pattern(String key, {bool far = false}) => (far ? farPatterns : patterns)[key] ?? patterns[key] ?? patterns['urban']!;

  ui.Image? stamp(String name, {bool lightsOn = true}) => lightsOn ? stamps[name] : (stampsOff[name] ?? stamps[name]);

  void dispose() {
    for (final i in {...stamps.values, ...stampsOff.values, ...patterns.values, ...farPatterns.values}) {
      if (!_shared.contains(i)) i.dispose();
    }
  }
}

/// Os PNGs do Aseprite (`assets/art/map/`), pelo nome do carimbo. Os que faltam ficam de fora (vale o de código).
Future<Map<String, ui.Image>> loadAsepriteArt(Future<Uint8List?> Function(String path) load) async {
  final out = <String, ui.Image>{};
  for (final name in mapStamps.keys) {
    final bytes = await load('assets/art/map/$name.png');
    if (bytes == null) continue;
    final codec = await ui.instantiateImageCodec(bytes);
    out[name] = (await codec.getNextFrame()).image;
  }
  return out;
}

int labColor(String key) => mapPalette[key] ?? 0xFFFF00FF; // magenta: chave que falta na paleta (o teste confere)

/// O carimbo [name] de `mapStamps` como imagem (luzes acesas), para quem desenha fora da cena da cidade (a casa, 0.28.0).
ui.Image mapStampImage(String name) => _stamp(name, mapStamps[name] ?? const [], lightsOn: true);

ui.Image _stamp(String name, List<String> rows, {required bool lightsOn}) {
  final legend = mapStampLegend[name] ?? const {};
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  var w = 0;
  for (final (y, row) in rows.indexed) {
    if (row.length > w) w = row.length;
    for (var x = 0; x < row.length; x++) {
      final ch = row[x];
      if (ch == '.') continue;
      var key = legend[ch] ?? 'outline';
      if (!lightsOn && _neonKeys.contains(key)) key = 'neon_off';
      c.drawRect(ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), _px(labColor(key)));
    }
  }
  return rec.endRecording().toImageSync(w == 0 ? 1 : w, rows.isEmpty ? 1 : rows.length);
}

/// O chão [key]: o módulo de piso (se houver) ou o tom base, o pontilhado e os carimbos, tudo dentro de 64 × 64 e repetível
/// (o carimbo que passa da borda volta do outro lado).
ui.Image _pattern(String key, GroundRecipe r, {bool far = false, ui.Image? module}) {
  const n = labPatternPx;
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec);
  c.drawRect(const ui.Rect.fromLTWH(0, 0, n + 0.0, n + 0.0), _px(r.base));
  // A calçada portuguesa leva o módulo dela; longe, o piso perde a paginação fina.
  final moduleName = far ? null : groundPatterns[key];
  if (module != null && !far) {
    // O módulo do Aseprite repetido pelo módulo inteiro de 64 × 64.
    for (var y = 0; y < n; y += module.height) {
      for (var x = 0; x < n; x += module.width) {
        c.drawImage(module, ui.Offset(x.toDouble(), y.toDouble()), ui.Paint()..filterQuality = ui.FilterQuality.none);
      }
    }
  }
  final module0 = module != null ? null : moduleName;
  final salt = key.codeUnits.fold(7, (a, b) => a * 31 + b);
  final rows = module0 == null ? null : mapStamps[module0];
  if (rows != null) {
    final legend = mapStampLegend[module0] ?? const {};
    final mh = rows.length, mw = rows.first.length;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final ch = rows[y % mh][x % mw];
        if (ch != '.') c.drawRect(ui.Rect.fromLTWH(x + 0.0, y + 0.0, 1, 1), _px(labColor(legend[ch] ?? 'outline')));
      }
    }
  }
  final dark = _px(r.dark), light = _px(r.light);
  for (var y = 0; y < n; y++) {
    for (var x = 0; x < n; x++) {
      final h = _hash(x, y, salt) % 200;
      if (h < r.ditherPct) c.drawRect(ui.Rect.fromLTWH(x + 0.0, y + 0.0, 1, 1), h.isEven ? dark : light);
    }
  }
  final count = (r.stampsPer100Px * n * n / 10000).round();
  for (var i = 0; i < count && r.stamps.isNotEmpty; i++) {
    final name = r.stamps[_hash(i, 1, salt) % r.stamps.length];
    final rows = mapStamps[name];
    if (rows == null) continue;
    final legend = mapStampLegend[name] ?? const {};
    final x0 = _hash(i, 2, salt) % n, y0 = _hash(i, 3, salt) % n;
    for (final (y, row) in rows.indexed) {
      for (var x = 0; x < row.length; x++) {
        if (row[x] == '.') continue;
        c.drawRect(ui.Rect.fromLTWH(((x0 + x) % n).toDouble(), ((y0 + y) % n).toDouble(), 1, 1), _px(labColor(legend[row[x]] ?? 'outline')));
      }
    }
  }
  return rec.endRecording().toImageSync(n, n);
}
