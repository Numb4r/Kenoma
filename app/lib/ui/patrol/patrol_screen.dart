/// O app Patrulha do celular: liga e desliga a Patrulha do Véu e o modo bolso, mostra a patrulha atual e o histórico das
/// anteriores (os resumos que o diário deixou no Chat), e explica o gasto de bateria e as permissões. O botão de ligar pede
/// as permissões (notificações e localização durante o uso) e liga o serviço.
library;

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../data/geolocator_source.dart';
import '../../patrol/patrol_balance.dart';
import '../../patrol/patrol_controller.dart';
import '../../patrol/patrol_service.dart' show PatrolSim;
import '../../player/game_state.dart';
import '../../world/location_access.dart';
import '../colors.dart';
import '../menu/screen_frame.dart';
import '../settings/connectivity_section.dart' show kPocketSetting;
import '../tuning/tuning_screen.dart' show PixelButton;

/// As patrulhas que acabaram, da mais nova para a mais velha: os resumos que o diário entregou no Chat
/// (`patrol_summary`, com minutos, Fagulhas, materiais e marcas).
List<({int endUtc, int min, int sparks, int materials, int marks})> patrolHistory(GameState s) => [
      for (final e in s.story.chat.delivered.reversed)
        if (e.id == 'patrol_summary')
          (
            endUtc: e.utc,
            min: int.tryParse(e.vars['min'] ?? '') ?? 0,
            sparks: int.tryParse(e.vars['sparks'] ?? '') ?? 0,
            materials: int.tryParse(e.vars['materials'] ?? '') ?? 0,
            marks: int.tryParse(e.vars['marks'] ?? '') ?? 0,
          ),
    ];

String _when(int utc) {
  final t = DateTime.fromMillisecondsSinceEpoch(utc * 1000, isUtc: true).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}

/// Horas até a Patrulha desligar sozinha, do Ajuste (padrão e teto do `balance.json`).
int patrolMaxHours(GameState s, PatrolBalance b) => ((s.settings[kPatrolMaxHoursKey] as int?) ?? b.maxHoursDefault).clamp(1, b.maxHoursLimit);

/// Pede as permissões e liga a Patrulha. Devolve o erro em português, ou `null`. [sim]: debug, sem GPS.
Future<String?> startPatrolFlow({
  required GameState state,
  required PatrolBalance balance,
  LocationGateway gateway = const GeolocatorGateway(),
  int clockOffsetS = 0,
  PatrolSim? sim,
}) async {
  try {
    if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted &&
        await FlutterForegroundTask.requestNotificationPermission() != NotificationPermission.granted) {
      return 'Sem notificações a Patrulha não liga: a notificação fixa é o que mantém o serviço vivo.';
    }
  } catch (_) {
    // sem o plugin (testes): segue
  }
  if (sim == null) {
    final access = await LocationAccessFlow(gateway).ensure(explain: () async => true);
    if (access != LocationAccess.granted) return locationAccessMessage(access);
  }
  state.setSetting(kPatrolIntroSeenKey, true);
  return PatrolController.instance.start(tickS: balance.tickS, maxDurationS: patrolMaxHours(state, balance) * 3600, clockOffsetS: clockOffsetS, sim: sim);
}

class PatrolScreen extends StatelessWidget {
  const PatrolScreen({required this.state, required this.balance, this.onMessage, super.key});

  final GameState state;
  final PatrolBalance balance;
  final void Function(String message)? onMessage;

  @override
  Widget build(BuildContext context) {
    const body = TextStyle(fontSize: 8, color: kText, height: 1.8);
    final c = PatrolController.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([c, state]),
      builder: (context, _) => ScreenFrame(title: 'Patrulha', children: [
        if (c.running) ...[
          Text('LIGADA · ${c.status['min'] ?? 0} MIN · ${c.status['sparks'] ?? 0} FAGULHAS · ${c.status['marks'] ?? 0} MARCAS', key: const Key('patrol-now'), style: const TextStyle(fontSize: 8, color: kSignal)),
          const SizedBox(height: 8),
          PixelButton(label: 'Encerrar a Patrulha', color: kEssence, onTap: () => c.stop()),
        ] else
          PixelButton(
            label: 'Ligar a Patrulha',
            color: kSignal,
            onTap: () async {
              final err = await startPatrolFlow(state: state, balance: balance);
              onMessage?.call(err ?? 'Patrulha ligada');
            },
          ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('pocket-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Modo bolso', style: TextStyle(fontSize: 8)),
          subtitle: const Text(
            'Com o celular no bolso (sensor de proximidade coberto) o mapa escurece e o celular vibra quando um Eco chega ao alcance de toque. A coleta continua. Com a Patrulha ligada, vale sempre',
            style: TextStyle(fontSize: 8, color: kDim),
          ),
          value: state.setting(kPocketSetting),
          activeThumbColor: kSignal,
          onChanged: (v) => state.setSetting(kPocketSetting, v),
        ),
        const SectionTitle('Anteriores'),
        if (patrolHistory(state).isEmpty) const Text('NENHUMA PATRULHA AINDA.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
        for (final p in patrolHistory(state).take(20))
          Text('${_when(p.endUtc)} · ${p.min} MIN · ${p.sparks} FAGULHAS · ${p.materials} MATERIAIS · ${p.marks} MARCAS', style: body),
        const SectionTitle('Como funciona'),
        const Text(
          'Com a Patrulha ligada o jogo continua com o app fechado ou a tela bloqueada, como um app de corrida. '
          'Ela coleta as Fagulhas e os materiais que entram na Aura e marca os Ecos que passam a até 30 m. '
          'O celular vibra a cada marca, com outro padrão para Brilhante, variante e Espírito. '
          'Sintonizar continua sendo com o app aberto.',
          style: body,
        ),
        const SectionTitle('Bateria'),
        Text(
          'O GPS fica ligado em precisão equilibrada, uma leitura a cada ${balance.gpsIntervalS} s ou ${balance.gpsDistanceM} m. '
          'A meta é gastar até 6% de bateria por hora. Ela desliga sozinha depois do tempo abaixo, com bateria abaixo de '
          '${balance.batteryMinPct}% ou com o GPS ${balance.gpsTimeoutS ~/ 60} minutos sem sinal.',
          style: body,
        ),
        const SectionTitle('Permissões'),
        const Text(
          'Notificações, para a notificação fixa com os botões Abrir e Encerrar, e localização durante o uso. '
          'A Patrulha começa com o app à vista, então não precisa de localização o tempo todo.',
          style: body,
        ),
        const SectionTitle('Desliga depois de'),
        Wrap(spacing: 8, children: [
          for (var h = balance.maxHoursDefault; h <= balance.maxHoursLimit; h++)
            ChoiceChip(
              label: Text('$h h', style: const TextStyle(fontSize: 8)),
              selected: patrolMaxHours(state, balance) == h,
              onSelected: (_) => state.setSetting(kPatrolMaxHoursKey, h),
            ),
        ]),
      ]),
    );
  }
}
