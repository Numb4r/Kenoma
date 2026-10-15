/// Seção do menu de debug com a identidade e o save: player_id, registro de fundador, log de versões (com a
/// conferência da cadeia de hashes), época e cabeçalho do save. Lê o que está em disco, então funciona antes de
/// abrir o mapa. O menu de debug fica em toda build de teste (CLAUDE.md).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, rootBundle;
import 'dart:convert';

import '../core/epochs.dart';
import '../save/founder.dart';
import '../save/ksv_save_store.dart';
import '../save/migrations.dart';
import '../save/save_store.dart';
import '../ui/colors.dart';
import '../ui/tuning/tuning_screen.dart' show PixelButton;
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

class IdentitySection extends StatefulWidget {
  const IdentitySection({required this.clock, this.store, super.key});

  final GameClock clock;

  /// O save. Por padrão, o `save.ksv` nos documentos do app.
  final SaveStore? store;

  @override
  State<IdentitySection> createState() => _IdentitySectionState();
}

class _IdentitySectionState extends State<IdentitySection> {
  IdentityReport? _report;
  Epoch? _epoch;
  bool _stale = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final store = widget.store ?? await KsvSaveStore.inDocuments();
      final raw = await store.read();
      final epochs = EpochSchedule.fromJson(jsonDecode(await rootBundle.loadString('assets/data/epochs.json')) as Map<String, dynamic>);
      final sel = epochs.select(widget.clock.nowUtc);
      if (!mounted) return;
      setState(() {
        _report = IdentityReport.fromSave(raw, note: store.loadNote);
        _epoch = sel.epoch;
        _stale = sel.stale;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  static String _date(int utc) {
    final t = DateTime.fromMillisecondsSinceEpoch(utc * 1000, isUtc: true);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)} UTC';
  }

  @override
  Widget build(BuildContext context) {
    const small = TextStyle(fontSize: 8, color: kText, height: 1.8);
    final r = _report;
    final f = r?.founder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(padding: EdgeInsets.only(bottom: 12), child: Text('IDENTIDADE · SAVE', style: TextStyle(fontSize: 24, color: kVeil))),
        if (_error != null) Text('ERRO: $_error', style: const TextStyle(fontSize: 8, color: kEssence)),
        if (r == null && _error == null) const Text('LENDO O SAVE...', style: TextStyle(fontSize: 8, color: kDim)),
        if (r != null) ...[
          Text('ÉPOCA ${_epoch?.id ?? '?'}${_stale ? ' · MUNDO DESATUALIZADO' : ''} (RELÓGIO ${widget.clock.overridden ? 'SOBREPOSTO' : 'REAL'})', style: TextStyle(fontSize: 8, color: _stale ? kEssence : kSignal, height: 1.8)),
          if (_epoch != null) Text('VALE ${_date(_epoch!.startsUtc)} → ${_date(_epoch!.validUntilUtc)}', style: const TextStyle(fontSize: 8, color: kDim, height: 1.8)),
          if (r.note != null) Text(r.note!.toUpperCase(), style: const TextStyle(fontSize: 8, color: kEssence, height: 1.8)),
          if (f == null)
            const Text('SEM REGISTRO DE FUNDADOR: ABRA O MAPA UMA VEZ.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8))
          else ...[
            const SizedBox(height: 8),
            const Text('PLAYER_ID', style: TextStyle(fontSize: 8, color: kDim)),
            Text(f.playerId, key: const Key('debug-player-id'), style: small),
            Text('PRIMEIRA VERSÃO ${f.firstInstallVersion} · ${_date(f.firstSeenUtc)}', style: small),
            Text('GRUPO ${r.groupCode ?? '?'} · SCHEMA ${r.schemaVersion ?? '?'} · ÚLTIMA ABERTURA ${r.lastSeenUtc == null ? '?' : _date(r.lastSeenUtc!)}', style: small),
            const SizedBox(height: 8),
            Text('VERSIONS_SEEN · ${f.versionsSeen.length} · CADEIA ${r.chainValid ? 'ÍNTEGRA' : 'QUEBRADA'}', style: TextStyle(fontSize: 8, color: r.chainValid ? kSignal : kEssence, height: 1.8)),
            for (final e in f.versionsSeen) Text('${e.version} · ${_date(e.utc)} · ${e.hash.substring(0, 12)}', style: small),
            const SizedBox(height: 8),
            PixelButton(
              label: 'Copiar player_id',
              color: kVeil,
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: f.playerId));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('player_id copiado')));
              },
            ),
          ],
          const SizedBox(height: 8),
          PixelButton(label: 'Reler o save', color: kDim, onTap: _load),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}
