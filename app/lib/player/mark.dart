/// Marcação: o toque longo num Eco dentro da Aura prende o sinal dele (docs/fase0-spec.md, seção 5). O Eco
/// marcado pode ser sintonizado de qualquer lugar, mesmo depois que a janela do spawn acabar, com o nível
/// que já tinha. Dart puro.
library;

import '../core/behavior.dart';
import '../world/spawn_field.dart';

class Mark {
  const Mark({
    required this.uid,
    required this.speciesId,
    required this.level,
    required this.x,
    required this.y,
    required this.cellX,
    required this.cellY,
    required this.window,
    required this.markedUtc,
    required this.expiresUtc,
    this.personal = false,
    this.hidden = false,
  });

  factory Mark.of(WorldSpawn eco, {required int nowUtc, required int durationS}) => Mark(
        uid: eco.uid.toString(),
        speciesId: eco.entryId,
        level: eco.level ?? 1,
        x: eco.x,
        y: eco.y,
        cellX: eco.cellX,
        cellY: eco.cellY,
        window: eco.window,
        markedUtc: nowUtc,
        expiresUtc: nowUtc + durationS,
        personal: eco.personal,
        hidden: eco.behavior == EcoBehavior.hidden,
      );

  factory Mark.fromJson(Map<String, dynamic> j) => Mark(
        uid: j['uid'] as String,
        speciesId: j['species'] as String,
        level: j['level'] as int,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        cellX: j['cell_x'] as int,
        cellY: j['cell_y'] as int,
        window: j['window'] as int,
        markedUtc: j['marked_utc'] as int,
        expiresUtc: j['expires_utc'] as int,
        personal: (j['personal'] as bool?) ?? false,
        hidden: (j['hidden'] as bool?) ?? false,
      );

  /// Uid do spawn, em texto (como na coleção).
  final String uid;
  final String speciesId;
  final int level;

  /// Posição do Eco em células z21 fracionárias, e a célula e a janela de onde veio.
  final double x;
  final double y;
  final int cellX;
  final int cellY;
  final int window;
  final int markedUtc;
  final int expiresUtc;

  /// O Eco veio da camada pessoal / era Oculto (a origem vai junto até a captura).
  final bool personal;
  final bool hidden;

  bool activeAt(int nowUtc) => nowUtc < expiresUtc;

  int secondsLeft(int nowUtc) => (expiresUtc - nowUtc).clamp(0, 1 << 30);

  /// O spawn de onde a marcação veio, para abrir o encontro.
  WorldSpawn toSpawn() => WorldSpawn(
        uid: int.parse(uid),
        kind: 'eco',
        entryId: speciesId,
        quantity: 1,
        x: x,
        y: y,
        cellX: cellX,
        cellY: cellY,
        window: window,
        level: level,
        behavior: hidden ? EcoBehavior.hidden : EcoBehavior.passive,
        personal: personal,
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'species': speciesId,
        'level': level,
        'x': x,
        'y': y,
        'cell_x': cellX,
        'cell_y': cellY,
        'window': window,
        'marked_utc': markedUtc,
        'expires_utc': expiresUtc,
        if (personal) 'personal': true,
        if (hidden) 'hidden': true,
      };
}
