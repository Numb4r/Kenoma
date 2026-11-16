import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Trava de release (0.20.4): uma época que usa um pacote baixável ainda não publicado (nem no APK, em `assets/regions/`,
/// nem no `docs/pages/regions.json` assinado) tem de começar daqui a pelo menos [minDays] dias. Assim a publicação não fica
/// para a véspera: o teste falha (e o build de release, que pede os testes passando) antes disso.
const int minDays = 7;

/// Os arquivos (nome e SHA-256) sem os quais a região não abre na época: o lógico, o visual e o de caminhos. O relevo e os
/// pontos do OSM são opcionais (sem eles a região abre plana e sem becos), então não travam: o relevo de São Paulo da época
/// 10 continua não publicado de propósito (`pipeline/README.md`).
Iterable<(String, String)> epochFiles(Map<String, dynamic> e) sync* {
  for (final key in ['region_packs', 'visual_packs']) {
    for (final ref in ((e[key] as Map<String, dynamic>?) ?? const {}).values) {
      yield ((ref as Map)['file'] as String, ref['sha256'] as String);
    }
  }
  for (final ref in (((e['walkable'] as Map<String, dynamic>?)?['exclude_packs'] as Map<String, dynamic>?) ?? const {}).values) {
    yield ((ref as Map)['file'] as String, ref['sha256'] as String);
  }
}

/// As épocas que começam em menos de [minDays] dias (ou já começaram) com algum pacote não publicado: `id: arquivos`.
List<String> unpublishedTooSoon(List<Map<String, dynamic>> epochs, {required bool Function(String file, String sha) published, required DateTime now}) => [
      for (final e in epochs)
        if (DateTime.parse(e['starts_utc'] as String).difference(now).inDays < minDays)
          if ([for (final (f, sha) in epochFiles(e)) if (!published(f, sha)) f] case final missing when missing.isNotEmpty) 'época ${e['id']}: ${missing.join(', ')}',
    ];

void main() {
  final epochs = ((jsonDecode(File('assets/data/epochs.json').readAsStringSync()) as Map)['epochs'] as List).cast<Map<String, dynamic>>();
  final catalog = jsonDecode(File('../docs/pages/regions.json').readAsStringSync()) as Map<String, dynamic>;
  final inCatalog = {
    for (final r in (catalog['regions'] as List).cast<Map<String, dynamic>>())
      for (final f in [...((r['files'] as Map?) ?? const {}).values, ...((r['route_files'] as Map?) ?? const {}).values]) ((f as Map)['file'] as String, (f['sha256'] as String).toLowerCase()),
  };
  bool published(String file, String sha) => File('assets/regions/$file').existsSync() || inCatalog.contains((file, sha.toLowerCase()));

  test('nenhuma época com pacote não publicado começa em menos de $minDays dias', () {
    expect(unpublishedTooSoon(epochs, published: published, now: DateTime.now().toUtc()), isEmpty,
        reason: 'publique o pacote (docs/assinatura.md) ou adie o starts_utc da época');
  });

  test('a trava pega a época 12 quando ela chega perto, e solta quando o pacote é publicado', () {
    final e12 = epochs.firstWhere((e) => e['id'] == 12);
    final start = DateTime.parse(e12['starts_utc'] as String);
    expect(unpublishedTooSoon([e12], published: published, now: start.subtract(const Duration(days: 8))), isEmpty);
    final soon = unpublishedTooSoon([e12], published: published, now: start.subtract(const Duration(days: 6)));
    expect(soon.single, 'época 12: sao_paulo_e12.bin');
    expect(unpublishedTooSoon([e12], published: published, now: start.add(const Duration(days: 1))), isNotEmpty, reason: 'já começou sem publicar');
    expect(unpublishedTooSoon([e12], published: (_, _) => true, now: start), isEmpty, reason: 'com tudo publicado, solta');
    expect(unpublishedTooSoon([epochs.firstWhere((e) => e['id'] == 11)], published: published, now: start), isEmpty, reason: 'a 11 só usa pacotes publicados');
  });
}
