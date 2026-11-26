/// De onde a criatura nasce no desenho (0.25.1, GDD: o Humoth "nasce onde o raio cai"). Só desenho: o Eco continua no
/// ponto que a seed deu, igual para os amigos; o gatilho escolhe o efeito que acompanha a animação `spawn` (o raio que
/// cai nele, as faíscas que saem do poste mais perto, a poça que ondula, o chão que se revira, a neblina que se junta;
/// 0.26.0: o bueiro do Soot, a rachadura da calçada do Frond, a cratera de meteoro e o asfalto rachado do Wyrm; depois,
/// decisão do dono pela coluna "Onde e quando" do GDD: o clarão na vitrine ou a faixa do arco-íris da Glare, o letreiro em
/// estática da Bit, a grade que range da Rust e o redemoinho de folhas secas da Sprig).
/// A escolha é Dart puro e testável; o desenho fica em [paintSpawnTrigger].
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../../core/fnv.dart';

enum SpawnTriggerKind { lightning, lamp, puddle, ground, fog, manhole, crack, crater, emberCrack, glint, rainbow, staticSign, grate, whirl, whirlPollen }

class SpawnTrigger {
  const SpawnTrigger(this.kind, [this.origin]);

  final SpawnTriggerKind kind;

  /// O poste de onde saem as faíscas, ou o letreiro que entra em estática (células z21). Só no [SpawnTriggerKind.lamp] e no
  /// [SpawnTriggerKind.staticSign] (sem letreiro perto, a estática acende em cima da criatura).
  final (double, double)? origin;

  @override
  bool operator ==(Object other) => other is SpawnTrigger && other.kind == kind && other.origin == origin;

  @override
  int get hashCode => Object.hash(kind, origin);
}

