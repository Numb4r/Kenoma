/// Seção dos Ajustes para o que é opcional e depende do aparelho: backup automático do Android, contador de passos
/// e modo bolso. Tudo desligado por padrão e silencioso quando o sensor ou a permissão faltam.
library;

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../../world/device_sensors.dart';
import '../../world/steps.dart';
import '../colors.dart';
import '../menu/screen_frame.dart';
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
          const SectionTitle('Backup automático'),
          const Text(
            'O Android pode guardar o seu save no Google Drive da conta do aparelho. Ele liga nas configurações do Android, '
            'em Sistema > Backup. Vale só com o Kenoma instalado de novo na mesma conta. O app não envia nada por conta própria.',
            style: TextStyle(fontSize: 8, color: kDim, height: 1.8),
          ),
          const SizedBox(height: 8),
          PixelButton(label: 'Abrir ajustes do Android', color: kVeil, onTap: () => sensors.openBackupSettings()),
          const SectionTitle('Sensores'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Contador de passos', style: TextStyle(fontSize: 8)),
            subtitle: Text(
              'A cada ${data.steps.perSpark} passos, uma Fagulha do bioma onde você esteve por último. Funciona sem GPS. Pede a permissão de atividade física só ao ligar',
              style: const TextStyle(fontSize: 8, color: kDim),
            ),
            value: state.setting(kStepsSetting),
            activeThumbColor: kSignal,
            onChanged: _setSteps,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Modo bolso', style: TextStyle(fontSize: 8)),
            subtitle: const Text(
              'Com o celular no bolso (sensor de proximidade coberto) o mapa escurece e o celular vibra quando um Eco chega ao alcance de toque. A coleta continua',
              style: TextStyle(fontSize: 8, color: kDim),
            ),
            value: state.setting(kPocketSetting),
            activeThumbColor: kSignal,
            onChanged: (v) => state.setSetting(kPocketSetting, v),
          ),
        ]),
      );
}
