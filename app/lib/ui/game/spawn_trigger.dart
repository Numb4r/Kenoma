/// De onde a criatura nasce no desenho (0.25.1, GDD: o Humoth "nasce onde o raio cai"). Só desenho: o Eco continua no
/// ponto que a seed deu, igual para os amigos; o gatilho escolhe o efeito que acompanha a animação `spawn` (o raio que
/// cai nele, as faíscas que saem do poste mais perto, a poça que ondula, o chão que se revira, a neblina que se junta).
/// A escolha é Dart puro e testável; o desenho fica em [paintSpawnTrigger].
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/fnv.dart';

enum SpawnTriggerKind { lightning, lamp, puddle, ground, fog }

class SpawnTrigger {
  const SpawnTrigger(this.kind, [this.origin]);

  final SpawnTriggerKind kind;

  /// O poste de onde saem as faíscas (células z21). Só no [SpawnTriggerKind.lamp].
  final (double, double)? origin;

  @override
  bool operator ==(Object other) => other is SpawnTrigger && other.kind == kind && other.origin == origin;

  @override
  int get hashCode => Object.hash(kind, origin);
}

/// O gatilho de uma criatura cujo `spawn` no `index.json` é [spec], com o clima mostrado [climateId]. [climates] diz quais
/// climas contam como raio, poça e neblina (`index.json`, `climates`). [lamp]: o poste mais perto dentro do alcance, se
/// houver. Sem gatilho que valha agora: `null` (nasce onde o Eco aparece, como sempre).
SpawnTrigger? resolveSpawnTrigger(String? spec, {required String climateId, required bool night, required Map<String, Set<String>> climates, (double, double)? lamp}) {
  bool on(String k) => climates[k]?.contains(climateId) ?? false;
  return switch (spec) {
    'lightning_lamp' when on('lightning') => const SpawnTrigger(SpawnTriggerKind.lightning),
    'lightning_lamp' when night && lamp != null => SpawnTrigger(SpawnTriggerKind.lamp, lamp),
    'puddle' when on('puddle') => const SpawnTrigger(SpawnTriggerKind.puddle),
    'ground' => const SpawnTrigger(SpawnTriggerKind.ground),
    'fog' when on('fog') => const SpawnTrigger(SpawnTriggerKind.fog),
    _ => null,
  };
}

/// O ponto de [points] mais perto de ([x], [y]) dentro de [maxCells], ou `null`.
(double, double)? nearestPoint(Iterable<(double, double)> points, double x, double y, double maxCells) {
  (double, double)? best;
  var bd = maxCells * maxCells;
  for (final p in points) {
    final d = (p.$1 - x) * (p.$1 - x) + (p.$2 - y) * (p.$2 - y);
    if (d <= bd) {
      bd = d;
      best = p;
    }
  }
  return best;
}

const _yellow = ui.Color(0xFFFFD84A), _pale = ui.Color(0xFFFFF3A8), _white = ui.Color(0xFFFFFFFF);
const _water = ui.Color(0xFF8FD3FF), _earth = ui.Color(0xFF6B5A44), _earthDark = ui.Color(0xFF3B2F28), _mist = ui.Color(0xFFE8E4F4);

