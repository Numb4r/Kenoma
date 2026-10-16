/// Peças comuns das telas do celular: moldura com título e seta de voltar, silhueta de criatura e o
/// carregador de sprites. No estilo das telas que já existem (painel ameixa, pixel, Silkscreen).
library;

import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../colors.dart';
import '../sprites/sprite_image.dart';

class ScreenFrame extends StatelessWidget {
  const ScreenFrame({required this.title, required this.children, this.subtitle, super.key});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kOutline,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Row(children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
                child: const SizedBox(width: 48, height: 48, child: Center(child: Text('<', style: TextStyle(fontSize: 24, color: kText)))),
              ),
              Expanded(child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 24, color: kVeil))),
            ]),
            if (subtitle != null) Text(subtitle!.toUpperCase(), style: const TextStyle(fontSize: 8, color: kDim)),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Título de seção dentro de uma tela.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 8, bottom: 8), child: Text(text.toUpperCase(), style: const TextStyle(fontSize: 16, color: kSignal)));
}

/// O sprite de uma espécie; [silhouette] pinta só a forma, para o que o jogador ainda não viu.
class SpeciesImage extends StatelessWidget {
  const SpeciesImage({required this.sprite, this.silhouette = false, this.size = 64, this.tint, super.key});

  final EcoSprite? sprite;
  final bool silhouette;
  final double size;

  /// A paleta da variante (0xAARRGGBB): um tom por cima da silhueta, sem arte nova.
  final int? tint;

  @override
  Widget build(BuildContext context) {
    final img = sprite == null ? null : RawImage(image: sprite!.normal, filterQuality: FilterQuality.none, fit: BoxFit.contain);
    return SizedBox(
      width: size,
      height: size,
      child: img == null
          ? null
          : silhouette
              ? ColorFiltered(colorFilter: const ColorFilter.mode(kPanelLine, BlendMode.srcIn), child: img)
              : tint == null
                  ? img
                  : ColorFiltered(colorFilter: ColorFilter.mode(Color(tint!).withValues(alpha: 0.4), BlendMode.srcATop), child: img),
    );
  }
}

/// Carrega os sprites de todas as espécies; chama [onLoaded] quando terminar.
Future<Map<String, EcoSprite>> loadSpecies(GameData data) async => {for (final s in data.tuning.species) s.id: await EcoSprite.load(s.id)};

/// Caixa de painel com contorno, o fundo das fichas.
BoxDecoration panelBox({Color line = kPanelLine}) => BoxDecoration(color: kPanel, border: Border.all(color: line, width: 2));
