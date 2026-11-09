/// Seção dos Ajustes para as permissões opcionais do aparelho: contador de passos e leitura das notificações da corrida,
/// mais o backup automático do Android. Tudo desligado por padrão e silencioso quando o sensor ou a permissão faltam. O modo
/// bolso e a Patrulha moram no app Patrulha.
library;

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../../world/device_sensors.dart';
import '../../world/steps.dart';
import '../colors.dart';
import '../menu/phone_shell.dart' show phoneRoute;
import '../menu/screen_frame.dart';
import 'ride_notifications_screen.dart';
import '../tuning/tuning_screen.dart' show PixelButton;

/// Chaves dos interruptores em `GameState.settings`.
const kStepsSetting = 'steps_counter';
const kPocketSetting = 'pocket_mode';

class ConnectivitySection extends StatelessWidget {
  const ConnectivitySection({required this.state, required this.data, required this.nowUtc, this.sensors = const DeviceSensors(), super.key});

  final GameState state;
  final GameData data;
  final int Function() nowUtc;
  final DeviceSensors sensors;

  Future<void> _setSteps(bool on) async {
    final tracker = StepTracker(state: state, balance: data.steps, read: sensors.readSteps);
    if (!on) {
      tracker.reset();
      state.setSetting(kStepsSetting, false);
      return;
    }
    if (!await sensors.requestStepsPermission()) return; // negada: o interruptor continua desligado
    tracker.reset(); // a base é a leitura de agora; passos de antes não contam
    state.setSetting(kStepsSetting, true);
    await tracker.sync(data.schedule.select(nowUtc()).epoch);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: state,
        builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Contador de passos', style: TextStyle(fontSize: 8)),
            subtitle: Text(
              'A cada ${data.steps.perSpark} passos, uma Fagulha do bioma onde você esteve por último, até ${data.steps.dailyCap} passos por dia. Funciona sem GPS e com o app fechado; os passos da Patrulha não contam duas vezes. Pede a permissão de atividade física só ao ligar',
              style: const TextStyle(fontSize: 8, color: kDim),
            ),
            value: state.setting(kStepsSetting),
            activeThumbColor: kSignal,
            onChanged: _setSteps,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Corrida no mapa', style: TextStyle(fontSize: 8)),
            subtitle: Text(
              '${state.setting(kRideNotifySetting) ? 'Ligada' : 'Desligada'}. Lê só as notificações do Uber e da 99, para o seu carro aparecer no mapa',
              style: const TextStyle(fontSize: 8, color: kDim),
            ),
            onTap: () => Navigator.of(context).push(phoneRoute<void>(RideNotificationsScreen(state: state))),
          ),
          const SectionTitle('Backup automático'),
          const Text(
            'O Android pode guardar o seu save no Google Drive da conta do aparelho. Ele liga nas configurações do Android, '
            'em Sistema > Backup. Vale só com o Kenoma instalado de novo na mesma conta. O app não envia nada por conta própria.',
            style: TextStyle(fontSize: 8, color: kDim, height: 1.8),
          ),
          const SizedBox(height: 8),
          PixelButton(label: 'Abrir ajustes do Android', color: kVeil, onTap: () => sensors.openBackupSettings()),
        ]),
      );
}
