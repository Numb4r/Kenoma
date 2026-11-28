/// A fusão da Entidade Maior na aba Fusão da Bancada (0.27.0): a família, a receita com os espaços (o que o jogador ainda
/// não viu aparece como ???, como no ritual), os três Espíritos, a criatura de ritual como oferenda, o resumo e o botão.
/// Só desenha e repassa o toque: a regra está em `crafting/major_fusion.dart`.
library;

import 'package:flutter/material.dart';

import '../../crafting/fusion.dart' show essenceOfFamily, fusionFamilies;
import '../../crafting/major_fusion.dart';
import '../../data/game_data.dart';
import '../../player/attributes.dart';
import '../../player/game_state.dart';
import '../kit.dart';
import '../pressable.dart';
import '../sprites/sprite_image.dart';
import '../tema.dart';
import 'fusion_animation.dart';
import 'screen_frame.dart' show SpeciesImage, cardBox;

const _blockerText = {
  MajorBlocker.unknownFamily: 'Família sem Entidade',
  MajorBlocker.wrongCount: 'Escolha os três Espíritos e a oferenda',
  MajorBlocker.invalidPiece: 'Peça inválida',
  MajorBlocker.missingEssence: 'Falta Essência',
};

/// As famílias que têm Entidade Maior e criatura de ritual.
List<String> majorFamilies(GameData data) => [
      for (final f in fusionFamilies(data))
        if (data.species(majorIdOf(f)) != null && data.species(ritualIdOf(f)) != null) f,
    ];

class MajorFusionPanel extends StatefulWidget {
  const MajorFusionPanel({required this.state, required this.data, required this.sprites, this.nowUtc, super.key});

  final GameState state;
  final GameData data;
  final Map<String, EcoSprite> sprites;
  final int Function()? nowUtc;

  @override
  State<MajorFusionPanel> createState() => _MajorFusionPanelState();
}

class _MajorFusionPanelState extends State<MajorFusionPanel> {
  late String _family = majorFamilies(widget.data).first;
  final _spirits = <String>[];
  String? _offering;

  GameState get _s => widget.state;
  GameData get _d => widget.data;

  void _toggleSpirit(String uid) => setState(() {
        if (!_spirits.remove(uid) && _spirits.length < _s.cb.majorSpiritCount) _spirits.add(uid);
      });

