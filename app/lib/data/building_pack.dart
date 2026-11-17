/// Leitor do arquivo de prédios e árvores `<região>_e0_bldg.bin` (`pipeline/build_buildings.py`, formato `BLD2` em
/// `pipeline/bld_tiles.py`): só cenário do estilo Completo do mapa. Nada da lógica lê; não é mundo e não entra em época.
///
/// 0.22.2: o arquivo é dividido em tiles z15 com um índice. O app lê o índice e carrega só os tiles em volta da câmera, fora
/// da thread de desenho (um `Isolate` por tile, como o campo de água), num cache que descarta os mais antigos acima de um teto
/// de memória ([kBuildingCacheBytes]). Enquanto um tile carrega, ele não tem prédio. Coordenadas em células z21.
library;

import 'dart:convert' show utf8;
import 'dart:io' show gzip;
import 'dart:isolate';
import 'dart:typed_data';

/// Teto da memória dos prédios carregados (estimativa: contornos e objetos), por arquivo.
const int kBuildingCacheBytes = 24 * 1024 * 1024;

/// O maior tile que o app aceita (comprimido). O maior de São Paulo tem 97 KB; o de Campinas, 18 KB.
const int kMaxBuildingTileBytes = 512 * 1024;

/// Um prédio: o contorno em células z21, o tipo do OSM (`house`, `yes`...), os andares (0 = sem dado) e se é comércio.
class PackBuilding {
  PackBuilding(this.xy, this.type, this.levels, this.shop, this.index);

  /// `x0, y0, x1, y1, ...` em células z21.
  final Float64List xy;
  final String type;
  final int levels;
  final bool shop;

  /// A posição no arquivo: o hash do prédio (estilo, janelas, props) sai dela e do contorno, igual em todo aparelho.
  final int index;

  int get length => xy.length ~/ 2;

  late final (double, double) centroid = () {
    var x = 0.0, y = 0.0;
    for (var i = 0; i < xy.length; i += 2) {
      x += xy[i];
      y += xy[i + 1];
    }
    return (x / length, y / length);
  }();

  /// A área em células² (o sinal some).
  late final double areaCells = () {
    var a = 0.0;
    for (var i = 0; i < length; i++) {
      final j = (i + 1) % length;
      a += xy[2 * i] * xy[2 * j + 1] - xy[2 * j] * xy[2 * i + 1];
    }
    return a.abs() / 2;
  }();

  late final (double, double, double, double) bounds = () {
    var l = double.infinity, t = double.infinity, r = -double.infinity, b = -double.infinity;
    for (var i = 0; i < xy.length; i += 2) {
      if (xy[i] < l) l = xy[i];
      if (xy[i] > r) r = xy[i];
      if (xy[i + 1] < t) t = xy[i + 1];
      if (xy[i + 1] > b) b = xy[i + 1];
    }
    return (l, t, r, b);
  }();

  /// Quanto o prédio ocupa na memória, por estimativa (o contorno e o objeto).
  int get estimatedBytes => 96 + xy.length * 8;
}

/// A fonte de prédios e árvores do mapa (o arquivo de uma região, ou várias).
abstract interface class BuildingSource {
  /// Os prédios cujo centro cai no retângulo (células z21), com folga de [margin] células. Só os dos tiles prontos; os que
  /// faltam começam a carregar.
  Iterable<PackBuilding> buildingsIn(double l, double t, double r, double b, {double margin = 2});

  /// As árvores do OSM no retângulo (células z21), dos tiles prontos.
  Iterable<(double, double)> treesIn(double l, double t, double r, double b);

  /// O tile de prédios da célula `(x, y)` já está pronto (ou não existe no arquivo).
  bool readyAt(double x, double y);

  /// Sobe quando um tile fica pronto ou sai do cache: quem desenha refaz o que usou os tiles de antes.
  int get buildingRevision;
}

const int _unit = 64;

/// Um tile decodificado.
typedef BuildingTile = ({List<PackBuilding> buildings, List<(double, double)> trees, int bytes});

