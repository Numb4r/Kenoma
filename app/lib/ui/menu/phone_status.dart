/// A barra de status do mundo no topo do celular: hora local, fase da lua e o clima (só com a Rua viva ligada).
/// O celular guarda de onde ler em [phoneStatusSource]; as telas dos apps usam a versão fina da mesma barra.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/astro.dart';
import '../../core/features.dart';
import '../../core/weather.dart';
import '../game/moon_hud.dart';
import '../tema.dart';

/// De onde a barra lê a hora, a latitude (o hemisfério espelha a lua) e o clima.
class PhoneStatusSource {
  const PhoneStatusSource({required this.nowUtc, required this.lat, this.weather});

  final int Function() nowUtc;
  final double Function() lat;
  final Weather Function()? weather;
}

/// Definido por `showPhoneMenu`. ponytail: global porque as telas dos apps ficam em rotas fora do celular; troque por
/// um InheritedWidget no topo do app se houver mais de um mapa.
PhoneStatusSource? phoneStatusSource;

String phoneClock(int utcSeconds) {
  final t = DateTime.fromMillisecondsSinceEpoch(utcSeconds * 1000, isUtc: true).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}';
}

class PhoneStatusBar extends StatefulWidget {
  const PhoneStatusBar({this.source, this.compact = false, super.key});

  /// Sem fonte, usa [phoneStatusSource]; sem nenhuma, a barra some.
  final PhoneStatusSource? source;
  final bool compact;

  @override
  State<PhoneStatusBar> createState() => _PhoneStatusBarState();
}

class _PhoneStatusBarState extends State<PhoneStatusBar> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final src = widget.source ?? phoneStatusSource;
    if (src == null) return const SizedBox.shrink();
    final t = src.nowUtc();
    final w = streetLifeEnabled ? src.weather?.call() : null;
    final ico = widget.compact ? 12.0 : 18.0;
    final style = KTexto.rotulo.copyWith(fontSize: widget.compact ? 9 : 12);
    return Container(
      key: Key(widget.compact ? 'phone-status-compact' : 'phone-status'),
      height: widget.compact ? 24 : 36,
      padding: const EdgeInsets.symmetric(horizontal: KEspaco.s2),
      color: KCores.contorno,
      child: Row(children: [
        Text(phoneClock(t), key: const Key('status-clock'), style: style),
        const SizedBox(width: KEspaco.s2),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
        CustomPaint(key: const Key('status-moon'), size: Size(ico, ico), painter: MoonPainter(moonCycle(t), src.lat() < 0)),
        const SizedBox(width: KEspaco.s1),
        Text(moonPhaseNames[moonPhase(t)]!.toUpperCase(), key: const Key('status-moon-name'), style: style.copyWith(color: KCores.textoMudo)),
        if (w != null) ...[
          const SizedBox(width: KEspaco.s2),
          SizedBox(width: ico, height: ico, child: FittedBox(child: CustomPaint(key: const Key('status-weather'), size: const Size(18, 18), painter: WeatherGlyphPainter(w)))),
          const SizedBox(width: KEspaco.s1),
          Text(w.label.toUpperCase(), key: const Key('status-weather-label'), style: style.copyWith(color: KCores.textoMudo)),
        ],
            ]),
          ),
        ),
      ]),
    );
  }
}
