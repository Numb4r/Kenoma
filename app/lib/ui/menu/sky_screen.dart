/// O app Céu do celular (docs/GDD.md, "Celular mágico"): o clima de agora e das próximas janelas, com o que cada um muda no
/// spawn, os eventos ativos e o motivo, e a lua. Tocar no clima do HUD abre aqui. Só desenha: o clima vem de um
/// [SkyOutlook] (`world/sky_outlook.dart`).
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/astro.dart';
import '../../core/climate_events.dart' show climateOfStack;
import '../../data/climate_catalog.dart';
import '../../world/dew_prism.dart';
import '../../world/sky_outlook.dart';
import '../colors.dart';
import '../game/moon_hud.dart' show MoonPainter, WeatherGlyphPainter;
import 'phone_status.dart' show phoneClock;
import 'screen_frame.dart';

const _body = TextStyle(fontSize: 8, color: kText, height: 1.8);
const _dim = TextStyle(fontSize: 8, color: kDim, height: 1.8);

class SkyScreen extends StatefulWidget {
  const SkyScreen({required this.nowUtc, required this.lat, required this.catalog, this.shown, this.outlook, this.windows = 6, this.nextEvent, this.calendar, this.prisms, this.usePrism, super.key});

  final int Function() nowUtc;

  /// A latitude do jogador (o hemisfério espelha a lua).
  final double Function() lat;
  final ClimateCatalog catalog;

  /// O clima que se vê agora (pode ser o da rede, só visual). `null` sem a Rua viva: o Céu mostra só a lua.
  final ClimateInfo Function()? shown;
  final SkyOutlook? outlook;

  /// Quantas janelas listar, a de agora inclusive.
  final int windows;

  /// O próximo evento do calendário do Véu depois de [nowUtc] (`climate_outlook.dart`, `nextCalendarEvent`).
  final ({String event, String climate, int startUtc})? Function(int nowUtc)? nextEvent;

  /// Época 12: os próximos itens do calendário do Véu, cada um marcado como clima ou evento (`nextCalendarItems`). Com ele,
  /// a lista substitui [nextEvent].
  final List<({String event, String what, bool isEvent, int startUtc})> Function(int nowUtc)? calendar;

  /// Quantos Prismas de orvalho há na bolsa, e usar um (aponta o pé do arco-íris; `null`: nenhum arco, nada gasto).
  final int Function()? prisms;
  final PrismReading? Function()? usePrism;

  @override
  State<SkyScreen> createState() => _SkyScreenState();
}

class _SkyScreenState extends State<SkyScreen> {
  Timer? _tick;

  /// O próximo evento, calculado uma vez por janela de 3 h (varre até um ano de janelas).
  int? _nextAt;
  ({String event, String climate, int startUtc})? _next;
  List<({String event, String what, bool isEvent, int startUtc})> _items = const [];

  /// A última leitura do prisma, ou a frase de quando não havia arco.
  String? _prism;

  void _usePrism() {
    final r = widget.usePrism?.call();
    setState(() => _prism = r == null
        ? 'O PRISMA FICA CLARO: NENHUM ARCO-ÍRIS AGORA. ELE NÃO SE GASTOU.'
        : 'O PÉ DO ARCO-ÍRIS ESTÁ A ${r.distanceM.round()} M, PARA O ${compassPoint(r.bearingDeg).toUpperCase()} (${r.bearingDeg.round()}°). O PRISMA SE DESFEZ.');
  }

  static String _when(int utc) {
    final d = DateTime.fromMillisecondsSinceEpoch(utc * 1000); // só exibição: o horário do aparelho
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ÀS ${phoneClock(utc)}';
  }

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

  Widget _glyph(ClimateInfo i, {double size = 18}) => SizedBox(width: size, height: size, child: FittedBox(child: CustomPaint(size: const Size(18, 18), painter: WeatherGlyphPainter(i))));