/// Decodifica a carga de um tile (gzip) com o canto `(tx, ty)` em z[zoom]. Função pura: roda num `Isolate`.
BuildingTile decodeBuildingTile(Uint8List gz, List<String> types, int tx, int ty, int zoom, int firstIndex) {
  final body = Uint8List.fromList(gzip.decode(gz));
  var i = 0;
  int varint() {
    var v = 0, shift = 0;
    while (true) {
      if (i >= body.length) throw const FormatException('Tile de prédios cortado');
      final b = body[i++];
      v |= (b & 0x7f) << shift;
      if (b < 0x80) return v;
      shift += 7;
    }
  }

  int zz() {
    final v = varint();
    return (v >>> 1) ^ -(v & 1);
  }

  final span = (1 << (21 - zoom)) * _unit;
  final ox = tx * span, oy = ty * span;
  final buildings = <PackBuilding>[];
  var bytes = 0;
  var px = ox, py = oy;
  final count = varint();
  for (var k = 0; k < count; k++) {
    final type = types[varint()];
    final levels = body[i], flags = body[i + 1];
    i += 2;
    final n = varint();
    final xy = Float64List(n * 2);
    var x0 = 0, y0 = 0;
    for (var j = 0; j < n; j++) {
      px += zz();
      py += zz();
      if (j == 0) (x0, y0) = (px, py);
      xy[2 * j] = px / _unit;
      xy[2 * j + 1] = py / _unit;
    }
    (px, py) = (x0, y0);
    final b = PackBuilding(xy, type, levels, flags & 1 == 1, firstIndex + k);
    bytes += b.estimatedBytes;
    buildings.add(b);
  }
  final trees = <(double, double)>[];
  px = ox;
  py = oy;
  for (var n = varint(); n > 0; n--) {
    px += zz();
    py += zz();
    trees.add((px / _unit, py / _unit));
    bytes += 40;
  }
  return (buildings: buildings, trees: trees, bytes: bytes);
}

/// O arquivo `BLD2`: o índice na memória e os tiles sob demanda. [read] devolve `len` bytes a partir de `offset` (o asset
/// inteiro já na memória, ou um `RandomAccessFile` para o arquivo baixado). [decodeInBackground]: falso nos testes (decodifica
/// na hora, sem `Isolate`).
class BuildingPack implements BuildingSource {
  BuildingPack._(this.tileZoom, this.types, this._index, this._payload, this.read, this.decodeInBackground, this.maxBytes);

  /// Lê o cabeçalho e o índice. [head]: os primeiros bytes do arquivo (o bastante para o índice; [headerLength] diz quanto).
  factory BuildingPack.open(Uint8List head, Future<Uint8List> Function(int offset, int len) read, {bool decodeInBackground = true, int maxBytes = kBuildingCacheBytes}) {
    if (head.length < 5 || String.fromCharCodes(head.sublist(0, 4)) != 'BLD2') throw const FormatException('Arquivo de prédios sem o magic BLD2');
    var i = 4;
    final zoom = head[i++];
    int varint() {
      var v = 0, shift = 0;
      while (true) {
        final b = head[i++];
        v |= (b & 0x7f) << shift;
        if (b < 0x80) return v;
        shift += 7;
      }
    }

    final types = <String>[];
    for (var n = varint(); n > 0; n--) {
      final len = varint();
      types.add(utf8.decode(head.sublist(i, i + len)));
      i += len;
    }
    final view = ByteData.sublistView(head);
    final count = view.getUint32(i, Endian.little);
    i += 4;
    final index = <(int, int), (int, int, int)>{};
    for (var k = 0; k < count; k++) {
      final o = i + 20 * k;
      final len = view.getUint32(o + 12, Endian.little);
      if (len > kMaxBuildingTileBytes) throw FormatException('Tile de prédios grande demais: $len bytes');
      index[(view.getUint32(o, Endian.little), view.getUint32(o + 4, Endian.little))] = (view.getUint32(o + 8, Endian.little), len, view.getUint32(o + 16, Endian.little));
    }
    return BuildingPack._(zoom, types, index, i + 20 * count, read, decodeInBackground, maxBytes);
  }

  /// O arquivo inteiro na memória (o de Campinas no APK, e os testes).
  factory BuildingPack.fromBytes(Uint8List bytes, {bool decodeInBackground = true, int maxBytes = kBuildingCacheBytes}) =>
      BuildingPack.open(bytes, (o, l) async => Uint8List.sublistView(bytes, o, o + l), decodeInBackground: decodeInBackground, maxBytes: maxBytes);

  /// Quantos bytes do começo do arquivo [open] precisa (o cabeçalho e o índice): lê o bastante, olha aqui e lê o resto.
  static int headerLength(Uint8List firstBytes) {
    var i = 5;
    int varint() {
      var v = 0, shift = 0;
      while (true) {
        final b = firstBytes[i++];
        v |= (b & 0x7f) << shift;
        if (b < 0x80) return v;
        shift += 7;
      }
    }

    for (var n = varint(); n > 0; n--) {
      final len = varint(); // em duas linhas: `i += varint()` lê o `i` antes de a varint andar
      i += len;
    }
    return i + 4 + 20 * ByteData.sublistView(firstBytes).getUint32(i, Endian.little);
  }

