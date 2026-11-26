/// Peças comuns das telas do celular: moldura com título e seta de voltar, silhueta de criatura e o
/// carregador de sprites. No estilo das telas que já existem (painel ameixa, pixel, Silkscreen).
library;

import '../game/creature_art.dart';
import '../game/creature_portrait.dart';
import '../game/spark_portrait.dart';
import 'package:flutter/material.dart';

import '../../data/game_data.dart';
import '../colors.dart';
import '../craft/ui_art.dart' show KitDecoration;
import '../sprites/sprite_image.dart';
import 'phone_shell.dart';

class ScreenFrame extends StatelessWidget {
  const ScreenFrame({required this.title, required this.children, this.subtitle, super.key});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PhoneScreen(
      title: title,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (subtitle != null) Text(subtitle!.toUpperCase(), style: const TextStyle(fontSize: 8, color: kDim)),
          if (subtitle != null) const SizedBox(height: 16),
          ...children,
        ],
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

/// A luz fraca atrás da criatura nas células do Bestiário: um degrau mais claro que a célula no meio, e ainda acima dela na
/// borda, para o contorno escuro (`#1a1424`) das criaturas de sombra se ler. Não toca na criatura. O teste de contraste
/// (`test/ui/bestiary_contrast_test.dart`) usa as mesmas duas cores.
const Color kBacklightCenter = Color(0xFF4F4570), kBacklightRim = Color(0xFF34294E);
const Decoration kBacklight = BoxDecoration(gradient: RadialGradient(colors: [kBacklightCenter, kBacklightRim], radius: 0.5));

/// O sprite de uma espécie; [silhouette] pinta só a forma, para o que o jogador ainda não viu.
class SpeciesImage extends StatelessWidget {
  const SpeciesImage(
      {required this.sprite, this.silhouette = false, this.size = 64, this.tint, this.aura = false, this.speciesId, this.variant, this.sparkType, this.backlit = false, super.key});

  /// A Fagulha do tipo dado (`fire`...): a tira animada do mapa no lugar do sprite. `null`: uma criatura.
  final String? sparkType;

  /// A luz fraca atrás ([kBacklight]), nas células do Bestiário.
  final bool backlit;

  /// 0.25.1: a chave da variante (`urban`...), para o retrato animado trocar as cores como no mapa em vez do [tint].
  final String? variant;

  /// 0.25.0: a espécie, para o retrato animado das que têm arte animada (o Humoth). `null`: o sprite de sempre.
  final String? speciesId;

  final EcoSprite? sprite;
  final bool silhouette;
  final double size;

  /// A paleta da variante (0xAARRGGBB): um tom por cima da silhueta, sem arte nova.
  final int? tint;

  /// A aura do Espírito: o brilho suave do Véu atrás do sprite.
  final bool aura;

  @override
  Widget build(BuildContext context) {
    final art = _art();
    return backlit ? DecoratedBox(decoration: kBacklight, child: art) : art;
  }

  Widget _art() {
    if (sparkType case final t?) return SparkPortrait(type: t, size: size, silhouette: silhouette);
    final animated = speciesId == null || silhouette ? null : CreatureArt.of(speciesId!);
    if (animated?.portrait != null) return CreaturePortrait(art: animated!, size: size, variant: variant);
    final img = sprite == null ? null : RawImage(image: sprite!.normal, filterQuality: FilterQuality.none, fit: BoxFit.contain);
    return Container(
      width: size,
      height: size,
      decoration: aura ? const BoxDecoration(gradient: RadialGradient(colors: [Color(0x669B7BFF), Color(0x009B7BFF)])) : null,
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

/// Caixa de painel, o fundo das fichas. 0.26.0: a moldura `panel` do kit em nove partes (docs/art/estilo-ui.md), cada pixel
/// de arte com 3 dp; [line] diferente da linha comum pinta o aro por cima (destaque, aviso).
Decoration panelBox({Color line = kPanelLine}) => KitDecoration('panel', line: line == kPanelLine ? null : line);

/// O cartão do kit (`card`, ou `card_selected` com o aro violeta): cartões de família, fichas, mensagens, espaços de criatura.
Decoration cardBox({bool selected = false, Color? line}) => KitDecoration(selected ? 'card_selected' : 'card', line: line);

/// A célula do kit (`cell`, rebaixada, ou `cell_selected`): grades, espaços vazios, campos. Lado mínimo de 24 dp.
Decoration cellBox({bool selected = false, Color? line}) => KitDecoration(selected ? 'cell_selected' : 'cell', line: line, fallbackFill: kOutline);
