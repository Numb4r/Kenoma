/// O celular do Conjurador (docs/fase0-spec.md, seção 9): o botão no centro de baixo do mapa abre este menu
/// com Coleção, Círculo, Bestiário e Bancada.
library;

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../collection/collection_screen.dart';
import '../colors.dart';
import '../tuning/tuning_screen.dart' show PixelButton;
import 'bench_screen.dart';
import 'bestiary_screen.dart';
import 'circle_screen.dart';

/// O botão do celular: um aparelho pequeno de pixels, no centro de baixo.
class PhoneButton extends StatelessWidget {
  const PhoneButton({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: kOutline.withValues(alpha: 0.9), border: Border.all(color: kVeil, width: 3)),
          child: CustomPaint(size: const Size(20, 32), painter: _PhonePainter()),
        ),
      );
}

class _PhonePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(2, 0, size.width - 4, size.height);
    canvas.drawRect(body, Paint()..color = kPanel..isAntiAlias = false);
    canvas.drawRect(body, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = kVeil..isAntiAlias = false);
    canvas.drawRect(Rect.fromLTWH(5, 4, size.width - 10, size.height - 12), Paint()..color = kSignal..isAntiAlias = false);
    canvas.drawRect(Rect.fromLTWH(size.width / 2 - 2, size.height - 5, 4, 2), Paint()..color = kVeil..isAntiAlias = false);
  }

  @override
  bool shouldRepaint(_PhonePainter old) => false;
}

/// Abre o menu do celular.
Future<void> showPhoneMenu(BuildContext context, {required GameState state, required GameData data, required Widget Function() settings}) {
  void open(Widget screen) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: kPanel,
    shape: const RoundedRectangleBorder(side: BorderSide(color: kVeil, width: 3)),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('CELULAR', style: TextStyle(fontSize: 16, color: kVeil)),
            const SizedBox(height: 16),
            PixelButton(label: 'Coleção', color: kSignal, onTap: () => open(CollectionScreen(state: state, data: data))),
            const SizedBox(height: 8),
            PixelButton(label: 'Círculo', color: kSignal, onTap: () => open(CircleScreen(state: state, data: data))),
            const SizedBox(height: 8),
            PixelButton(label: 'Bestiário', color: kSignal, onTap: () => open(BestiaryScreen(state: state, data: data))),
            const SizedBox(height: 8),
            PixelButton(label: 'Bancada', color: kEssence, onTap: () => open(BenchScreen(state: state, data: data))),
            const SizedBox(height: 8),
            PixelButton(label: 'Ajustes', color: kVeil, onTap: () => open(settings())),
          ],
        ),
      ),
    ),
  );
}
