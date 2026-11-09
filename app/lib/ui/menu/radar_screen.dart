/// O app Radar do celular (docs/GDD.md, "Rastros e scanner"): a tela de sonar. Um círculo com o Conjurador no centro, que
/// gira com o norte do mapa; o pulso (recarga de 2 minutos) parte do centro e volta com os ecos: arcos difusos dos
/// rastros a até 250 m, mais estreitos quanto mais perto, e as distorções dos Ocultos a até 60 m. No nível 2 o arco leva a
/// cor do tipo. O atalho do HUD (`RadarShortcut`) dispara o mesmo pulso sem abrir o app. Só desenha: a lógica é de
/// `world/radar.dart`.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../capture/eco_type.dart';
import '../../player/game_state.dart';
import '../../world/radar.dart';
import '../../world/street_life_balance.dart';
import '../colors.dart';
import '../game/trace_painter.dart' show paintDistortion;
import '../pressable.dart';
import '../tema.dart';
import '../tuning/tuning_screen.dart' show PixelButton;
import 'screen_frame.dart';

/// O que o pulso achou, numa linha para o aviso.
String radarSummary(RadarOutcome o) {
  if (o.isEmpty) return 'Radar: nada raro por perto';
  final t = o.traces.length, d = o.distortions.length;
  return 'Radar: ${[if (t > 0) '$t ${t == 1 ? 'rastro' : 'rastros'}', if (d > 0) '$d ${d == 1 ? 'distorção' : 'distorções'}'].join(' e ')}';
}

class RadarScreen extends StatefulWidget {
  const RadarScreen({required this.state, required this.street, required this.nowUtc, required this.onSweep, required this.echoes, required this.rotation, super.key});

  final GameState state;
  final StreetLifeBalance street;
  final int Function() nowUtc;

  /// Dispara o pulso no mapa e devolve o que ele achou.
  final RadarOutcome Function() onSweep;

  /// Os ecos de agora, vistos do jogador (`WorldView.sonar`).
  final List<SonarEcho> Function() echoes;

  /// A rotação do mapa (radianos): o sonar gira com o norte dele.
  final double Function() rotation;

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  Timer? _tick;
  RadarOutcome? _last;
  final _sinceFired = Stopwatch();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _spin.dispose();
    super.dispose();
  }

  static String _clock(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  void _sweep() {
    final wait = radarWaitS(lastUtc: widget.state.radarLastUtc, nowUtc: widget.nowUtc(), balance: widget.street);
    if (wait > 0) return;
    _sinceFired
      ..reset()
      ..start();
    setState(() => _last = widget.onSweep());
  }

  /// Há quantos segundos saiu o pulso: daqui, com fração; do HUD, pelo relógio do jogo.
  double _pulseAge() => _sinceFired.isRunning ? _sinceFired.elapsedMilliseconds / 1000 : (widget.nowUtc() - widget.state.radarLastUtc).toDouble();

  @override
  Widget build(BuildContext context) {
    final b = widget.street;
    final level = scannerLevel(widget.state.playerLevel, b);
    final wait = radarWaitS(lastUtc: widget.state.radarLastUtc, nowUtc: widget.nowUtc(), balance: b);
    final last = _last;
    return ScreenFrame(
      title: 'Radar',
      subtitle: 'Scanner nível $level',
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(
            key: const Key('radar-sonar'),
            painter: SonarPainter(
              echoes: widget.echoes,
              rotation: widget.rotation,
              pulseAge: _pulseAge,
              balance: b,
              level: level,
              spin: _spin,
            ),
          ),
        ),
        const SizedBox(height: 12),
        PixelButton(label: wait > 0 ? 'Recarregando ${_clock(wait)}' : 'Pulso', color: wait > 0 ? kDim : kSignal, onTap: _sweep),
        const SizedBox(height: 12),
        if (last != null)
          Container(
            key: const Key('radar-result'),
            padding: const EdgeInsets.all(12),
            decoration: panelBox(line: last.isEmpty ? kPanelLine : kSignal),
            child: Text(radarSummary(last).toUpperCase(), style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
          ),
        const SizedBox(height: 12),
        Text(
          level >= 2
              ? 'NÍVEL 2: O ARCO MOSTRA A COR DO TIPO DO ECO. OS OCULTOS A ATÉ ${b.radarRadiusM.round()} M VOLTAM COMO DISTORÇÃO: ANDE ATÉ ELA PARA O ECO APARECER.'
              : 'NÍVEL 1: ARCOS NA DIREÇÃO PROVÁVEL DOS ECOS RAROS (VARIANTES, BRILHANTES, OCULTOS E MAIS FORTES QUE VOCÊ) A ATÉ ${b.traceRangeM.round()} M, MAIS ESTREITOS QUANTO MAIS PERTO. OS OCULTOS A ATÉ ${b.radarRadiusM.round()} M VOLTAM COMO DISTORÇÃO: ANDE ATÉ ELA. O NÍVEL 2 VEM NO NÍVEL ${b.radarLevel2PlayerLevel}.',
          style: const TextStyle(fontSize: 8, color: kDim, height: 1.8),
        ),
      ],
    );
  }
}

/// O sonar: anéis de distância, o norte do mapa, o feixe girando, a onda do pulso e os ecos que ela já alcançou.
class SonarPainter extends CustomPainter {
  SonarPainter({required this.echoes, required this.rotation, required this.pulseAge, required this.balance, required this.level, required Animation<double> spin})
      : _spin = spin,
        super(repaint: spin);

