/// A aba Fusão da Bancada: escolha da família, dos cinco Ecos, o aviso do Círculo, o resumo do Espírito e o botão Fundir.
/// Só desenha e repassa o toque: a regra está em `crafting/fusion.dart`. Antes do nível 6 aparece como ???.
library;

import 'package:flutter/material.dart';

import '../../crafting/fusion.dart';
import '../../data/game_data.dart';
import '../../player/attributes.dart';
import '../../player/game_state.dart';
import '../pressable.dart';
import '../sprites/sprite_image.dart';
import '../tema.dart';
import 'fusion_animation.dart';
import 'screen_frame.dart' show SpeciesImage;

const _blockerText = {
  FusionBlocker.locked: 'Libera no nível 6',
  FusionBlocker.unknownFamily: 'Família desconhecida',
  FusionBlocker.wrongCount: 'Escolha os cinco Ecos',
  FusionBlocker.invalidEco: 'Eco inválido',
  FusionBlocker.missingEssence: 'Falta Essência',
};

class FusionPanel extends StatefulWidget {
  const FusionPanel({required this.state, required this.data, required this.sprites, this.nowUtc, super.key});

  final GameState state;
  final GameData data;
  final Map<String, EcoSprite> sprites;

  /// O relógio do jogo (segundos UTC). `null`: o relógio do aparelho.
  final int Function()? nowUtc;

  @override
  State<FusionPanel> createState() => _FusionPanelState();
}

class _FusionPanelState extends State<FusionPanel> {
  late String _family = fusionFamilies(widget.data).first;
  final _picked = <String>[];

  GameState get _s => widget.state;
  GameData get _d => widget.data;

  void _toggle(String uid) {
    setState(() {
      if (!_picked.remove(uid) && _picked.length < _s.cb.fusionEcoCount) _picked.add(uid);
    });
  }

  Future<bool> _confirmCircle(int n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: KCores.superficie1,
        shape: const RoundedRectangleBorder(side: BorderSide(color: KCores.brasaLaranja, width: kContornoDp)),
        title: Text('ECO NO CÍRCULO', style: KTexto.titulo.copyWith(color: KCores.brasaLaranja)),
        content: Text('$n dos Ecos escolhidos ${n == 1 ? 'está' : 'estão'} no Círculo. A fusão ${n == 1 ? 'o consome' : 'os consome'} e a vaga fica vazia.', style: KTexto.corpo),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('CANCELAR', style: KTexto.rotulo.copyWith(color: KCores.textoMudo))),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('FUNDIR', style: KTexto.rotulo.copyWith(color: KCores.brasaLaranja))),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _fuse() async {
    final plan = fusionPlan(_s, _d, _family, _picked);
    if (plan == null) return;
    final confirm = plan.circleUids.isNotEmpty;
    if (confirm && !await _confirmCircle(plan.circleUids.length)) return;
    if (!mounted) return;
    final spirit = fuse(_s, _d, _family, _picked, nowUtc: (widget.nowUtc ?? () => DateTime.now().millisecondsSinceEpoch ~/ 1000)(), confirmCircle: confirm);
    if (spirit == null) return;
    setState(_picked.clear);
    final name = _d.species(spirit.speciesId)?.name ?? spirit.speciesId;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: KCores.fundo,
      transitionDuration: Duration.zero,
      pageBuilder: (dialog, _, _) => FusionAnimation(
        eco: widget.sprites['$_family.eco']?.normal,
        spirit: widget.sprites[spirit.speciesId]?.normal,
        durationS: _s.cb.fusionAnimS,
        onDone: () => Navigator.of(dialog).pop(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text('$name NV ${spirit.level} entrou na coleção')));
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s.playerLevel < s.cb.fusionLevel) {
      return Container(
        key: const Key('fusion-locked'),
        padding: const EdgeInsets.all(KEspaco.s2),
        decoration: BoxDecoration(color: KCores.superficie1, border: Border.all(color: KCores.contorno, width: kContornoDp)),
        child: Text('??? LIBERADA NO NÍVEL ${s.cb.fusionLevel}', style: KTexto.rotulo.copyWith(color: KCores.textoMudo)),
      );
    }
    final ecos = fusibleEcos(s, _family).reversed.toList();
    _picked.removeWhere((u) => !ecos.any((c) => c.uid == u));
    final plan = fusionPlan(s, _d, _family, _picked);
    final blocker = fusionBlocker(s, _d, _family, _picked, confirmCircle: true);
    final essence = essenceOfFamily(_d, _family)!;
    final cost = s.cb.fusionEssenceCost;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${s.cb.fusionEcoCount} ECOS DA MESMA FAMÍLIA + $cost ${_d.itemName(essence).toUpperCase()} VIRAM UM ESPÍRITO. OS ECOS ESCOLHIDOS SE VÃO.', style: KTexto.corpoPequeno),
      const SizedBox(height: KEspaco.s2),
      Wrap(spacing: KEspaco.s1, runSpacing: KEspaco.s1, children: [
        for (final f in fusionFamilies(_d))
          _Chip(label: _d.species('$f.eco')?.name ?? f, on: f == _family, onTap: () => setState(() {
                _family = f;
                _picked.clear();
              })),
      ]),
      const SizedBox(height: KEspaco.s2),
      Text('${_d.itemName(essence).toUpperCase()}  ${s.count(essence)}/$cost', style: KTexto.rotulo.copyWith(color: s.count(essence) >= cost ? KCores.sinalCiano : KCores.brasaLaranja)),
      const SizedBox(height: KEspaco.s1),
      Text('ECOS ESCOLHIDOS ${_picked.length}/${s.cb.fusionEcoCount}', style: KTexto.rotulo),
      const SizedBox(height: KEspaco.s1),
      if (ecos.isEmpty) Text('NENHUM ECO DESTA FAMÍLIA NA COLEÇÃO.', style: KTexto.corpoPequeno),
      for (final c in ecos) _EcoTile(creature: c, sprite: widget.sprites[c.speciesId], picked: _picked.contains(c.uid), inCircle: s.inCircle(c.uid), traits: traitsCounter(c, _d), onTap: () => _toggle(c.uid)),
      if (plan != null && plan.circleUids.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: KEspaco.s1),
          child: Text('ATENÇÃO: ${plan.circleUids.length} ECO(S) NO CÍRCULO. A VAGA FICA VAZIA.', key: const Key('fusion-circle-warning'), style: KTexto.rotulo.copyWith(color: KCores.brasaLaranja)),
        ),
      if (plan != null && plan.ecos.isNotEmpty) _Summary(plan: plan, data: _d, sprite: widget.sprites[plan.spiritId]),
      const SizedBox(height: KEspaco.s2),
      _Button(label: 'Fundir', enabled: blocker == null, onTap: _fuse),
      if (blocker != null) Padding(padding: const EdgeInsets.only(top: KEspaco.s1), child: Text((_blockerText[blocker] ?? '').toUpperCase(), style: KTexto.corpoPequeno)),
    ]);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.plan, required this.data, required this.sprite});

  final FusionPlan plan;
  final GameData data;
  final EcoSprite? sprite;

  @override
  Widget build(BuildContext context) {
    final spirit = CreatureInstance(uid: '', speciesId: plan.spiritId, level: plan.level, capturedUtc: 0, traits: plan.traits);
    final a = attributesOf(spirit, data);
    return Container(
      key: const Key('fusion-summary'),
      margin: const EdgeInsets.only(top: KEspaco.s2),
      padding: const EdgeInsets.all(KEspaco.s2),
      decoration: BoxDecoration(color: KCores.superficie1, border: Border.all(color: KCores.veuVioleta, width: kContornoDp)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SpeciesImage(sprite: sprite, size: 64, aura: true),
        const SizedBox(width: KEspaco.s2),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((data.species(plan.spiritId)?.name ?? plan.spiritId).toUpperCase(), style: KTexto.rotulo.copyWith(color: KCores.veuClaro)),
            Text('NÍVEL MÉDIO ${plan.level} · PODER ${a.power}', style: KTexto.rotulo),
            Text(a.traitsCounter.toUpperCase(), style: KTexto.rotulo),
            for (final t in a.traits) Text('${t.name}: ${t.description}', style: KTexto.corpoPequeno.copyWith(color: Color(t.tint))),
            if (a.ability != null) Text(a.ability!, style: KTexto.corpoPequeno),
          ]),
        ),
      ]),
    );
  }
}