  @override
  Widget build(BuildContext context) {
    final now = widget.nowUtc();
    final cycle = moonCycle(now);
    final toFull = ((0.5 - cycle) % 1) * synodicMonthDays, toNew = ((1 - cycle) % 1) * synodicMonthDays;
    final list = widget.outlook?.call(now, widget.windows) ?? const <SkyWindow>[];
    final shown = widget.shown?.call();
    final active = [for (final w in list.take(1)) if (w.reason != null) w];
    final window = now ~/ 10800;
    if ((widget.nextEvent != null || widget.calendar != null) && _nextAt != window) {
      _nextAt = window;
      _next = widget.nextEvent?.call(now);
      _items = widget.calendar?.call(now) ?? const [];
    }
    // Época 12: o clima e os eventos separados. O "Agora" é só o clima; os eventos vêm em "Eventos ativos".
    final events = list.isEmpty ? const <OutlookEvent>[] : list.first.events;
    final climateNow = shown == null ? null : widget.catalog.of(climateOfStack(shown.id));
    final next = _next;
    final prisms = widget.prisms?.call() ?? 0;
    return ScreenFrame(
      title: 'Céu',
      subtitle: phoneClock(now),
      children: [
        if (shown != null && climateNow != null) ...[
          const SectionTitle('Clima agora'),
          Container(
            key: const Key('sky-now'),
            padding: const EdgeInsets.all(12),
            decoration: panelBox(line: kSignal),
            child: Row(children: [
              _glyph(climateNow, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(climateNow.name.toUpperCase(), style: const TextStyle(fontSize: 16, color: kText)),
                  Text(climateNow.hud.toUpperCase(), style: _body),
                  if (list.isNotEmpty && list.first.climateId != climateNow.id)
                    Text('NO MUNDO: ${widget.catalog.of(list.first.climateId).name.toUpperCase()}. O CLIMA DA REDE É SÓ VISUAL.', style: _dim),
                ]),
              ),
            ]),
          ),
          const SectionTitle('Eventos ativos'),
          if (active.isEmpty && events.isEmpty) const Text('NENHUM EVENTO AGORA.', style: _dim),
          for (final e in events)
            Container(
              key: Key('sky-layer-event-${e.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: panelBox(line: kVeil),
              child: Row(children: [
                _glyph(widget.catalog.of(e.id), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${e.name.toUpperCase()} · ATÉ ${phoneClock(e.endUtc)}${e.waited ? ' · ESPEROU A VAGA' : ''}\n${e.effect.toUpperCase()}\n${e.reason.toUpperCase()}',
                    style: _body,
                  ),
                ),
              ]),
            ),
          for (final w in active)
            Container(
              key: const Key('sky-event'),
              padding: const EdgeInsets.all(12),
              decoration: panelBox(line: kEssence),
              child: Text('${w.reason!.toUpperCase()}: ${widget.catalog.of(w.climateId).name.toUpperCase()}. ${widget.catalog.of(w.climateId).hud.toUpperCase()}', style: _body),
            ),
          const SectionTitle('Próximas janelas'),
          for (final w in list.skip(1))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 44, child: Text(phoneClock(w.startUtc), style: _dim)),
                _glyph(widget.catalog.of(w.climateId)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${widget.catalog.of(w.climateId).hud}${w.reason == null ? '' : ' · ${w.reason}'}${w.events.isEmpty ? '' : ' · EVENTO: ${w.events.map((e) => e.name).join(', ')}'}'.toUpperCase(),
                    style: w.reason == null ? _body : _body.copyWith(color: kEssence),
                  ),
                ),
              ]),
            ),
        ],
        if (widget.calendar != null) ...[
          const SectionTitle('Calendário do Véu'),
          if (_items.isEmpty) const Text('NENHUM EVENTO NO CALENDÁRIO.', key: Key('sky-next-event'), style: _body),
          for (final (i, it) in _items.indexed)
            Text(
              '${it.event.toUpperCase()} · ${it.isEvent ? 'EVENTO' : 'CLIMA'}: ${it.what.toUpperCase()}. ${_when(it.startUtc)}.',
              key: Key(i == 0 ? 'sky-next-event' : 'sky-next-event-$i'),
              style: _body,
            ),
          for (final p in widget.catalog.calendarPending)
            Text(
              '${p.name.toUpperCase()}: ${[for (final c in p.climates) widget.catalog.of(c).name.toUpperCase()].join(' E ')}. ${p.note.toUpperCase()}',
              key: Key('sky-pending-${p.id}'),
              style: _dim,
            ),
        ] else if (widget.nextEvent != null) ...[
          const SectionTitle('Calendário do Véu'),
          Text(
            next == null ? 'NENHUM EVENTO NO CALENDÁRIO.' : 'PRÓXIMO: ${next.event.toUpperCase()}, ${next.climate.toUpperCase()}. ${_when(next.startUtc)}.',
            key: const Key('sky-next-event'),
            style: _body,
          ),
          for (final p in widget.catalog.calendarPending)
            Text(
              '${p.name.toUpperCase()}: ${[for (final c in p.climates) widget.catalog.of(c).name.toUpperCase()].join(' E ')}. ${p.note.toUpperCase()}',
              key: Key('sky-pending-${p.id}'),
              style: _dim,
            ),
        ],
        if (widget.usePrism != null && (prisms > 0 || _prism != null)) ...[
          const SectionTitle('Arco-íris'),
          if (_prism != null) Text(_prism!, key: const Key('sky-prism-reading'), style: _body.copyWith(color: kSignal)),
          if (prisms > 0)
            TextButton(
              key: const Key('sky-use-prism'),
              onPressed: _usePrism,
              child: Text('USAR PRISMA DE ORVALHO ($prisms)', style: _body.copyWith(color: kSignal)),
            ),
        ],
        const SectionTitle('Lua'),
        Row(children: [
          CustomPaint(key: const Key('sky-moon'), size: const Size(48, 48), painter: MoonPainter(cycle, widget.lat() < 0)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(moonPhaseNames[moonPhase(now)]!.toUpperCase(), style: const TextStyle(fontSize: 16, color: kText)),
              Text('${(moonIllumination(now) * 100).round()}% ILUMINADA', style: _body),
              Text('CHEIA EM ${toFull.round()} DIAS · NOVA EM ${toNew.round()} DIAS', style: _dim),
            ]),
          ),
        ]),
      ],
    );
  }
}
