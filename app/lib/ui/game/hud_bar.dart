/// Peças do HUD do mapa (as zonas são de `hud_layout.dart`): a barra do topo com hora, lua, clima e o selo de modo, e o
/// atalho temporário da faixa acima do celular. Só desenham e repassam toques.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/astro.dart';
import '../../core/epochs.dart' show testEpochId;
import '../../data/climate_catalog.dart';
import '../../dev/dev_tools.dart';
import '../../world/layered_world.dart';
import '../colors.dart';
import '../menu/phone_status.dart' show phoneClock;
import 'moon_hud.dart' show MoonPainter, WeatherGlyphPainter;

const _label = TextStyle(fontSize: 8, color: kText);

/// O que a folha do selo explica quando o jogador está num bloco da Overpass.
const String kVeilBadgeHelp = 'Aqui o mapa veio da rede: amigos em versões diferentes do app podem ver coisas diferentes.';

/// A barra única do topo: hora, lua e clima à esquerda (o toque abre o Céu) e o selo de modo à direita.
class HudBar extends StatefulWidget {
  const HudBar({required this.nowUtc, required this.lat, required this.seal, this.weather, this.onSky, this.battery, this.hole, super.key});

  final int Function() nowUtc;
  final double Function() lat;

  /// O clima que se vê. Sem ele (0.13.1), só hora e lua.
  final ClimateInfo Function()? weather;
  final VoidCallback? onSky;
  final Widget seal;

  /// 0.23.1: a carga da bateria em % (o modo imersivo esconde a barra de status). `null` ou sem leitura: sem indicador.
  final Future<int?> Function()? battery;

  /// 0.23.2: o furo da câmera, nas coordenadas da barra (tela cheia): a parte da esquerda termina antes dele.
  final Rect? hole;

  @override
  State<HudBar> createState() => _HudBarState();
}

class _HudBarState extends State<HudBar> {
  Timer? _tick, _batteryTick;
  int? _battery;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
    if (widget.battery != null) {
      _readBattery();
      _batteryTick = Timer.periodic(const Duration(minutes: 1), (_) => _readBattery());
    }
  }

  Future<void> _readBattery() async {
    final v = await widget.battery!();
    if (mounted && v != _battery) setState(() => _battery = v);
  }

  /// A parte da esquerda (hora, bateria, lua, clima): ocupa o que sobra, ou só até o furo da câmera.
  Widget _left(Widget child) {
    final h = widget.hole;
    if (h == null || h.left < 40) return Expanded(child: child);
    return Expanded(child: Row(children: [SizedBox(width: h.left - 4, child: child), SizedBox(width: h.width + 8), const Spacer()]));
  }

  @override
  void dispose() {
    _tick?.cancel();
    _batteryTick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.nowUtc();
    final w = widget.weather?.call();
    return Container(
      key: const Key('hud-bar'),
      decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.85), border: Border.all(color: kPanelLine, width: 2)),
      child: Row(children: [
        _left(GestureDetector(
            key: const Key('weather-hud'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSky,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(children: [
                Text(phoneClock(t), key: const Key('hud-clock'), style: _label),
                if (_battery case final b?) ...[
                  const SizedBox(width: 6),
                  CustomPaint(key: const Key('hud-battery'), size: const Size(14, 8), painter: BatteryGlyphPainter(b)),
                  const SizedBox(width: 3),
                  Text('$b%', key: const Key('hud-battery-label'), style: _label.copyWith(color: b <= 20 ? kEssence : null)),
                ],
                const SizedBox(width: 8),
                CustomPaint(key: const Key('moon-hud'), size: const Size(20, 20), painter: MoonPainter(moonCycle(t), widget.lat() < 0)),
                if (w != null) ...[
                  const SizedBox(width: 8),
                  CustomPaint(key: const Key('weather-glyph'), size: const Size(18, 18), painter: WeatherGlyphPainter(w)),
                  const SizedBox(width: 6),
                  Flexible(child: Text(w.name.toUpperCase(), key: const Key('weather-label'), maxLines: 1, overflow: TextOverflow.ellipsis, style: _label)),
                ],
              ]),
            ),
          ),
        ),
        widget.seal,
      ]),
    );
  }
}

/// O selo de modo: de onde vem a posição (GPS real ou simulador) e, embaixo, DEBUG com algo forçado e VÉU INSTÁVEL num
/// bloco da Overpass. O toque abre a folha do modo: estado do GPS, troca de fonte, controles do simulador e o menu de debug.
class ModeSeal extends StatelessWidget {
  const ModeSeal({required this.tools, required this.source, required this.onTap, super.key});

  final DevTools tools;
  final ValueNotifier<MapSourceKind> source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([tools, tools.clock, tools.force, source]),
        builder: (context, _) {
          final debug = tools.anyForcing, veil = source.value == MapSourceKind.overpass, test = testEpochId;
          return GestureDetector(
            key: const Key('mode-seal'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minWidth: 72, maxWidth: 120),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: kPanelLine, width: 2))),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(tools.useSimulator ? 'SIMULADOR' : 'GPS REAL', style: const TextStyle(fontSize: 8, color: kSignal)),
                  if (debug || veil)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (debug) const Text('DEBUG', key: Key('debug-tag'), style: TextStyle(fontSize: 7, color: kEssence)),
                        if (debug && veil) const SizedBox(width: 6),
                        if (veil) const Text('VÉU INSTÁVEL', key: Key('veil-badge'), style: TextStyle(fontSize: 7, color: kVeil)),
                      ]),
                    ),
                  // A época em teste (Ajustes, só neste aparelho): o mundo aqui não é o dos amigos.
                  if (test != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('ÉPOCA $test EM TESTE', key: const Key('test-epoch-tag'), style: const TextStyle(fontSize: 7, color: kEssence)),
                    ),
                ]),
              ),
            ),
          );
        },
      );
}

/// Um atalho temporário da faixa acima do celular: fino, com contorno na cor dele.
class ShortcutChip extends StatelessWidget {
  const ShortcutChip({required this.label, required this.color, required this.onTap, super.key});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            height: 32,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.88), border: Border.all(color: color, width: 2)),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 8, color: color)),
          ),
        ),
      );
}


/// 0.23.1: a bateria no HUD, em pixels: o corpo com contorno, o polo à direita e a carga por dentro (Essência com 20% ou menos).
class BatteryGlyphPainter extends CustomPainter {
  BatteryGlyphPainter(this.percent);

  final int percent;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..isAntiAlias = false;
    final body = Rect.fromLTWH(0, 0, size.width - 2, size.height);
    canvas.drawRect(body, p..color = kText);
    canvas.drawRect(body.deflate(1), p..color = kOutline);
    canvas.drawRect(Rect.fromLTWH(size.width - 2, size.height / 2 - 2, 2, 4), p..color = kText);
    final inner = body.deflate(2);
    final w = (inner.width * percent.clamp(0, 100) / 100).roundToDouble();
    if (w > 0) canvas.drawRect(Rect.fromLTWH(inner.left, inner.top, w, inner.height), p..color = percent <= 20 ? kEssence : kSignal);
  }

  @override
  bool shouldRepaint(BatteryGlyphPainter old) => old.percent != percent;
}
