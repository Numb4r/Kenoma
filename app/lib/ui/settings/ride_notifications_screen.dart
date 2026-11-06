/// O interruptor das notificações de corrida e a explicação dele. Opcional: sem isso a corrida funciona pelos botões.
library;

import 'package:flutter/material.dart';

import '../../player/game_state.dart';
import '../../travel/system_bridge.dart';
import '../colors.dart';
import '../menu/screen_frame.dart';
import '../tuning/tuning_screen.dart' show PixelButton;

/// Chave do interruptor em `GameState.settings`.
const kRideNotifySetting = 'ride_notifications';

class RideNotificationsScreen extends StatefulWidget {
  const RideNotificationsScreen({required this.state, this.bridge = const SystemBridge(), super.key});

  final GameState state;
  final SystemBridge bridge;

  @override
  State<RideNotificationsScreen> createState() => _RideNotificationsScreenState();
}

class _RideNotificationsScreenState extends State<RideNotificationsScreen> with WidgetsBindingObserver {
  bool _access = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh(); // o jogador pode ter dado o acesso nos ajustes do Android
  }

  Future<void> _refresh() async {
    final on = await widget.bridge.notificationAccess();
    if (mounted) setState(() => _access = on);
  }

  void _set(bool on) {
    widget.state.setSetting(kRideNotifySetting, on);
    if (!on) widget.bridge.setRideRelay(false);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 8, color: kText, height: 1.8);
    return ScreenFrame(title: 'Corrida no mapa', children: [
      const Text(
        'Com isto ligado, o carro da sua corrida de Uber ou 99 aparece no mapa sozinho: chega junto com a estimativa do app e '
        'você embarca nele quando a viagem começa. O jogo sabe disso lendo as notificações desses dois apps.',
        style: style,
      ),
      const SizedBox(height: 8),
      const Text(
        'Só Uber e 99: as notificações dos outros apps são ignoradas sem leitura. Nada é guardado nem enviado: o texto é processado '
        'na hora e descartado.',
        style: style,
      ),
      const SizedBox(height: 8),
      const Text('Sem isto o fluxo é o mesmo, com botões: você informa o tempo de chegada, toca em Entrei e em Cheguei.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ler notificações de corrida', style: TextStyle(fontSize: 8)),
        value: widget.state.setting(kRideNotifySetting),
        activeThumbColor: kSignal,
        onChanged: _set,
      ),
      Text(_access ? 'O Android já deu o acesso às notificações.' : 'O Android ainda não deu o acesso às notificações.', style: TextStyle(fontSize: 8, color: _access ? kSignal : kEssence, height: 1.8)),
      const SizedBox(height: 8),
      PixelButton(label: 'Abrir ajustes do Android', color: kVeil, onTap: () => widget.bridge.openNotificationSettings()),
      const SizedBox(height: 8),
      const Text(
        'Em APK instalado por fora, no Android 13 ou mais novo, o Android pode bloquear a opção. Nesse caso abra a tela de '
        'informações do app, toque no menu de três pontos e escolha "Permitir configurações restritas".',
        style: TextStyle(fontSize: 8, color: kDim, height: 1.8),
      ),
    ]);
  }
}