/// Desenha o gatilho [t] da criatura em [c] (centro do sprite de [size] px), com a abertura [appear] de 0 a 1. [origin]
/// é o poste na tela. [behind]: a parte que fica por baixo do corpo (poça, chão); senão a de cima (raio, faíscas,
/// neblina), que o mapa põe na camada emissiva quando acende.
void paintSpawnTrigger(ui.Canvas canvas, SpawnTrigger t, ui.Offset c, double appear, double size, int uid, {ui.Offset? origin, required bool behind}) {
  final px = size / 28; // o pixel de arte do Eco
  final feet = c.translate(0, size * 0.42);
  final p = ui.Paint()..isAntiAlias = false;
  void block(ui.Offset o, ui.Color col, [double k = 1]) => canvas.drawRect(ui.Rect.fromCenter(center: o, width: px * k, height: px * k), p..color = col);
  double r(int i) => ((fnv1a64([uid, i, 0x545247]) >>> 40) % 1000) / 1000;

  switch ((t.kind, behind)) {
    case (SpawnTriggerKind.lightning, false):
      // O raio cai na criatura no começo (35% da abertura) e deixa o chão aceso.
      if (appear < 0.35) {
        final a = 1 - appear / 0.35;
        final top = math.max(0.0, c.dy - size * 9);
        final path = ui.Path()..moveTo(c.dx + (r(0) - 0.5) * size, top);
        for (var i = 1; i <= 7; i++) {
          final y = top + (feet.dy - top) * i / 7;
          path.lineTo(c.dx + (r(i) - 0.5) * size * 0.8 * (1 - i / 7), y);
        }
        canvas.drawPath(path, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = px * 3..color = _yellow.withValues(alpha: a * 0.7)..isAntiAlias = false);
        canvas.drawPath(path, ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = px..color = _white.withValues(alpha: a)..isAntiAlias = false);
      }
      if (appear < 0.6) {
        final k = appear / 0.6;
        canvas.drawOval(ui.Rect.fromCenter(center: feet, width: size * (0.4 + k), height: size * (0.14 + k * 0.3)),
            ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = px..color = _pale.withValues(alpha: 1 - k)..isAntiAlias = false);
      }
    case (SpawnTriggerKind.lamp, false):
      // As faíscas saem da cabeça do poste e chegam juntas no centro antes de a silhueta aparecer (metade da abertura).
      final o = origin;
      if (o == null) return;
      if (appear < 0.15) block(o, _white.withValues(alpha: 1 - appear / 0.15), 3);
      for (var i = 0; i < 6; i++) {
        final k = ((appear - i * 0.05) / 0.45).clamp(0.0, 1.0);
        if (k <= 0 || k >= 1) continue;
        final arc = math.sin(k * math.pi) * size * (0.4 + r(10 + i) * 0.6);
        final pt = ui.Offset.lerp(o, c, k)!.translate(0, -arc);
        block(pt, i.isEven ? _yellow : _pale, k < 0.8 ? 2 : 1);
      }
    case (SpawnTriggerKind.puddle, true):
      // A poça ondula embaixo dela: dois anéis que abrem e somem.
      for (var i = 0; i < 2; i++) {
        final k = (appear * 1.3 - i * 0.3).clamp(0.0, 1.0);
        if (k <= 0 || k >= 1) continue;
        canvas.drawOval(ui.Rect.fromCenter(center: feet, width: size * (0.3 + k * 0.9), height: size * (0.1 + k * 0.3)),
            ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = px..color = _water.withValues(alpha: (1 - k) * 0.9)..isAntiAlias = false);
      }
    case (SpawnTriggerKind.ground, true):
      // O chão se revira: um monte escuro que baixa e torrões jogados para os lados.
      final k = appear.clamp(0.0, 1.0);
      canvas.drawOval(ui.Rect.fromCenter(center: feet, width: size * 0.7, height: size * 0.2), p..color = _earthDark.withValues(alpha: 1 - k));
      for (var i = 0; i < 6; i++) {
        final dir = (i / 6 + r(20 + i) * 0.1) * 2 * math.pi;
        final dist = size * (0.25 + 0.4 * k) * (0.6 + r(30 + i) * 0.4);
        final up = math.sin(k * math.pi) * size * 0.35;
        if (k >= 1) continue;
        block(feet + ui.Offset(math.cos(dir) * dist, math.sin(dir) * dist * 0.4 - up), i.isEven ? _earth : _earthDark, 2);
      }
    case (SpawnTriggerKind.fog, false):
      // A neblina se junta nela: fiapos claros que vêm de fora e somem quando o corpo fecha.
      for (var i = 0; i < 8; i++) {
        final dir = i / 8 * 2 * math.pi + r(40 + i);
        final k = appear.clamp(0.0, 1.0);
        final dist = size * (1.1 - k) * (0.7 + r(50 + i) * 0.5);
        block(c + ui.Offset(math.cos(dir) * dist, math.sin(dir) * dist * 0.6), _mist.withValues(alpha: (1 - k) * 0.55), 3);
      }
    default:
  }
}
