/// A tela do celular: moldura de aparelho, barra de status do mundo e a grade de apps. App acima do nível aparece com
/// glitch e "???"; o app recém-liberado se forma com a costura violeta e o Familiar comenta num balão.
library;

import 'package:flutter/material.dart';

import '../../core/features.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../pressable.dart';
import '../tema.dart';
import 'phone_apps.dart';
import 'phone_icons.dart';
import 'phone_status.dart';

class PhoneSheet extends StatefulWidget {
  const PhoneSheet({required this.state, required this.data, required this.status, required this.onOpen, super.key});

  final GameState state;
  final GameData data;
  final PhoneStatusSource status;

  /// Abre o app [id] (liberado). Quem chama decide a tela.
  final void Function(String id) onOpen;

  @override
  State<PhoneSheet> createState() => _PhoneSheetState();
}

class _PhoneSheetState extends State<PhoneSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _form = AnimationController(vsync: this, duration: phoneFormDuration);
  late final Set<String> _forming = {for (final a in widget.data.phone.unseen(widget.state)) a.id};
  late final List<String> _lines = [for (final a in widget.data.phone.unseen(widget.state)) if (widget.data.mentor.phoneUnlock[a.id] != null) widget.data.mentor.phoneUnlock[a.id]!];

  @override
  void initState() {
    super.initState();
    if (_forming.isEmpty) return;
    _form.addStatusListener((s) {
      if (s != AnimationStatus.completed) return;
      for (final id in _forming) {
        widget.state.setSetting(phoneSeenKey(id), true);
      }
    });
    _form.forward();
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final apps = [for (final a in widget.data.phone.apps) if (a.id != PhoneAppId.radar || streetLifeEnabled) a];
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 420, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: Container(
            margin: const EdgeInsets.only(top: KEspaco.s2),
            padding: const EdgeInsets.all(KCanto.r2),
            decoration: BoxDecoration(
              color: KCores.superficie2,
              border: Border.all(color: KCores.contorno, width: kContornoDp),
              borderRadius: BorderRadius.circular(KCanto.r2),
              boxShadow: KSombra.pixel,
            ),
            child: Container(
              key: const Key('phone-screen'),
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(color: KCores.fundo, border: Border.all(color: KCores.contorno, width: kContornoDp)),
              child: ListenableBuilder(
                listenable: Listenable.merge([widget.state, _form]),
                builder: (context, _) => Column(children: [
                  PhoneStatusBar(source: widget.status),
                  Expanded(
                    child: GridView.count(
                      padding: const EdgeInsets.all(KEspaco.s3),
                      crossAxisCount: 3,
                      mainAxisSpacing: KEspaco.s2,
                      crossAxisSpacing: KEspaco.s2,
                      childAspectRatio: 0.95,
                      children: [for (final a in apps) _AppTile(app: a, state: widget.state, forming: _forming.contains(a.id), t: _form.value, onOpen: widget.onOpen)],
                    ),
                  ),
                  if (_lines.isNotEmpty) _Balloon(text: _lines.first, more: _lines.length - 1, onTap: () => setState(() => _lines.removeAt(0))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({required this.app, required this.state, required this.forming, required this.t, required this.onOpen});

  final PhoneApp app;
  final GameState state;
  final bool forming;
  final double t;
  final void Function(String id) onOpen;

  @override
  Widget build(BuildContext context) {
    final locked = !app.unlockedAt(state.playerLevel);
    final mode = locked ? PhoneIconMode.locked : (forming ? PhoneIconMode.forming : PhoneIconMode.normal);
    return Pressable(
      key: Key('app-${app.id}'),
      onTap: locked ? null : () => onOpen(app.id),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KCores.superficie1,
              border: Border.all(color: KCores.contorno, width: kContornoDp),
              borderRadius: BorderRadius.circular(KCanto.r1),
              boxShadow: locked ? null : KSombra.pixel,
            ),
            child: CustomPaint(size: const Size(48, 48), painter: PhoneIconPainter(app.id, mode: mode, t: t)),
          ),
          if (phoneAppHasBadge(state, app))
            Positioned(
              right: -4,
              top: -4,
              child: Container(key: Key('badge-${app.id}'), width: 15, height: 15, decoration: BoxDecoration(color: KCores.brasaLaranja, border: Border.all(color: KCores.contorno, width: 3))),
            ),
        ]),
        const SizedBox(height: KEspaco.s1),
        Text(
          locked ? '???' : app.label.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 2,
          style: KTexto.rotulo.copyWith(fontSize: 9, color: locked ? KCores.textoMudo : KCores.texto),
        ),
      ]),
    );
  }
}

/// O balão do Familiar dentro do celular; tocar passa para a próxima fala (ou fecha).
class _Balloon extends StatelessWidget {
  const _Balloon({required this.text, required this.more, required this.onTap});

  final String text;
  final int more;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          key: const Key('familiar-balloon'),
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: kToqueMinDp),
          margin: const EdgeInsets.fromLTRB(KEspaco.s2, 0, KEspaco.s2, KEspaco.s2),
          padding: const EdgeInsets.all(KEspaco.s2),
          decoration: BoxDecoration(
            color: KCores.superficie2,
            border: Border.all(color: KCores.veuVioleta, width: kContornoDp),
            borderRadius: BorderRadius.circular(KCanto.r1),
            boxShadow: KSombra.pixel,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(more > 0 ? 'FAMILIAR · +$more' : 'FAMILIAR', style: KTexto.rotulo.copyWith(color: KCores.veuClaro, fontSize: 10)),
            const SizedBox(height: KEspaco.s1),
            Text(text, style: KTexto.corpo.copyWith(fontSize: 14)),
          ]),
        ),
      );
}
