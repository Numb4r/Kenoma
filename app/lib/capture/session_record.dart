/// Uma linha do registro de sessões de sintonia, para analisar o balanceamento jogando.
library;

import 'eco_type.dart';
import 'session.dart';
import 'tuning_balance.dart';
import 'tuning_setup.dart';

class SessionRecord {
  const SessionRecord({
    required this.timeUtc,
    required this.type,
    required this.ecoLevel,
    required this.playerLevel,
    required this.sealId,
    required this.tonic,
    required this.tolerance,
    required this.resistance,
    required this.durationS,
    required this.success,
    required this.alignedTimeS,
    required this.alignmentLosses,
    required this.balanceVersion,
    this.hiddenType = false,
    this.guessCorrect,
  });

  /// Registro de uma sintonia terminada. [guessCorrect] só existe no modo de tipo oculto.
  factory SessionRecord.of({
    required TuningSetup setup,
    required TuningSession session,
    required TuningBalance balance,
    required DateTime at,
    required String balanceVersion,
    bool hiddenType = false,
    bool? guessCorrect,
  }) =>
      SessionRecord(
        timeUtc: at.toUtc(),
        type: setup.type,
        ecoLevel: setup.ecoLevel,
        playerLevel: setup.playerLevel,
        sealId: setup.seal.id,
        tonic: setup.tonic != null,
        tolerance: setup.tolerance(balance),
        resistance: setup.intensity(balance),
        durationS: session.t,
        success: session.phase == TuningPhase.success,
        alignedTimeS: session.alignedTimeS,
        alignmentLosses: session.alignmentLosses,
        balanceVersion: balanceVersion,
        hiddenType: hiddenType,
        guessCorrect: guessCorrect,
      );

  static const List<String> columns = [
    'timestamp_utc',
    'type',
    'eco_level',
    'player_level',
    'seal',
    'tonic',
    'tolerance',
    'resistance',
    'duration_s',
    'result',
    'aligned_s',
    'alignment_losses',
    'hidden_type',
    'guess_correct',
    'balance_version',
  ];

  static String get header => columns.join(',');

  /// Cabeçalho do formato anterior, sem `balance_version`. Arquivos nesse formato são migrados.
  static String get legacyHeader => columns.take(columns.length - 1).join(',');

  /// Versão gravada nas linhas que já existiam quando a coluna foi criada.
  static const String legacyBalanceVersion = 'pre-ajuste';

  final DateTime timeUtc;
  final EcoType type;
  final int ecoLevel;
  final int playerLevel;
  final String sealId;
  final bool tonic;

  /// Tolerância inicial da sintonia (selo e bônus), antes de a Planta encolhê-la.
  final double tolerance;
  final double resistance;
  final double durationS;
  final bool success;
  final double alignedTimeS;
  final int alignmentLosses;

  /// Versão do balanceamento com que a sintonia foi jogada (ver `balanceVersionOf`).
  final String balanceVersion;
  final bool hiddenType;

  /// No modo de tipo oculto, se o jogador acertou o tipo. `null` se não marcou ou fora do modo.
  final bool? guessCorrect;

  String toCsvLine() => [
        timeUtc.toIso8601String(),
        type.name,
        '$ecoLevel',
        '$playerLevel',
        sealId,
        tonic ? '1' : '0',
        tolerance.toStringAsFixed(3),
        resistance.toStringAsFixed(3),
        durationS.toStringAsFixed(2),
        success ? 'success' : 'fail',
        alignedTimeS.toStringAsFixed(2),
        '$alignmentLosses',
        hiddenType ? '1' : '0',
        guessCorrect == null ? '' : (guessCorrect! ? '1' : '0'),
        balanceVersion,
      ].map(_escape).join(',');
}

/// Aspas em volta do campo se ele tiver vírgula, aspas ou quebra de linha.
String _escape(String field) =>
    field.contains(RegExp(r'[",\n\r]')) ? '"${field.replaceAll('"', '""')}"' : field;
