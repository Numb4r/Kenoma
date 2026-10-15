/// Registro de fundador (só a coleta, sem assinatura ainda): um `player_id` aleatório de 128 bits gerado no
/// primeiro uso, a versão e o instante da primeira abertura e o log `versions_seen`, uma linha por versão
/// aberta, encadeado por hash: cada linha guarda o hash da anterior, então apagar ou mudar uma linha quebra
/// a cadeia. Dart puro; o gerador de bytes entra por parâmetro.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart' show sha256;

/// Hash de uma linha do log: `SHA-256("anterior|versão|utc|player_id")` em hexadecimal.
String chainHash({required String prev, required String version, required int utc, required String playerId}) =>
    sha256.convert(utf8.encode('$prev|$version|$utc|$playerId')).toString();

class VersionEntry {
  const VersionEntry({required this.version, required this.utc, required this.prev, required this.hash});

  factory VersionEntry.fromJson(Map<String, dynamic> j) =>
      VersionEntry(version: j['version'] as String, utc: j['utc'] as int, prev: j['prev'] as String, hash: j['hash'] as String);

  final String version;
  final int utc;
  final String prev;
  final String hash;

  Map<String, dynamic> toJson() => {'version': version, 'utc': utc, 'prev': prev, 'hash': hash};
}

class Founder {
  Founder({required this.playerId, required this.firstInstallVersion, required this.firstSeenUtc, List<VersionEntry>? versionsSeen})
      : versionsSeen = [...?versionsSeen];

  /// Primeira abertura: sorteia o `player_id` com [randomBytes] (o gerador seguro do sistema).
  factory Founder.create({required List<int> Function(int n) randomBytes, required String version, required int utc}) {
    final id = randomBytes(16).map((b) => (b & 0xff).toRadixString(16).padLeft(2, '0')).join();
    return Founder(playerId: id, firstInstallVersion: version, firstSeenUtc: utc)..noteVersion(version, utc);
  }

  factory Founder.fromJson(Map<String, dynamic> j) => Founder(
        playerId: j['player_id'] as String,
        firstInstallVersion: j['first_install_version'] as String,
        firstSeenUtc: j['first_seen_utc'] as int,
        versionsSeen: [for (final e in (j['versions_seen'] as List<dynamic>? ?? const [])) VersionEntry.fromJson(e as Map<String, dynamic>)],
      );

  /// 128 bits em 32 caracteres hexadecimais.
  final String playerId;
  final String firstInstallVersion;
  final int firstSeenUtc;
  final List<VersionEntry> versionsSeen;

  /// Anota a versão aberta agora. Só acrescenta se for diferente da última: uma linha por versão, não por abertura.
  bool noteVersion(String version, int utc) {
    if (versionsSeen.isNotEmpty && versionsSeen.last.version == version) return false;
    final prev = versionsSeen.isEmpty ? '' : versionsSeen.last.hash;
    versionsSeen.add(VersionEntry(version: version, utc: utc, prev: prev, hash: chainHash(prev: prev, version: version, utc: utc, playerId: playerId)));
    return true;
  }

  /// Se a cadeia está íntegra: cada linha aponta para o hash da anterior e o próprio hash confere.
  bool get chainValid {
    var prev = '';
    for (final e in versionsSeen) {
      if (e.prev != prev || e.hash != chainHash(prev: e.prev, version: e.version, utc: e.utc, playerId: playerId)) return false;
      prev = e.hash;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'player_id': playerId,
        'first_install_version': firstInstallVersion,
        'first_seen_utc': firstSeenUtc,
        'versions_seen': [for (final e in versionsSeen) e.toJson()],
      };
}
