/// O catálogo de pacotes baixáveis (`regions.json`, assinado) e a abertura dos arquivos de uma região. Quem manda é a época:
/// o catálogo só diz onde baixar; o SHA-256 que vale é o de `epochs.json` (CLAUDE.md, regra 8). Dart puro.
library;

import 'dart:io';
import 'dart:typed_data';

import '../core/epochs.dart';
import '../data/access_pack.dart';
import '../data/nowalk_pack.dart';
import '../data/relief_pack.dart';
import '../data/region_loader.dart' show sha256Hex;
import '../data/region_pack.dart';
import '../data/visual_pack.dart';
import '../world/layered_world.dart';
import 'feed_config.dart';
import 'signed_feed.dart' show verifySigned;

const String kKindLogic = 'logic', kKindVisual = 'visual', kKindNoWalk = 'nowalk', kKindRelief = 'relief';

/// O arquivo de rota (`_noaccess.bin`), em `route_files`: fora das épocas, vale o SHA-256 do catálogo assinado. Fica fora de
/// `files` porque a 0.16 exige que todo arquivo de lá esteja em `epochs.json` e recusaria a região inteira.
const String kKindAccess = 'access';

final _safeName = RegExp(r'^[A-Za-z0-9._-]+$');

class RegionFileRef {
  const RegionFileRef({required this.file, required this.url, required this.sha256, required this.bytes, required this.sig});

  factory RegionFileRef.fromJson(Map<String, dynamic> j) {
    final file = j['file'] as String;
    if (!_safeName.hasMatch(file) || file.startsWith('.')) throw FormatException('nome de arquivo inválido: $file');
    return RegionFileRef(file: file, url: j['url'] as String, sha256: (j['sha256'] as String).toLowerCase(), bytes: j['bytes'] as int, sig: j['sig'] as String);
  }

  final String file;
  final String url;
  final String sha256;
  final int bytes;

  /// Assinatura Ed25519 sobre os bytes do arquivo, 128 caracteres hex.
  final String sig;
}

class RegionEntry {
  const RegionEntry({required this.id, required this.name, required this.bbox, required this.epoch, required this.files, this.routeFiles = const {}});

  factory RegionEntry.fromJson(Map<String, dynamic> j) => RegionEntry(
        id: j['id'] as String,
        name: j['name'] as String,
        bbox: [for (final v in j['bbox'] as List<dynamic>) (v as num).toDouble()],
        epoch: j['epoch'] as int,
        files: {for (final e in (j['files'] as Map<String, dynamic>).entries) e.key: RegionFileRef.fromJson(e.value as Map<String, dynamic>)},
        routeFiles: {
          for (final e in ((j['route_files'] as Map<String, dynamic>?) ?? const {}).entries) e.key: RegionFileRef.fromJson(e.value as Map<String, dynamic>),
        },
      );

  final String id;
  final String name;

  /// Oeste, sul, leste, norte.
  final List<double> bbox;
  final int epoch;

  /// Por tipo: [kKindLogic], [kKindVisual] e [kKindNoWalk].
  final Map<String, RegionFileRef> files;

  /// O que só a rota lê: [kKindAccess]. Opcional, e fora de [totalBytes] e da época.
  final Map<String, RegionFileRef> routeFiles;

  int get totalBytes => files.values.fold(0, (sum, f) => sum + f.bytes);

  bool contains(double lat, double lon) => lon >= bbox[0] && lat >= bbox[1] && lon <= bbox[2] && lat <= bbox[3];
}

class RegionCatalog {
  const RegionCatalog(this.regions);

  factory RegionCatalog.fromJson(Map<String, dynamic> j) {
    if (j['format'] != 1) throw FormatException('formato de regions.json: ${j['format']}');
    return RegionCatalog([for (final r in j['regions'] as List<dynamic>) RegionEntry.fromJson(r as Map<String, dynamic>)]);
  }

  final List<RegionEntry> regions;
}

