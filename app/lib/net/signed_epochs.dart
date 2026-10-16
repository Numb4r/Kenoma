/// O que o feed assinado pode fazer com as épocas (CLAUDE.md, regra 8): acrescentar épocas NOVAS (id maior que o maior
/// id embutido) e ESTENDER o `valid_until_utc` de uma época existente com conteúdo idêntico. Qualquer outra mudança em
/// época já publicada rejeita o arquivo inteiro (lança [FormatException]).
library;

import '../core/epochs.dart';

/// Funde [signed] (já com assinatura conferida) em [bundled] (o `epochs.json` do app, JSON cru) e devolve o JSON
/// resultante. [hasPack] diz se um arquivo de pacote existe nos assets do app; épocas novas que exigem um pacote
/// ausente são ignoradas (sem [hasPack], todas valem).
Map<String, dynamic> mergeSignedJson(Map<String, dynamic> bundled, Map<String, dynamic> signed, {bool Function(String file)? hasPack}) {
  final base = <int, Map<String, dynamic>>{
    for (final e in bundled['epochs'] as List<dynamic>) (e as Map<String, dynamic>)['id'] as int: e,
  };
  final maxId = base.keys.reduce((a, b) => a > b ? a : b);
  final out = {...base};
  for (final raw in signed['epochs'] as List<dynamic>) {
    final e = raw as Map<String, dynamic>;
    final id = e['id'] as int;
    final old = base[id];
    if (old != null) {
      if (!_same(old, e, skip: 'valid_until_utc')) throw FormatException('o feed altera o conteúdo da época $id');
      final until = DateTime.parse(e['valid_until_utc'] as String);
      final oldUntil = DateTime.parse(old['valid_until_utc'] as String);
      if (!until.isUtc) throw const FormatException('valid_until_utc sem Z');
      if (until.isBefore(oldUntil)) throw FormatException('o feed encurta a época $id');
      out[id] = e;
    } else if (id > maxId) {
      Epoch.fromJson(e); // lança se estiver malformada; a época inteira do feed é rejeitada
      if (hasPack == null || _packFiles(e).every(hasPack)) out[id] = e;
    } else {
      throw FormatException('o feed traz a época $id, que não existe no app');
    }
  }
  final ids = out.keys.toList()..sort();
  return {...bundled, 'epochs': [for (final i in ids) out[i]]};
}

/// Versão sobre [EpochSchedule]: [bundled] precisa ter vindo de `EpochSchedule.fromJson` (guarda o JSON cru).
EpochSchedule mergeSigned(EpochSchedule bundled, Map<String, dynamic> signedJson, {bool Function(String file)? hasPack}) {
  final src = bundled.source;
  if (src == null) throw ArgumentError('EpochSchedule sem JSON de origem');
  return EpochSchedule.fromJson(mergeSignedJson(src, signedJson, hasPack: hasPack));
}

/// Os arquivos de pacote (`assets/regions/`) que uma época do JSON exige.
List<String> epochPackFiles(Map<String, dynamic> epoch) => _packFiles(epoch);

List<String> _packFiles(Map<String, dynamic> e) => [
      for (final k in ['region_packs', 'visual_packs'])
        for (final v in ((e[k] as Map<String, dynamic>?) ?? const {}).values) (v as Map<String, dynamic>)['file'] as String,
      if ((e['walkable'] as Map<String, dynamic>?)?['exclude_pack'] != null) ((e['walkable'] as Map<String, dynamic>)['exclude_pack'] as Map<String, dynamic>)['file'] as String,
    ];

bool _same(Object? a, Object? b, {String? skip}) {
  if (a is Map && b is Map) {
    final ka = a.keys.where((k) => k != skip).toSet(), kb = b.keys.where((k) => k != skip).toSet();
    return ka.length == kb.length && ka.every((k) => kb.contains(k) && _same(a[k], b[k]));
  }
  if (a is List && b is List) return a.length == b.length && [for (var i = 0; i < a.length; i++) _same(a[i], b[i])].every((x) => x);
  return a == b;
}