  Future<bool> _confirmCircle(int n) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => KitAlertDialog(
          title: Text('NO CÍRCULO', style: KTexto.titulo.copyWith(color: KCores.brasaLaranja)),
          content: Text('$n das peças ${n == 1 ? 'está' : 'estão'} no Círculo. A fusão ${n == 1 ? 'a consome' : 'as consome'} e a vaga fica vazia.', style: KTexto.corpo),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text('CANCELAR', style: KTexto.rotulo.copyWith(color: KCores.textoMudo))),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('FUNDIR', style: KTexto.rotulo.copyWith(color: KCores.brasaLaranja))),
          ],
        ),
      ) ==
      true;

  Future<void> _fuse() async {
    final offering = _offering;
    final plan = offering == null ? null : majorPlan(_s, _d, _family, _spirits, offering);
    if (plan == null || offering == null) return;
    final confirm = plan.circleUids.isNotEmpty;
    if (confirm && !await _confirmCircle(plan.circleUids.length)) return;
    if (!mounted) return;
    final major = fuseMajor(_s, _d, _family, _spirits, offering, nowUtc: (widget.nowUtc ?? () => DateTime.now().millisecondsSinceEpoch ~/ 1000)(), confirmCircle: confirm);
    if (major == null) return;
    setState(() {
      _spirits.clear();
      _offering = null;
    });
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: KCores.fundo,
      transitionDuration: Duration.zero,
      pageBuilder: (dialog, _, _) => FusionAnimation(
        eco: widget.sprites['$_family.spirit']?.normal,
        spirit: widget.sprites[major.speciesId]?.normal,
        durationS: _s.cb.fusionAnimS,
        onDone: () => Navigator.of(dialog).pop(),
      ),
    );
    if (!mounted) return;
    final name = _d.species(major.speciesId)?.name ?? major.speciesId;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text('$name NV ${major.level} entrou na coleção')));
  }

  @override
  Widget build(BuildContext context) {
    final s = _s;
    if (s.playerLevel < s.cb.majorFusionLevel) {
      return Container(
        key: const Key('major-locked'),
        padding: const EdgeInsets.all(KEspaco.s2),
        decoration: cardBox(),
        child: Text('??? LIBERADA NO NÍVEL ${s.cb.majorFusionLevel}', style: KTexto.rotulo.copyWith(color: KCores.textoMudo)),
      );
    }
    final spirits = majorSpirits(s, _family).reversed.toList(), offerings = majorOfferings(s, _family).reversed.toList();
    _spirits.removeWhere((u) => !spirits.any((c) => c.uid == u));
    if (_offering != null && !offerings.any((c) => c.uid == _offering)) _offering = null;
    final plan = majorPlan(s, _d, _family, _spirits, _offering);
    final blocker = majorBlocker(s, _d, _family, _spirits, _offering, confirmCircle: true);
    final essence = essenceOfFamily(_d, _family)!, cost = s.cb.majorEssenceCost;
    String nameOf(MajorSlot slot) => slot.known ? (_d.species(slot.speciesId)?.name ?? slot.speciesId) : '???';
    final recipe = majorRecipe(s, _family);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('TRÊS ESPÍRITOS DA FAMÍLIA, A CRIATURA DE RITUAL DELA COMO OFERENDA E ${_d.itemCount(essence, cost).toUpperCase()} VIRAM A ENTIDADE MAIOR. AS QUATRO SE VÃO.', style: KTexto.corpoPequeno),
      const SizedBox(height: KEspaco.s2),
      Wrap(spacing: KEspaco.s1, runSpacing: KEspaco.s1, children: [
        for (final f in majorFamilies(_d))
          _Chip(label: _d.species('$f.eco')?.name ?? f, on: f == _family, onTap: () => setState(() {
                _family = f;
                _spirits.clear();
                _offering = null;
              })),
      ]),
      const SizedBox(height: KEspaco.s2),
      // A receita: os espaços que o jogador já viu no Bestiário têm nome; os outros, ???.
      Container(
        key: const Key('major-recipe'),
        padding: const EdgeInsets.all(KEspaco.s2),
        decoration: cardBox(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('RECEITA', style: KTexto.rotulo.copyWith(color: KCores.textoMudo)),
          for (final (i, slot) in recipe.indexed)
            Text(
              switch (i) {
                0 => '${slot.count} × ${nameOf(slot)}',
                1 => '+ ${nameOf(slot)} (oferenda)',
                _ => '= ${nameOf(slot)}',
              }.toUpperCase(),
              key: Key('major-slot-$i'),
              style: KTexto.rotulo.copyWith(color: slot.known ? KCores.texto : KCores.textoMudo),
            ),
          Text('+ ${_d.itemName(essence).toUpperCase()}  ${s.count(essence)}/$cost', style: KTexto.rotulo.copyWith(color: s.count(essence) >= cost ? KCores.sinalCiano : KCores.brasaLaranja)),
        ]),
      ),
      const SizedBox(height: KEspaco.s2),
      Text('ESPÍRITOS ESCOLHIDOS ${_spirits.length}/${s.cb.majorSpiritCount}', style: KTexto.rotulo),
      const SizedBox(height: KEspaco.s1),
      if (spirits.isEmpty) Text('NENHUM ESPÍRITO DESTA FAMÍLIA NA COLEÇÃO.', style: KTexto.corpoPequeno),
      for (final c in spirits)
        _Tile(key: Key('major-spirit-${c.uid}'), creature: c, sprite: widget.sprites[c.speciesId], picked: _spirits.contains(c.uid), inCircle: s.inCircle(c.uid), traits: traitsCounter(c, _d), onTap: () => _toggleSpirit(c.uid)),
      const SizedBox(height: KEspaco.s1),
      Text('OFERENDA ${_offering == null ? 0 : 1}/1', style: KTexto.rotulo),
      const SizedBox(height: KEspaco.s1),
      if (offerings.isEmpty) Text('NENHUMA CRIATURA DE RITUAL DESTA FAMÍLIA NA COLEÇÃO.', style: KTexto.corpoPequeno),
      for (final c in offerings)
        _Tile(
          key: Key('major-offering-${c.uid}'),
          creature: c,
          sprite: widget.sprites[c.speciesId],
          picked: _offering == c.uid,
          inCircle: s.inCircle(c.uid),
          traits: traitsCounter(c, _d),
          onTap: () => setState(() => _offering = _offering == c.uid ? null : c.uid),
        ),
      if (plan != null && plan.circleUids.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: KEspaco.s1),
          child: Text('ATENÇÃO: ${plan.circleUids.length} PEÇA(S) NO CÍRCULO. A VAGA FICA VAZIA.', style: KTexto.rotulo.copyWith(color: KCores.brasaLaranja)),
        ),
      if (plan != null && plan.spirits.isNotEmpty) _Summary(plan: plan, data: _d, sprite: widget.sprites[plan.majorId]),
      const SizedBox(height: KEspaco.s2),
      _Button(label: 'Fundir', enabled: blocker == null, onTap: _fuse),
      if (blocker != null && _blockerText[blocker] != null)
        Padding(padding: const EdgeInsets.only(top: KEspaco.s1), child: Text(_blockerText[blocker]!.toUpperCase(), style: KTexto.corpoPequeno)),
    ]);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.plan, required this.data, required this.sprite});

  final MajorPlan plan;
  final GameData data;
  final EcoSprite? sprite;

  @override
  Widget build(BuildContext context) {
    final a = attributesOf(CreatureInstance(uid: '', speciesId: plan.majorId, level: plan.level, capturedUtc: 0, traits: plan.traits), data);
    return Container(
      key: const Key('major-summary'),
      margin: const EdgeInsets.only(top: KEspaco.s2),
      padding: const EdgeInsets.all(KEspaco.s2),
      decoration: cardBox(selected: true),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SpeciesImage(sprite: sprite, size: 64, aura: true),
        const SizedBox(width: KEspaco.s2),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((data.species(plan.majorId)?.name ?? plan.majorId).toUpperCase(), style: KTexto.rotulo.copyWith(color: KCores.veuClaro)),
            Text('NÍVEL MÉDIO ${plan.level} · PODER ${a.power}', style: KTexto.rotulo),
            Text(a.traitsCounter.toUpperCase(), style: KTexto.rotulo),
            for (final t in a.traits) Text('${t.name}: ${t.description}', style: KTexto.corpoPequeno.copyWith(color: Color(t.tint))),
          ]),
        ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.creature, required this.sprite, required this.picked, required this.inCircle, required this.traits, required this.onTap, super.key});

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
          margin: const EdgeInsets.only(bottom: KEspaco.s1),
          padding: const EdgeInsets.all(KEspaco.s1),
          constraints: const BoxConstraints(minHeight: kToqueMinDp),
          decoration: cardBox(selected: picked),
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
            key: const Key('major-button'),
            alignment: Alignment.center,
            constraints: const BoxConstraints(minHeight: kToqueMinDp),
            decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: KCores.veuVioleta, width: kContornoDp), boxShadow: KSombra.pixel),
            child: Text(label.toUpperCase(), style: KTexto.rotulo.copyWith(color: KCores.veuVioleta)),
          ),
        ),
      );
}
