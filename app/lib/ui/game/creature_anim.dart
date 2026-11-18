/// As animações das criaturas no mapa (0.25.0, docs/art/estilo-criaturas.md): qual animação vale agora, qual quadro dela
/// e quando os LEDs estão acesos. Dart puro; o desenho é de `creature_art.dart` e do `spawn_painter.dart`.
library;

import '../../core/fnv.dart';

/// As animações que toda criatura tem no mapa (o Humoth fixou a lista).
enum CreatureAnim { idle, drift, alert, flee, spawn, tuned }

/// A animação de uma criatura parada no mundo: nascendo ([appear] < 1) ganha de tudo; com o jogador ao alcance, alerta;
/// andando, deriva; senão, parada. Fuga e sintonia são saídas, desenhadas pelo `Fx`.
CreatureAnim animOf({required double appear, required bool alert, required bool moving}) =>
    appear < 1 ? CreatureAnim.spawn : (alert ? CreatureAnim.alert : (moving ? CreatureAnim.drift : CreatureAnim.idle));

/// O quadro de uma animação em laço a [fps], com a fase própria de [uid] (duas criaturas lado a lado não batem as asas
/// juntas).
int loopFrame(double t, int frames, double fps, {int uid = 0}) {
  if (frames <= 1) return 0;
  final phase = (fnv1a64([uid, 0x50484153]) >>> 40) % 1000 / 1000;
  return ((t * fps + phase * frames).floor() % frames + frames) % frames;
}

/// O quadro de uma animação que corre uma vez: [progress] de 0 a 1.
int onceFrame(double progress, int frames) => (progress.clamp(0.0, 0.9999) * frames).floor();

/// Os ocelos de LED de [uid] em [t]: piscam num ritmo próprio, fora de fase com as asas, como letreiro com mau contato
/// (acesos a maior parte do tempo, com apagões curtos e uma tremida de vez em quando). [fixed]: acesos fixos (alerta,
/// sinal travado).
bool ledLit(int uid, double t, {bool fixed = false}) {
  if (fixed) return true;
  // Um "ciclo" de 1,7 s com a fase do uid: aceso 75% dele; no resto, apagado ou tremendo.
  final cycle = 1.7, base = (fnv1a64([uid, 0x4c4544]) >>> 40) % 1000 / 1000 * cycle;
  final k = ((t + base) / cycle).floor(), u = ((t + base) % cycle) / cycle;
  final h = fnv1a64([uid, k, 0x6d6175]) >>> 40;
  if (u < 0.75) {
    // Mau contato: às vezes uma tremida curta no meio do aceso.
    if (h % 4 == 0 && u > 0.40 && u < 0.46) return ((t * 30).floor()).isEven;
    return true;
  }
  return h % 3 == 0 && u > 0.9; // apagado, com uma volta rápida antes de acender de novo
}

/// O brilho animado do Brilhante (o único com brilho que se move): de 0 a 1, uma faixa que passa pelo corpo.
double creatureShine(int uid, double t) {
  final p = ((t * 0.8 + (fnv1a64([uid, 0x5348]) >>> 40) % 100 / 100) % 1.0);
  return p < 0.35 ? p / 0.35 : (p < 0.5 ? 1 - (p - 0.35) / 0.15 : 0);
}
