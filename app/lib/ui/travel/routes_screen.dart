/// O app Rotas do celular (docs/GDD.md, "Celular mágico"): o Modo Viagem inteiro. Destino pela busca ou pelo mapa,
/// veículo, rota, os atalhos do Uber e da 99, o painel da corrida e o baú. Os painéis são os de `travel_overlay.dart`.
library;

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../../travel/travel_session.dart';
import '../colors.dart';
import '../menu/phone_shell.dart' show phoneRoute;
import '../menu/screen_frame.dart';
import '../settings/ride_notifications_screen.dart';
import 'travel_overlay.dart';

class RoutesScreen extends StatelessWidget {
  const RoutesScreen({
    required this.travel,
    required this.state,
    required this.data,
    required this.appVersion,
    required this.playerLat,
    required this.playerLon,
    required this.onMessage,
    required this.onPickOnMap,
    super.key,
  });

  final TravelSession travel;
  final GameState state;
  final GameData data;
  final String appVersion;
  final double Function() playerLat;
  final double Function() playerLon;
  final void Function(String message, {int seconds}) onMessage;

  /// Fecha o celular para o jogador tocar o destino no mapa.
  final VoidCallback onPickOnMap;

  @override
  Widget build(BuildContext context) => ScreenFrame(title: 'Rotas', children: [
        TravelOverlay(
          travel: travel,
          state: state,
          data: data,
          appVersion: appVersion,
          playerLat: playerLat,
          playerLon: playerLon,
          onMessage: onMessage,
          embedded: true,
          onPickOnMap: onPickOnMap,
        ),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: state,
          builder: (context, _) => ListTile(
            key: const Key('routes-ride-notify'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Corrida no mapa', style: TextStyle(fontSize: 8)),
            subtitle: Text(
              '${state.setting(kRideNotifySetting) ? 'Ligada' : 'Desligada'}. Lê só as notificações do Uber e da 99, para o seu carro aparecer no mapa',
              style: const TextStyle(fontSize: 8, color: kDim),
            ),
            onTap: () => Navigator.of(context).push(phoneRoute<void>(RideNotificationsScreen(state: state))),
          ),
        ),
      ]);
}
