/// O celular do Conjurador (docs/fase0-spec.md, seção 9): o botão no centro de baixo do mapa abre o aparelho, que
/// desliza de baixo com a grade de apps (`phone_grid.dart`). Os apps e o nível que libera cada um estão em `phone_apps.dart`.
library;

import 'package:flutter/material.dart';

import '../../core/tiles.dart';
import '../../core/weather.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../collection/collection_screen.dart';
import '../pressable.dart';
import '../tema.dart';
import 'bench_screen.dart';
import 'bestiary_screen.dart';
import 'chat_screen.dart';
import 'circle_screen.dart';
import 'forum_screen.dart';
import 'phone_apps.dart';
import 'phone_grid.dart';
import 'phone_shell.dart';
import 'phone_status.dart';
import 'profile_screen.dart';

/// O botão do celular: um aparelho pequeno de pixels, no centro de baixo. Um ponto laranja avisa que há mensagem
/// nova do mentor ou pedido do fórum pronto para entregar.
class PhoneButton extends StatelessWidget {
  const PhoneButton({required this.onTap, this.alert = false, super.key});

  final VoidCallback onTap;
  final bool alert;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KCores.superficie1,
              border: Border.all(color: KCores.veuVioleta, width: kContornoDp),
              borderRadius: BorderRadius.circular(KCanto.r1),
              boxShadow: KSombra.pixel,
            ),
            child: CustomPaint(size: const Size(20, 32), painter: _PhonePainter()),
          ),
          if (alert)
            Positioned(
              right: -4,
              top: -4,
              child: Container(key: const Key('phone-alert'), width: 15, height: 15, decoration: BoxDecoration(color: KCores.brasaLaranja, border: Border.all(color: KCores.contorno, width: 3))),
            ),
        ]),
      );
}

class _PhonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(2, 0, size.width - 4, size.height);
    canvas.drawRect(body, Paint()..color = KCores.fundo..isAntiAlias = false);
    canvas.drawRect(body, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = KCores.veuVioleta..isAntiAlias = false);
    canvas.drawRect(Rect.fromLTWH(5, 4, size.width - 10, size.height - 12), Paint()..color = KCores.sinalCiano..isAntiAlias = false);
    canvas.drawRect(Rect.fromLTWH(size.width / 2 - 2, size.height - 5, 4, 2), Paint()..color = KCores.veuVioleta..isAntiAlias = false);
  }

  @override
  bool shouldRepaint(_PhonePainter old) => false;
}

/// Abre o celular. Cada app empilha a sua tela por cima do aparelho: voltar devolve ao celular. A Visão espectral
/// fecha o celular e volta ao mapa.
Future<void> showPhoneMenu(
  BuildContext context, {
  required GameState state,
  required GameData data,
  required Widget Function() settings,
  required Widget Function() radar,
  required int Function() nowUtc,
  required int Function() epochId,
  Weather Function()? weather,
  double Function()? lat,
}) {
  final status = PhoneStatusSource(nowUtc: nowUtc, lat: lat ?? () => 0, weather: weather);
  phoneStatusSource = status;

  void open(String id) {
    final screen = switch (id) {
      PhoneAppId.radar => radar(),
      PhoneAppId.bestiary => BestiaryScreen(state: state, data: data),
      PhoneAppId.circle => CircleScreen(state: state, data: data),
      PhoneAppId.bag => CollectionScreen(state: state, data: data),
      PhoneAppId.bench => BenchScreen(state: state, data: data),
      PhoneAppId.chat => ChatScreen(state: state, data: data),
      PhoneAppId.forum => ForumScreen(state: state, data: data, nowUtc: nowUtc, epochId: epochId),
      PhoneAppId.profile => ProfileScreen(
        state: state,
        data: data,
        nowUtc: nowUtc,
        cellSideM: lat == null ? null : () => 2 * metersPerCell(lat()),
        onOpenSettings: () => Navigator.of(context).push(phoneRoute<void>(settings())),
      ),
      PhoneAppId.settings => settings(),
      _ => null, // vision
    };
    if (screen == null) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).push(phoneRoute<void>(screen));
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    sheetAnimationStyle: sheetSlide,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (_) => PhoneSheet(state: state, data: data, status: status, onOpen: open),
  );
}

/// Se o celular tem algo a avisar: algum app liberado com novidade (mensagem não lida, pedido pronto etc.).
bool phoneHasAlert(GameState s, [PhoneApps? apps]) {
  if (apps != null) return apps.apps.any((a) => phoneAppHasBadge(s, a));
  return phoneAppBadges.values.any((f) => f(s));
}