/// O que [epoch] fixa para o arquivo [kind] da região [id].
RegionPackRef? epochRefOf(Epoch epoch, String id, String kind) => switch (kind) {
      kKindLogic => epoch.regionPacks[id],
      kKindVisual => epoch.visualPacks[id],
      kKindNoWalk => epoch.walkable?.excludePacks[id],
      kKindRelief => epoch.reliefPacks[id],
      _ => null,
    };

/// A época vigente aceita o que o catálogo oferece: arquivos lógico e visual presentes, e cada um com o nome e o SHA-256 dela.
/// Sem isto nada é baixado.
bool catalogMatchesEpoch(RegionEntry r, Epoch epoch) {
  if (!r.files.containsKey(kKindLogic) || !r.files.containsKey(kKindVisual)) return false;
  return r.files.entries.every((e) {
    final ref = epochRefOf(epoch, r.id, e.key);
    return ref != null && ref.file == e.value.file && ref.sha256.toLowerCase() == e.value.sha256;
  });
}

/// Um arquivo a abrir. Com [sigHex] a assinatura é conferida também (recém-baixado); na reabertura basta o SHA-256 da época.
class RegionFileJob {
  const RegionFileJob({required this.kind, required this.path, required this.sha256, this.sigHex});

  final String kind;
  final String path;
  final String sha256;
  final String? sigHex;
}

class RegionOpen {
  const RegionOpen({this.region, this.error, this.bad = const []});

  final LoadedRegion? region;

  /// Em português, para o log; a tela só mostra um aviso curto.
  final String? error;

  /// Caminhos que não passaram: quem chamou apaga.
  final List<String> bad;
}

/// Lê e confere os arquivos da região [id] e monta os pacotes. Síncrono e pesado (SHA, Ed25519 e gunzip): roda em Isolate.
RegionOpen openRegionFiles(String id, List<RegionFileJob> jobs, {String publicKeyHex = kFeedPublicKeyHex}) {
  RegionPack? logic;
  VisualPack? visual;
  NoWalkPack? noWalk;
  ReliefPack? relief;
  for (final job in jobs) {
    RegionOpen fail(String why) => RegionOpen(error: '$id/${job.kind}: $why', bad: [job.path]);
    final Uint8List bytes;
    try {
      bytes = File(job.path).readAsBytesSync();
    } on FileSystemException catch (e) {
      return fail('não abriu: ${e.message}');
    }
    if (sha256Hex(bytes) != job.sha256.toLowerCase()) return fail('SHA-256 diferente do de epochs.json');
    final sig = job.sigHex;
    if (sig != null && !verifySigned(bytes, sig, publicKeyHex: publicKeyHex)) return fail('assinatura inválida');
    try {
      switch (job.kind) {
        case kKindLogic:
          logic = RegionPack.parse(bytes);
        case kKindVisual:
          visual = VisualPack.parse(bytes);
        case kKindNoWalk:
          noWalk = NoWalkPack.parse(bytes);
        case kKindRelief:
          relief = ReliefPack.parse(bytes);
      }
    } catch (e) {
      return fail('corrompido: $e');
    }
  }
  if (logic == null || visual == null) return RegionOpen(error: '$id: faltam arquivos');
  return RegionOpen(region: LoadedRegion(id: id, grid: logic, visual: visual, noWalk: noWalk, relief: relief));
}

/// Lê e confere o arquivo de rota: SHA-256 do catálogo e, recém-baixado, a assinatura. `null` se não confere. Roda em Isolate.
AccessPack? openAccessFile(RegionFileJob job, {String publicKeyHex = kFeedPublicKeyHex}) {
  try {
    final bytes = File(job.path).readAsBytesSync();
    if (sha256Hex(bytes) != job.sha256.toLowerCase()) return null;
    final sig = job.sigHex;
    if (sig != null && !verifySigned(bytes, sig, publicKeyHex: publicKeyHex)) return null;
    return AccessPack.parse(bytes);
  } catch (_) {
    return null;
  }
}

