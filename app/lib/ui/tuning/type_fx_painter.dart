/// O desenho dos padrões dos nove tipos da fase 1 (`capture/type_patterns.dart`). Só pinta o [TypeFx] do instante.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../../capture/eco_type.dart';
import '../../capture/fx/wave_geometry.dart';
import '../../capture/type_patterns.dart';
import '../colors.dart';
import '../flashes.dart';
import 'tuning_layout.dart';

Paint _stroke(Color c, double w) => Paint()
  ..color = c
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..isAntiAlias = false;

Paint _fill(Color c) => Paint()
  ..color = c
  ..isAntiAlias = false;

/// Por baixo da onda real: os estratos da Terra, a cópia cinza do Espectral, as cópias com glitch do Digital e a imagem
/// residual da Luz. [sig] monta a onda do sinal numa frequência.
void paintTypeUnder(Canvas canvas, Rect r, TypeFx fx, EcoType type, Path Function(double f) sig) {
  if (fx.strata.isNotEmpty) {
    // Estratos de rocha: faixas horizontais pesadas no fundo do painel.
    final c = typeColor(EcoType.earth).withValues(alpha: 0.22);
    for (var i = 0; i < fx.strata.length; i++) {
      final y = r.top + r.height * (i + 0.7) / (fx.strata.length + 0.6);
      canvas.drawRect(Rect.fromLTWH(r.left + 2, y, r.width - 4, 5), _fill(c));
    }
  }
  final ghost = fx.ghost;
  if (ghost != null) canvas.drawPath(sig(ghost), _stroke(kDim, 3));
  for (var i = 0; i < fx.decoys.length; i++) {
    // A cópia falsa tem a cor da real; o que a entrega é o glitch: sai do lugar e vem cortada em blocos.
    final k = fx.glitch * 7 + i * 13;
    canvas.save();
    canvas.translate(0, ((k % 3) - 1) * 4.0);
    canvas.drawPath(sig(fx.decoys[i]), _stroke(kSignal.withValues(alpha: 0.85), 3));
    canvas.restore();
    for (var b = 0; b < 5; b++) {
      final x = r.left + r.width * (((k + b * 37) * 61 % 97) / 97);
      canvas.drawRect(Rect.fromLTWH(x, r.top + 2, 6, r.height - 4), _fill(kPanel));
    }
  }
  final after = fx.afterimage;
  if (after != null) canvas.drawPath(sig(after), _stroke(typeColor(EcoType.light).withValues(alpha: 0.25 + 0.4 * fx.flash), 3));
}