/// O gatilho de uma criatura cujo `spawn` no `index.json` é [spec], com o clima mostrado [climateId]. [climates] diz quais
/// climas contam como raio, poça e neblina (`index.json`, `climates`). [lamp]: o poste mais perto dentro do alcance, se
/// houver. [sign]: o letreiro, a placa ou o painel mais perto. [rainbow]: um arco-íris à vista. [twilight]: o sol a menos
/// de 6° do horizonte (o crepúsculo real do GDD). Sem gatilho que valha agora: `null` (nasce onde o Eco aparece, como sempre).
SpawnTrigger? resolveSpawnTrigger(String? spec,
    {required String climateId, required bool night, required Map<String, Set<String>> climates, (double, double)? lamp, (double, double)? sign, bool rainbow = false, bool twilight = false}) {
  bool on(String k) => climates[k]?.contains(climateId) ?? false;
  return switch (spec) {
    'lightning_lamp' when on('lightning') => const SpawnTrigger(SpawnTriggerKind.lightning),
    'lightning_lamp' when night && lamp != null => SpawnTrigger(SpawnTriggerKind.lamp, lamp),
    'puddle' when on('puddle') => const SpawnTrigger(SpawnTriggerKind.puddle),
    'ground' => const SpawnTrigger(SpawnTriggerKind.ground),
    'fog' when on('fog') => const SpawnTrigger(SpawnTriggerKind.fog),
    'manhole' => const SpawnTrigger(SpawnTriggerKind.manhole),
    'crack' => const SpawnTrigger(SpawnTriggerKind.crack),
    'crater_crack' when on('crater') => const SpawnTrigger(SpawnTriggerKind.crater),
    'crater_crack' => const SpawnTrigger(SpawnTriggerKind.emberCrack),
    'glint_rainbow' when rainbow => const SpawnTrigger(SpawnTriggerKind.rainbow),
    'glint_rainbow' when !night => const SpawnTrigger(SpawnTriggerKind.glint),
    'static_sign' => SpawnTrigger(SpawnTriggerKind.staticSign, sign),
    'grate' => const SpawnTrigger(SpawnTriggerKind.grate),
    'whirl' when twilight => const SpawnTrigger(SpawnTriggerKind.whirlPollen),
    'whirl' => const SpawnTrigger(SpawnTriggerKind.whirl),
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
// 0.26.0, cores do criativo (docs/art/estilo-criaturas.md, "No app"): bueiro, calçada, cratera e asfalto.
const _outline = ui.Color(0xFF1A1424), _iron = ui.Color(0xFF3A3540), _ironLit = ui.Color(0xFF55505C), _hole = ui.Color(0xFF241A2A);
const _emberDim = ui.Color(0xFFA82E1C), _ember = ui.Color(0xFFF0502E), _emberHead = ui.Color(0xFFFF9C7A), _smoke = ui.Color(0xFF6B6570);
const _concrete = ui.Color(0xFF8A8790), _concreteDark = ui.Color(0xFF5E5B66), _leafDark = ui.Color(0xFF2B7A40), _leaf = ui.Color(0xFF4DBD62), _leafPale = ui.Color(0xFFA2E8A0);
const _asphalt = ui.Color(0xFF3F3B4C), _clay = ui.Color(0xFF7A3B2E), _craterFloor = ui.Color(0xFF3A1A2C), _stripe = ui.Color(0xFFB8B2A0);
const _dracDark = ui.Color(0xFF8E2852), _drac = ui.Color(0xFFDE4F84), _dracPale = ui.Color(0xFFF797B6), _dracCold = ui.Color(0xFF643046);
// Luz, Digital, Metal e Feérico: a luz de cada tipo (tools/art/ui/types/palette.lua); a folha seca é a das asas da Sprig.
const _lightDim = ui.Color(0xFFCDB468), _lightTone = ui.Color(0xFFFFF0B8), _lightPale = ui.Color(0xFFFFFBE6);
const _digiDim = ui.Color(0xFF62A01E), _digi = ui.Color(0xFFA8F040), _digiPale = ui.Color(0xFFDCFA9E), _panel = ui.Color(0xFF2A2833);
const _metalDim = ui.Color(0xFF566274), _metal = ui.Color(0xFF93A1B3), _metalPale = ui.Color(0xFFCCD6E2), _rust = ui.Color(0xFF7A4A2E);
const _faeDim = ui.Color(0xFFC0669E), _fae = ui.Color(0xFFFFA8E0), _leafDry = ui.Color(0xFF8A6A3A), _leafDryPale = ui.Color(0xFFB08A4E);
// As faixas do arco-íris do mapa (clima.json, `rainbow_arc`), sem o violeta do Véu.
const _bands = [ui.Color(0xFFFF5A36), ui.Color(0xFFFFE9A8), ui.Color(0xFF6BD36A), ui.Color(0xFF4AA8FF)];

/// A fração de [t] entre [a] e [b], presa em 0 a 1.
double _span(double t, double a, double b) => ((t - a) / (b - a)).clamp(0.0, 1.0);

/// A rachadura da calçada: de 0 a 8 px para cada lado do centro, a altura de cada coluna (degraus de 1 px).
List<int> _crackRows(double Function(int) r) {
  final ys = List.filled(17, 0);
  for (var side = -1; side <= 1; side += 2) {
    var y = 0;
    for (var i = 1; i <= 8; i++) {
      final v = r(70 + i * side + 9);
      if (v < 0.25) y--;
      if (v > 0.75) y++;
      ys[8 + i * side] = y.clamp(-2, 2);
    }
  }
  return ys;
}

/// A trinca em Y do asfalto: três braços de 6 px a partir do nó (dois em diagonal para cima, um para baixo), cada passo
/// em diagonal ou reto conforme o sorteio.
List<List<(int, int)>> _yArms(double Function(int) r) {
  final arms = <List<(int, int)>>[];
  for (final (a, dx, dy) in const [(0, -1, -1), (1, 1, -1), (2, 0, 1)]) {
    final pts = <(int, int)>[];
    var x = 0, y = 0;
    for (var i = 1; i <= 6; i++) {
      final diag = r(90 + a * 10 + i) < 0.5;
      if (dx == 0) {
        y += dy;
        if (diag) x += i.isEven ? 1 : -1;
      } else {
        x += dx;
        if (diag) y += dy;
      }
      pts.add((x, y));
    }
    arms.add(pts);
  }
  return arms;
}

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
    case (SpawnTriggerKind.manhole, true):
      // A tampa do bueiro: as frestas acendem, ela desliza para o lado, o buraco aceso aparece e ela volta.
      final fade = 1 - _span(appear, 0.6, 1);
      final slide = appear < 0.6 ? _span(appear, 0.25, 0.5) : 1 - _span(appear, 0.6, 0.8);
      final lid = ui.Rect.fromCenter(center: feet, width: 14 * px, height: 5 * px);
      if (slide > 0) {
        canvas.drawOval(lid, p..color = _hole.withValues(alpha: fade));
        canvas.drawOval(lid.deflate(px * 0.5), ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = px..isAntiAlias = false
          ..color = (appear < 0.6 ? _ember : _emberDim).withValues(alpha: fade));
      }
      final at = lid.shift(ui.Offset((slide * 5).roundToDouble() * px, slide > 0.5 ? -px : 0.0));
      canvas.drawOval(at.inflate(px), p..color = _outline.withValues(alpha: fade));
      canvas.drawOval(at, p..color = _iron.withValues(alpha: fade));
      final slit = ui.Color.lerp(_ironLit, _emberDim, _span(appear, 0, 0.25))!;
      for (var i = -1; i <= 1; i++) {
        canvas.drawRect(ui.Rect.fromCenter(center: at.center.translate(i * 3 * px, 0), width: px, height: 3 * px), p..color = slit.withValues(alpha: fade));
      }
    case (SpawnTriggerKind.manhole, false):
      // Fagulhas e fumaça saem pelo buraco enquanto a tampa está aberta.
      if (appear < 0.25 || appear > 0.6) return;
      final k = _span(appear, 0.25, 0.6);
      for (var i = 0; i < 4; i++) {
        final o = feet.translate((r(60 + i) - 0.5) * 10 * px, -k * (6 + r(64 + i) * 2) * px);
        block(o, _ember.withValues(alpha: 1 - k));
        block(o.translate(0, -px), _emberHead.withValues(alpha: 1 - k));
      }
      for (var i = 0; i < 2; i++) {
        block(feet.translate((i * 2 - 1 + k * 2) * px * 2, -k * 5 * px - px), _smoke.withValues(alpha: 0.5 * (1 - k)), 2);
      }
    case (SpawnTriggerKind.crack, true):
      // A calçada racha do centro para os lados, com dois pedaços de concreto levantados.
      final fade = 1 - _span(appear, 0.7, 1);
      final reach = (_span(appear, 0, 0.4) * 8).round();
      final ys = _crackRows(r);
      for (var i = -reach; i <= reach; i++) {
        block(feet.translate(i * px, ys[8 + i] * px), _outline.withValues(alpha: fade));
        if (i == -5 || i == 4) {
          block(feet.translate(i * px, (ys[8 + i] - 1) * px), _concrete.withValues(alpha: fade));
          block(feet.translate(i * px, (ys[8 + i] + 1) * px), _concreteDark.withValues(alpha: fade));
        }
      }
      if (reach >= 6) {
        block(feet.translate(-3 * px, (ys[5] - 1) * px), _outline.withValues(alpha: fade));
        block(feet.translate(-2 * px, (ys[5] - 2) * px), _outline.withValues(alpha: fade));
        block(feet.translate(5 * px, (ys[13] + 1) * px), _outline.withValues(alpha: fade));
        block(feet.translate(6 * px, (ys[13] + 2) * px), _outline.withValues(alpha: fade));
      }
    case (SpawnTriggerKind.crack, false):
      // A luz verde corre por dentro da rachadura do centro para as pontas e apaga das pontas para o centro.
      if (appear < 0.3) return;
      final lit = appear < 0.7 ? _span(appear, 0.3, 0.5) * 8 : (1 - _span(appear, 0.7, 1)) * 8;
      final ys = _crackRows(r);
      for (var i = -8; i <= 8; i++) {
        if (i.abs() > lit) continue;
        block(feet.translate(i * px, ys[8 + i] * px), i.abs() <= 1 ? _leafPale : (i.abs() <= 4 ? _leaf : _leafDark));
      }
      if (appear < 0.7) {
        final k = _span(appear, 0.3, 0.6);
        for (final (x, dir) in const [(-2, -1), (3, 1)]) {
          for (var h = 1; h <= (k * 3).round(); h++) {
            block(feet.translate((x + (h == 3 ? dir : 0)) * px, (ys[8 + x] - h) * px), _leafDark);
          }
        }
        for (var i = 0; i < 3; i++) {
          final up = math.sin(k * math.pi) * 3;
          block(feet.translate(((i - 1) * 4 + k * (i - 1) * 2) * px, (-up - 1) * px), _concrete.withValues(alpha: 1 - k));
        }
      }
    case (SpawnTriggerKind.crater, true):
      // A cratera abre do centro com um anel rosa que some; sobra o buraco escuro, que perde a cor.
      final fade = 1 - _span(appear, 0.6, 1);
      final w = (4 + 12 * _span(appear, 0, 0.2)) * px;
      final rim = ui.Rect.fromCenter(center: feet, width: w, height: w * 6 / 16);
      canvas.drawOval(rim.inflate(px), p..color = _outline.withValues(alpha: fade));
      canvas.drawOval(rim, p..color = _asphalt.withValues(alpha: fade));
      canvas.drawOval(rim.deflate(px * 1.5), p..color = _clay.withValues(alpha: fade));
      canvas.drawOval(rim.deflate(px * 2.5), p..color = _craterFloor.withValues(alpha: fade));
      final k = _span(appear, 0, 0.3);
      if (k < 1) {
        canvas.drawOval(ui.Rect.fromCenter(center: feet, width: (16 + 8 * k) * px, height: (6 + 3 * k) * px),
            ui.Paint()..style = ui.PaintingStyle.stroke..strokeWidth = px..color = _dracPale.withValues(alpha: 1 - k)..isAntiAlias = false);
      }
    case (SpawnTriggerKind.crater, false):
      // O fundo acende até o pico, solta brasas e encolhe para o centro, apagando no violeta frio.
      if (appear < 0.2) return;
      final g = appear < 0.6 ? _span(appear, 0.2, 0.6) : 1 - _span(appear, 0.6, 1);
      final cold = appear > 0.85;
      for (final (wPx, col) in [(11.0, cold ? _dracCold : _dracDark), (7.0, _drac), (3.0, _dracPale)]) {
        if (cold && col != _dracCold) continue;
        final ww = (wPx * g).roundToDouble() * px;
        if (ww <= 0) continue;
        canvas.drawOval(ui.Rect.fromCenter(center: feet, width: ww, height: math.max(px, ww * 6 / 16)), p..color = col);
      }
      if (appear < 0.6) {
        final k = _span(appear, 0.2, 0.6);
        for (var i = 0; i < 4; i++) {
          final o = feet.translate((r(80 + i) - 0.5) * 9 * px, -k * 5 * px);
          block(o, _drac.withValues(alpha: 1 - k));
          block(o.translate(0, -px), _dracPale.withValues(alpha: 1 - k));
        }
      }
    case (SpawnTriggerKind.emberCrack, true):
      // O asfalto trinca em Y a partir do nó, com duas placas levantadas e a faixa pintada partida.
      final fade = 1 - _span(appear, 0.65, 1);
      final n = (_span(appear, 0, 0.35) * 6).round();
      for (final (x, y) in const [(-4, 2), (-3, 2), (-2, 2), (2, 2), (3, 2), (4, 2)]) {
        block(feet.translate(x * px, y * px), _stripe.withValues(alpha: fade));
      }
      block(feet.translate(-3 * px, -2 * px), _asphalt.withValues(alpha: fade), 2);
      block(feet.translate(3 * px, -2 * px), _asphalt.withValues(alpha: fade), 2);
      block(feet, _outline.withValues(alpha: fade));
      for (final arm in _yArms(r)) {
        for (final (x, y) in arm.take(n)) {
          block(feet.translate(x * px, y * px), _outline.withValues(alpha: fade));
        }
      }
    case (SpawnTriggerKind.emberCrack, false):
      // A junta acende dentro da trinca, respira em dois passos e esfria das pontas para o nó.
      if (appear < 0.35) return;
      final cooling = _span(appear, 0.65, 1);
      final len = appear < 0.65 ? 6 : (6 * (1 - cooling)).round();
      final breath = appear < 0.65 && (appear * 20).floor().isOdd ? 0.7 : 1.0;
      final arm = cooling < 0.34 ? _drac : (cooling < 0.67 ? _dracDark : _dracCold);
      block(feet, (cooling < 0.5 ? _dracPale : arm).withValues(alpha: breath));
      for (final a in _yArms(r)) {
        for (var i = 0; i < len && i < a.length; i++) {
          final col = appear < 0.65 && i >= 4 ? _dracDark : arm;
          block(feet.translate(a[i].$1 * px, a[i].$2 * px), col.withValues(alpha: breath));
        }
      }
      if (appear < 0.65) {
        final k = _span(appear, 0.35, 0.65);
        for (var i = 0; i < 2; i++) {
          block(feet.translate((i * 2 - 1) * 2 * px, -(1 + k * 4) * px), _dracPale.withValues(alpha: 1 - k));
        }
      }
    case (SpawnTriggerKind.glint, false):
      // O sol bate numa vitrine: uma estrela de quatro pontas abre acima dela, um risco de reflexo passa e tudo apaga.
      if (appear >= 0.6) return;
      final k = _span(appear, 0, 0.3), fade = 1 - _span(appear, 0.3, 0.6);
      final o = c.translate(0, -size * 0.35);
      final arm = (1 + k * 5).round();
      for (var i = 1; i <= arm; i++) {
        final col = (i <= 2 ? _lightPale : (i <= 4 ? _lightTone : _lightDim)).withValues(alpha: fade);
        for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          block(o.translate(dx * i * px, dy * i * px), col);
        }
      }
      block(o, _white.withValues(alpha: fade), 2);
      for (var i = -3; i <= 3; i++) {
        block(c.translate((i + (k * 8 - 4)) * px, (-i - 2) * px), _lightTone.withValues(alpha: fade * 0.6));
      }
    case (SpawnTriggerKind.rainbow, false):
      // Ela sai da faixa do arco-íris: quatro faixas descem do alto até ela e se desfazem em pontos de luz.
      final k = _span(appear, 0, 0.5), fade = 1 - _span(appear, 0.5, 0.9);
      final top = c.dy - size * (2.5 - 2 * k);
      for (var b = 0; b < _bands.length; b++) {
        for (var y = top; y < c.dy - size * 0.3; y += px) {
          block(ui.Offset(c.dx + (b - 1.5) * px, y), _bands[b].withValues(alpha: fade * 0.8));
        }
      }
      for (var i = 0; i < 6; i++) {
        final kk = _span(appear, 0.3 + i * 0.03, 0.8);
        if (kk <= 0 || kk >= 1) continue;
        block(c + ui.Offset(math.cos(i * 1.05) * size * 0.5 * kk, -size * 0.3 + math.sin(i * 1.05) * size * 0.3 * kk), _bands[i % _bands.length].withValues(alpha: 1 - kk));
      }
    case (SpawnTriggerKind.staticSign, false):
      // O letreiro mais perto pisca em estática; os pixels saem dele e chegam juntos no centro, onde o pombo aparece.
      final o = origin ?? c.translate(0, -size * 0.6);
      if (appear < 0.45) {
        final on = (appear * 20).floor().isEven;
        final panel = ui.Rect.fromCenter(center: o, width: 8 * px, height: 5 * px);
        canvas.drawRect(panel.inflate(px), p..color = _outline);
        canvas.drawRect(panel, p..color = _panel);
        for (var i = 0; i < 10; i++) {
          if (r(70 + i + (appear * 20).floor() * 10) < 0.5 != on) continue;
          block(o.translate(((r(90 + i) * 8).floor() - 3.5) * px, ((r(100 + i) * 5).floor() - 2) * px), i.isEven ? _digi : _digiPale);
        }
      }
      for (var i = 0; i < 6; i++) {
        final k = _span(appear, 0.2 + i * 0.03, 0.6);
        if (k <= 0 || k >= 1) continue;
        block(ui.Offset.lerp(o, c, k)!.translate(((i % 3) - 1) * px * (1 - k) * 3, 0), i.isEven ? _digi : _digiDim);
      }
    case (SpawnTriggerKind.grate, true):
      // Uma folha de grade enferrujada atrás dela range (balança 1 px), abre e some quando o corpo fecha.
      final fade = 1 - _span(appear, 0.55, 0.85);
      if (fade <= 0) return;
      final swing = appear < 0.3 ? ((appear * 24).floor().isEven ? 1.0 : 0.0) : 0.0;
      final open = _span(appear, 0.3, 0.55);
      final w = (10 - open * 6).roundToDouble();
      final left = c.dx - 5 * px + swing * px;
      final topY = feet.dy - 14 * px;
      canvas.drawRect(ui.Rect.fromLTWH(left - px, topY - px, (w + 2) * px, 16 * px), p..color = _outline.withValues(alpha: fade));
      for (var x = 0; x < w; x++) {
        for (var y = 0; y < 14; y++) {
          final bar = x.isEven || y % 5 == 0;
          if (!bar) continue;
          canvas.drawRect(ui.Rect.fromLTWH(left + x * px, topY + y * px, px, px), p..color = (r(110 + x * 14 + y) < 0.25 ? _rust : (y % 5 == 0 ? _metal : _metalDim)).withValues(alpha: fade));
        }
      }
    case (SpawnTriggerKind.grate, false):
      // A limalha solta da grade se junta no besouro.
      for (var i = 0; i < 8; i++) {
        final k = _span(appear, 0.15 + i * 0.02, 0.55);
        if (k <= 0 || k >= 1) continue;
        final dir = i / 8 * 2 * math.pi + r(120 + i);
        final dist = size * 0.6 * (1 - k);
        block(c + ui.Offset(math.cos(dir) * dist, math.sin(dir) * dist * 0.7), i.isEven ? _metalPale : _metal);
      }
    case (SpawnTriggerKind.whirl, false) || (SpawnTriggerKind.whirlPollen, false):
      // Folhas secas giram num redemoinho que fecha nela; no crepúsculo, com pólen aceso no meio.
      final pollen = t.kind == SpawnTriggerKind.whirlPollen;
      for (var i = 0; i < 8; i++) {
        final k = _span(appear, i * 0.03, 0.6);
        if (k >= 1) continue;
        final ang = i / 8 * 2 * math.pi + k * 2.5 * math.pi;
        final rad = size * (0.75 - 0.6 * k);
        final pt = c + ui.Offset(math.cos(ang) * rad, math.sin(ang) * rad * 0.5 - k * size * 0.2);
        block(pt, (i.isEven ? _leafDry : _leafDryPale).withValues(alpha: 1 - k * 0.6), 2);
        if (pollen && i.isOdd) block(pt.translate(px * 1.5, -px * 1.5), (k < 0.5 ? _fae : _faeDim).withValues(alpha: 1 - k));
      }
    default:
  }
}