  final List<SonarEcho> Function() echoes;
  final double Function() rotation;
  final double Function() pulseAge;
  final StreetLifeBalance balance;
  final int level;
  final Animation<double> _spin;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;
    final scale = r / balance.traceRangeM;
    final p = Paint()..isAntiAlias = false;
    canvas.drawCircle(c, r, p..color = KCores.fundo..style = PaintingStyle.fill);
    final line = Paint()..style = PaintingStyle.stroke..isAntiAlias = false;
    for (final m in [balance.traceRangeM / 2, balance.traceRangeM]) {
      canvas.drawCircle(c, m * scale, line..strokeWidth = 2..color = kSignal.withValues(alpha: 0.35));
    }
    canvas.drawCircle(c, balance.radarRadiusM * scale, line..strokeWidth = 2..color = kVeil.withValues(alpha: 0.45)); // onde os Ocultos aparecem
    final rot = rotation();
    // O norte do mapa: -90° no mundo, girado como o mapa.
    final north = -math.pi / 2 + rot;
    final n = TextPainter(text: const TextSpan(text: 'N', style: TextStyle(fontFamily: 'Silkscreen', fontSize: 10, color: kEssence)), textDirection: TextDirection.ltr)..layout();
    n.paint(canvas, c + Offset(math.cos(north), math.sin(north)) * (r - 10) - Offset(n.width / 2, n.height / 2));
    // O feixe girando (só enfeite).
    final beam = _spin.value * 2 * math.pi;
    canvas.drawLine(c, c + Offset(math.cos(beam), math.sin(beam)) * r, line..strokeWidth = 2..color = kSignal.withValues(alpha: 0.5));
    // A onda do pulso.
    final waveM = pulseAge() * balance.pulseSpeedMps;
    if (waveM <= balance.traceRangeM) canvas.drawCircle(c, waveM * scale, line..strokeWidth = 3..color = kSignal);
    for (final e in echoes()) {
      if (e.distanceM > waveM) continue; // a onda ainda não voltou daqui
      final a = e.angleRad + rot;
      if (e.distortion) {
        paintDistortion(canvas, (c.dx + math.cos(a) * e.distanceM * scale, c.dy + math.sin(a) * e.distanceM * scale), 10, _spin.value * 8, p);
        continue;
      }
      final color = e.shiny ? const Color(0xFFFFE9A8) : (level >= 2 && e.typeId != null ? typeColor(EcoType.parse(e.typeId!)) : kText);
      final rr = e.distanceM * scale;
      final box = Rect.fromCircle(center: c, radius: rr);
      // Difuso: três traços, do largo e fraco ao fino e forte.
      for (final (w, alpha) in const [(14.0, 0.18), (8.0, 0.35), (3.0, 0.9)]) {
        canvas.drawArc(box, a - e.widthRad / 2, e.widthRad, false, line..strokeWidth = w..color = color.withValues(alpha: alpha));
      }
    }
    canvas.drawRect(Rect.fromCenter(center: c, width: 8, height: 8), p..color = kEssence..style = PaintingStyle.fill); // o Conjurador
  }

  @override
  bool shouldRepaint(SonarPainter old) => true;
}

/// O atalho do Radar no HUD: dispara o pulso sem abrir o app e mostra a recarga como um anel.
class RadarShortcut extends StatefulWidget {
  const RadarShortcut({required this.state, required this.street, required this.nowUtc, required this.onPulse, super.key});

  final GameState state;
  final StreetLifeBalance street;
  final int Function() nowUtc;

  /// Dispara o pulso (só chamado com o Radar pronto).
  final VoidCallback onPulse;

  @override
  State<RadarShortcut> createState() => _RadarShortcutState();
}

class _RadarShortcutState extends State<RadarShortcut> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  int _wait() => radarWaitS(lastUtc: widget.state.radarLastUtc, nowUtc: widget.nowUtc(), balance: widget.street);

  @override
  Widget build(BuildContext context) {
    final ready = 1 - _wait() / widget.street.radarCooldownS;
    return Pressable(
      key: const Key('radar-shortcut'),
      onTap: () {
        if (_wait() > 0) return;
        widget.onPulse();
        setState(() {});
      },
      child: CustomPaint(size: const Size(48, 48), painter: _RingPainter(ready.clamp(0.0, 1.0))),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.ready);

  final double ready;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 3;
    canvas.drawCircle(c, r, Paint()..color = kOutline.withValues(alpha: 0.88)..isAntiAlias = false);
    final ring = Paint()..style = PaintingStyle.stroke..strokeWidth = 4..isAntiAlias = false;
    canvas.drawCircle(c, r, ring..color = kPanelLine);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * ready, false, ring..color = ready >= 1 ? kSignal : kDim);
    final dot = Paint()..color = ready >= 1 ? kSignal : kDim..isAntiAlias = false;
    canvas.drawRect(Rect.fromCenter(center: c, width: 6, height: 6), dot);
    final waves = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = dot.color..isAntiAlias = false;
    canvas.drawArc(Rect.fromCircle(center: c, radius: 9), -math.pi * 0.85, math.pi * 0.7, false, waves);
    canvas.drawArc(Rect.fromCircle(center: c, radius: 14), -math.pi * 0.85, math.pi * 0.7, false, waves);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.ready != ready;
}