/// Por cima da onda real e por baixo da do jogador: a tinta da Sombra, as placas do Metal, o arco do Elétrico, as
/// escamas do Dracônico, o pó de fada e o clarão da Luz.
void paintTypeOver(Canvas canvas, Rect r, TypeFx fx, EcoType type, double clock, {required bool aligned}) {
  if (fx.ink > 0) {
    // A tinta sobe do fundo, com a borda de cima em degraus.
    final h = r.height * fx.ink, ink = _fill(kOutline);
    canvas.drawRect(Rect.fromLTRB(r.left + 2, r.bottom - h, r.right - 2, r.bottom - 2), ink);
    for (var i = 0; i < 12; i++) {
      final w = (r.width - 4) / 12, up = 3.0 + 3 * math.sin(clock * 1.7 + i * 1.9);
      canvas.drawRect(Rect.fromLTWH(r.left + 2 + i * w, math.max(r.top + 2, r.bottom - h - up), w, up + 1), ink);
    }
  }
  if (fx.armored) {
    // Placas de blindagem sobre o painel, com rebites. Alinhado, só faísca.
    final metal = typeColor(EcoType.metal);
    const n = 5;
    for (var i = 0; i < n; i++) {
      final plate = Rect.fromLTWH(r.left + 3 + i * (r.width - 6) / n, r.top + 3, (r.width - 6) / n - 2, r.height - 6);
      canvas.drawRect(plate, _fill(metal.withValues(alpha: 0.38)));
      canvas.drawRect(plate, _stroke(metal, 2));
      for (final at in [plate.topLeft + const Offset(5, 5), plate.bottomRight - const Offset(5, 5)]) {
        canvas.drawRect(Rect.fromCenter(center: at, width: 3, height: 3), _fill(kOutline));
      }
    }
    if (aligned) {
      final x = r.left + r.width * waveReadU;
      for (var i = 0; i < 6; i++) {
        final a = i * 1.05 + (clock * 9).floor() * 0.7, d = 6.0 + (i * 5 + (clock * 12).floor()) % 9;
        canvas.drawRect(Rect.fromCenter(center: Offset(x + math.cos(a) * d, r.center.dy + math.sin(a) * d), width: 3, height: 3), _fill(kEssence));
      }
    }
  }
  if (fx.hopFlash > 0) {
    // O arco do salto: um raio quebrado no ponto de leitura.
    final x = r.left + r.width * waveReadU, p = Path()..moveTo(x, r.top + 2);
    for (var i = 1; i <= 6; i++) {
      p.lineTo(x + (i.isOdd ? 7 : -7) * (i == 6 ? 0 : 1), r.top + 2 + (r.height - 4) * i / 6);
    }
    canvas.drawPath(p, _stroke(typeColor(EcoType.electric).withValues(alpha: fx.hopFlash), 3));
  }
  if (type == EcoType.draconic) {
    // Escamas: uma fileira a mais a cada padrão somado.
    final c = _stroke(typeColor(EcoType.draconic).withValues(alpha: 0.7), 2);
    for (var row = 0; row <= fx.stage; row++) {
      for (var x = r.left + 8 + (row.isOdd ? 8 : 0); x < r.right - 8; x += 16) {
        canvas.drawArc(Rect.fromCircle(center: Offset(x, r.bottom - 4 - row * 7), radius: 7), math.pi, math.pi, false, c);
      }
    }
  }
  if (type == EcoType.fae) {
    // Pó de fada: pontos que sobem devagar; mais e mais vivos com o dial invertido.
    final c = typeColor(EcoType.fae);
    final n = fx.inverted ? 18 : 8;
    for (var i = 0; i < n; i++) {
      final u = (i * 0.618 + clock * 0.03 * (1 + i % 3)) % 1.0, v = (i * 0.37 - clock * 0.08 * (1 + i % 2)) % 1.0;
      final tw = 0.4 + 0.6 * (0.5 + 0.5 * math.sin(clock * 3 + i));
      canvas.drawRect(Rect.fromLTWH(r.left + 4 + u * (r.width - 8), r.top + 4 + v * (r.height - 8), 2, 2), _fill(c.withValues(alpha: tw * (fx.inverted ? 1 : 0.6))));
    }
  }
  if (fx.flash > 0) {
    // Reduzir clarões: o clarão vira um véu fraco; a onda some do mesmo jeito.
    canvas.drawRect(r.deflate(2), _fill(typeColor(EcoType.light).withValues(alpha: fx.flash * (reduceFlashes.value ? 0.15 : 0.6))));
  }
}

/// No dial: as faixas pesadas da Terra, o pulso fraco da Sombra, o aro do Feérico invertido e o da blindagem.
void paintTypeDial(Canvas canvas, TuningLayout l, TypeFx fx, double target, double clock) {
  final c = l.dialCenter, rad = l.dialRadius;
  for (final (lo, hi) in fx.strata) {
    final a = dialAngle(lo);
    canvas.drawArc(Rect.fromCircle(center: c, radius: rad - 4), a, dialAngle(hi) - a, false, _stroke(typeColor(EcoType.earth).withValues(alpha: 0.75), 10));
  }
  if (fx.ink > 0) {
    // Com a onda na tinta, o pulso do sinal aparece fraco na borda do dial.
    final a = dialAngle(target), at = c + Offset(math.cos(a), math.sin(a)) * (rad + 1);
    final alpha = fx.ink * (0.22 + 0.16 * math.sin(clock * 6));
    canvas.drawCircle(at, 5, _fill(typeColor(EcoType.shadow).withValues(alpha: alpha.clamp(0.0, 1.0))));
  }
  if (fx.inverted) canvas.drawCircle(c, rad + 10, _stroke(typeColor(EcoType.fae), 2));
  if (fx.armored) canvas.drawCircle(c, rad + 10, _stroke(typeColor(EcoType.metal), 3));
}