  final int tileZoom;
  final List<String> types;
  final Map<(int, int), (int, int, int)> _index;
  final int _payload;
  final Future<Uint8List> Function(int offset, int len) read;
  final bool decodeInBackground;
  final int maxBytes;

  /// Os tiles prontos, do usado há mais tempo para o mais recente.
  final _tiles = <(int, int), BuildingTile>{};
  final _loading = <(int, int)>{};
  int _bytes = 0;
  int _revision = 0;

  @override
  int get buildingRevision => _revision;
  int get tileCount => _index.length;
  int get loadedTiles => _tiles.length;
  int get loadedBytes => _bytes;
  int get loadingTiles => _loading.length;

  /// Tempo da última carga de tile (ler e decodificar), em ms (debug).
  double lastLoadMs = 0;
  int loadsTotal = 0;

  int get _shift => 21 - tileZoom;
  (int, int) _tileOf(double x, double y) => (x.floor() >>> _shift, y.floor() >>> _shift);

  @override
  bool readyAt(double x, double y) {
    final k = _tileOf(x, y);
    return !_index.containsKey(k) || _tiles.containsKey(k);
  }

  /// Carrega todos os tiles (testes).
  Future<void> loadAll() => Future.wait([for (final k in _index.keys) _load(k)]);

  /// Carrega o tile `(tx, ty)` agora, sem `Isolate` (testes e o carregamento inicial).
  Future<void> load(int tx, int ty) => _load((tx, ty));

  Future<void> _load((int, int) k) async {
    final e = _index[k];
    if (e == null || _tiles.containsKey(k) || !_loading.add(k)) return;
    final sw = Stopwatch()..start();
    try {
      final gz = await read(_payload + e.$1, e.$2);
      final types = this.types, zoom = tileZoom;
      final tile = decodeInBackground ? await Isolate.run(() => decodeBuildingTile(gz, types, k.$1, k.$2, zoom, e.$3)) : decodeBuildingTile(gz, types, k.$1, k.$2, zoom, e.$3);
      _tiles[k] = tile;
      _bytes += tile.bytes;
      // O teto: descarta os tiles usados há mais tempo (nunca o que acabou de chegar).
      while (_bytes > maxBytes && _tiles.length > 1) {
        final old = _tiles.keys.first;
        _bytes -= _tiles.remove(old)!.bytes;
      }
      _revision++;
      loadsTotal++;
      lastLoadMs = sw.elapsedMicroseconds / 1000;
    } catch (_) {
      // Tile ruim: fica sem prédio.
    } finally {
      _loading.remove(k);
    }
  }

  BuildingTile? _use((int, int) k) {
    final t = _tiles.remove(k);
    if (t == null) {
      if (_index.containsKey(k)) _load(k);
      return null;
    }
    _tiles[k] = t; // o mais recente
    return t;
  }

  Iterable<BuildingTile> _tilesIn(double l, double t, double r, double b) sync* {
    final (x0, y0) = _tileOf(l, t);
    final (x1, y1) = _tileOf(r, b);
    if ((x1 - x0 + 1) * (y1 - y0 + 1) > _index.length) {
      // Retângulo maior que o arquivo: anda pelo índice, não por todas as casas vazias.
      for (final k in [..._index.keys]) {
        if (k.$1 < x0 || k.$1 > x1 || k.$2 < y0 || k.$2 > y1) continue;
        final tile = _use(k);
        if (tile != null) yield tile;
      }
      return;
    }
    for (var ty = y0; ty <= y1; ty++) {
      for (var tx = x0; tx <= x1; tx++) {
        final tile = _use((tx, ty));
        if (tile != null) yield tile;
      }
    }
  }

  @override
  Iterable<PackBuilding> buildingsIn(double l, double t, double r, double b, {double margin = 2}) sync* {
    for (final tile in _tilesIn(l - margin, t - margin, r + margin, b + margin)) {
      for (final p in tile.buildings) {
        final (cx, cy) = p.centroid;
        if (cx >= l - margin && cx <= r + margin && cy >= t - margin && cy <= b + margin) yield p;
      }
    }
  }

  @override
  Iterable<(double, double)> treesIn(double l, double t, double r, double b) sync* {
    for (final tile in _tilesIn(l, t, r, b)) {
      for (final p in tile.trees) {
        if (p.$1 >= l && p.$1 <= r && p.$2 >= t && p.$2 <= b) yield p;
      }
    }
  }
}
