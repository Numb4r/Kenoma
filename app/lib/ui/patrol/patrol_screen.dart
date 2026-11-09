/// A tela da Patrulha do Véu (HUD na primeira vez e Ajustes): o que acontece, o gasto de bateria, até quando ela fica
/// ligada, e o botão que pede as permissões (notificações e localização durante o uso) e liga o serviço.
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
import '../tuning/tuning_screen.dart' show PixelButton;

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
      builder: (context, _) => ScreenFrame(title: 'Patrulha do Véu', children: [
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
        const SizedBox(height: 16),
        if (c.running) ...[
          Text('LIGADA · ${c.status['min'] ?? 0} MIN · ${c.status['sparks'] ?? 0} FAGULHAS · ${c.status['marks'] ?? 0} MARCAS', style: const TextStyle(fontSize: 8, color: kSignal)),
          const SizedBox(height: 8),
          PixelButton(label: 'Encerrar a Patrulha', color: kEssence, onTap: () => c.stop()),
        ] else
          PixelButton(
            label: 'Ligar a Patrulha',
            color: kSignal,
            onTap: () async {
              final err = await startPatrolFlow(state: state, balance: balance);
              onMessage?.call(err ?? 'Patrulha ligada');
              if (err == null && context.mounted) Navigator.of(context).maybePop();
            },
          ),
      ]),
    );
  }
}
