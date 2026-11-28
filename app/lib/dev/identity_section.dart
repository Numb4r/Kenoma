/// A identidade e o save para a aba Sistema do debug: player_id, registro de fundador, log de versões (com a conferência
/// da cadeia de hashes), época e cabeçalho do save. Lê o que está em disco, então funciona antes de abrir o mapa.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:convert';

import '../core/epochs.dart';
import '../save/founder.dart';
import '../save/ksv_save_store.dart';
import '../save/migrations.dart';
import '../save/save_store.dart';
import '../ui/tema.dart';
import 'game_clock.dart';

/// O que a seção mostra, tirado do JSON do save. Separado da tela para poder testar.
class IdentityReport {
  const IdentityReport({
    required this.founder,
    required this.chainValid,
    required this.savedEpoch,
    required this.appVersion,
    required this.schemaVersion,
    required this.lastSeenUtc,
    required this.groupCode,
    this.note,
  });

  factory IdentityReport.fromSave(Map<String, dynamic>? raw, {String? note}) {
    final j = raw == null ? null : migrateSave(raw);
    final founder = j?['founder'] == null ? null : Founder.fromJson(j!['founder'] as Map<String, dynamic>);
    return IdentityReport(
      founder: founder,
      chainValid: founder?.chainValid ?? false,
      savedEpoch: j?['epoch'] as int?,
      appVersion: j?['app_version'] as String?,
      schemaVersion: j?['schema_version'] as int?,
      lastSeenUtc: j?['last_seen_utc'] as int?,
      groupCode: j?['group_code'] as String?,
      note: note,
    );
  }

  final Founder? founder;
  final bool chainValid;
  final int? savedEpoch;
  final String? appVersion;
  final int? schemaVersion;
  final int? lastSeenUtc;
  final String? groupCode;
  final String? note;
}

/// O que a entrada `system.identity` mostra: o relatório do save, a época de agora e se o mundo está desatualizado.
class IdentityInfo {
  const IdentityInfo({required this.report, required this.epoch, required this.stale, required this.clockForced});

  final IdentityReport report;
  final Epoch? epoch;
  final bool stale;
  final bool clockForced;

  /// O resumo de uma linha (o `cmd` e a tela).
  String get line {
    final f = report.founder;
    return [
      'época ${epoch?.id ?? '?'}${stale ? ' (mundo desatualizado)' : ''}${clockForced ? ' · relógio forçado' : ''}',
      if (f == null) 'sem fundador (abra o mapa)' else 'player_id ${f.playerId.substring(0, 8)}…',
      'schema ${report.schemaVersion ?? '?'}',
      if (f != null) '${f.versionsSeen.length} versões · cadeia ${report.chainValid ? 'íntegra' : 'QUEBRADA'}',
      if (report.note != null) report.note!,
    ].join(' · ');
  }

  /// O resumo em linhas de rótulo e valor (a entrada `system.identity`).
  List<({String title, List<(String, String)> rows})> get groups {
    final f = report.founder;
    return [
      (
        title: 'Identidade',
        rows: [
          ('Época', '${epoch?.id ?? '?'}${stale ? ' (mundo desatualizado)' : ''}${clockForced ? ' · relógio forçado' : ''}'),
          ('player_id', f == null ? 'sem fundador (abra o mapa)' : '${f.playerId.substring(0, 8)}…'),
          ('Schema', '${report.schemaVersion ?? '?'}'),
          if (f != null) ('Versões', '${f.versionsSeen.length} · cadeia ${report.chainValid ? 'íntegra' : 'QUEBRADA'}'),
          if (report.note != null) ('Nota', report.note!),
        ],
      ),
    ];
  }

  /// O que o botão de copiar leva: o resumo com o player_id inteiro, o grupo e o log de versões.
  String get full {
    final f = report.founder;
    return [
      line,
      if (f != null) 'player_id ${f.playerId}',
      if (f != null) 'primeira versão ${f.firstInstallVersion} · ${utcDate(f.firstSeenUtc)}',
      'grupo ${report.groupCode ?? '?'} · última abertura ${report.lastSeenUtc == null ? '?' : utcDate(report.lastSeenUtc!)}',
      if (epoch != null) 'época vale ${utcDate(epoch!.startsUtc)} → ${utcDate(epoch!.validUntilUtc)}',
      for (final e in f?.versionsSeen ?? const <VersionEntry>[]) '${e.version} · ${utcDate(e.utc)} · ${e.hash.substring(0, 12)}',
    ].join('\n');
  }
}

String utcDate(int utc) {
  final t = DateTime.fromMillisecondsSinceEpoch(utc * 1000, isUtc: true);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)} UTC';
}

/// Lê o save de [store] (ou o do app) e as épocas, no relógio de [clock].
Future<IdentityInfo> readIdentity(GameClock clock, {SaveStore? store}) async {
  final s = store ?? await KsvSaveStore.inDocuments();
  final raw = await s.read();
  final epochs = EpochSchedule.fromJson(jsonDecode(await rootBundle.loadString('assets/data/epochs.json')) as Map<String, dynamic>);
  final sel = epochs.select(clock.nowUtc);
  return IdentityInfo(report: IdentityReport.fromSave(raw, note: s.loadNote), epoch: sel.epoch, stale: sel.stale, clockForced: clock.overridden);
}

/// O log de versões e o resto do registro, recolhido até tocar (só leitura).
class IdentityDetails extends StatefulWidget {
  const IdentityDetails({required this.info, super.key});

  final IdentityInfo? info;

  @override
  State<IdentityDetails> createState() => _IdentityDetailsState();
}

class _IdentityDetailsState extends State<IdentityDetails> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final info = widget.info;
    if (info == null) return const SizedBox.shrink();
    final n = info.report.founder?.versionsSeen.length ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      GestureDetector(
        key: const Key('identity-details'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _open = !_open),
        child: SizedBox(
          height: kToqueMinDp,
          child: Row(children: [
            Icon(_open ? Icons.expand_less : Icons.expand_more, color: KCores.textoMudo),
            Text('VERSIONS_SEEN · $n', style: KTexto.rotulo.copyWith(color: KCores.textoMudo)),
          ]),
        ),
      ),
      if (_open) SelectableText(info.full, style: KTexto.corpoPequeno),
    ]);
  }
}