class _EcoTile extends StatelessWidget {
  const _EcoTile({required this.creature, required this.sprite, required this.picked, required this.inCircle, required this.traits, required this.onTap});

  final CreatureInstance creature;
  final EcoSprite? sprite;
  final bool picked;
  final bool inCircle;
  final String traits;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          key: Key('fusion-eco-${creature.uid}'),
          margin: const EdgeInsets.only(bottom: KEspaco.s1),
          padding: const EdgeInsets.all(KEspaco.s1),
          constraints: const BoxConstraints(minHeight: kToqueMinDp),
          decoration: BoxDecoration(color: picked ? KCores.superficie2 : KCores.superficie1, border: Border.all(color: picked ? KCores.veuVioleta : KCores.contorno, width: kContornoDp)),
          child: Row(children: [
            SpeciesImage(sprite: sprite, size: 48),
            const SizedBox(width: KEspaco.s2),
            Expanded(child: Text('NV ${creature.level} · ${traits.toUpperCase()}', style: KTexto.rotulo)),
            if (inCircle) Text('NO CÍRCULO', style: KTexto.rotulo.copyWith(color: KCores.brasaLaranja)),
            const SizedBox(width: KEspaco.s1),
            Text(picked ? '[X]' : '[ ]', style: KTexto.rotulo.copyWith(color: picked ? KCores.veuVioleta : KCores.textoMudo)),
          ]),
        ),
      );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.on, required this.onTap});

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: kToqueMinDp),
          padding: const EdgeInsets.symmetric(horizontal: KEspaco.s2),
          decoration: BoxDecoration(color: on ? KCores.superficie2 : KCores.fundo, border: Border.all(color: on ? KCores.veuVioleta : KCores.contorno, width: kContornoDp)),
          child: Text(label.toUpperCase(), style: KTexto.rotulo.copyWith(color: on ? KCores.veuVioleta : KCores.textoMudo)),
        ),
      );
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Pressable(
          onTap: enabled ? onTap : null,
          child: Container(
            key: const Key('fusion-button'),
            alignment: Alignment.center,
            constraints: const BoxConstraints(minHeight: kToqueMinDp),
            decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: KCores.veuVioleta, width: kContornoDp), boxShadow: KSombra.pixel),
            child: Text(label.toUpperCase(), style: KTexto.rotulo.copyWith(color: KCores.veuVioleta)),
          ),
        ),
      );
}
