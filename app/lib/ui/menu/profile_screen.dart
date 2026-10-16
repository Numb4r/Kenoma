/// Placeholder do app Perfil (o chefe substitui o miolo). Mantém o nome da classe e os parâmetros.
library;

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../tema.dart';
import 'phone_shell.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({required this.state, required this.data, super.key});

  final GameState state;
  final GameData data;

  @override
  Widget build(BuildContext context) => PhoneScreen(
        title: 'Perfil',
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) => Padding(
            padding: const EdgeInsets.all(KEspaco.s3),
            child: Text('NÍVEL ${state.playerLevel}', style: KTexto.numero),
          ),
        ),
      );
}
