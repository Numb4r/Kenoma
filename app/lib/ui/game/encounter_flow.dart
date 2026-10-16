/// O encontro (M7): tocar num Eco dentro da Aura abre a escolha de selo, depois a sintonia. Sucesso põe
/// a criatura na coleção e dá Ectoplasma. Falha gasta o selo e o Eco pode fugir; se não fugiu, dá para
/// tentar de novo com outro selo. As regras da sintonia estão em `capture/`; aqui só se liga o mapa a ela.
library;

import '../pressable.dart';
import 'package:flutter/material.dart';

import '../../capture/seal.dart';
import '../../core/behavior.dart';
import '../../capture/tuning_setup.dart';
import '../../data/game_data.dart';
import '../../data/tuning_data.dart';
import '../../player/circle.dart';
import '../../player/game_state.dart';
import '../../player/progression.dart' show tuningXp;
import '../../world/spawn_field.dart';
import '../../world/world_view.dart';
import '../colors.dart';
import '../tuning/tuning_game.dart' show TuningRun;
import '../tuning/tuning_screen.dart';
import '../tuning/vibration_driver.dart';
import '../type_label.dart';

const _tonicId = 'item.tonic.focus';

/// O que o jogador escolheu na folha de preparo.
typedef Prep = ({Seal seal, bool tonic});

Future<void> runEncounter(
  BuildContext context, {
  required WorldSpawn eco,
  required WorldView world,
  required GameState state,
  required GameData data,
  required int Function() nowUtc,
  VibrationPlayer? vibration,
  void Function(String message)? onMessage,
}) async {
  final species = data.species(eco.entryId);
  if (species == null) return;
  final level = (eco.level ?? 1).clamp(1, state.balance.levelCapFor(species.id)); // o Espírito vai ao teto 30, o Eco ao 20
  final navigator = Navigator.of(context);
  while (context.mounted) {
    final seals = [for (final s in data.tuning.seals) if (state.count(s.id) > 0) s];
    if (!context.mounted) return;
    final prep = await showModalBottomSheet<Prep>(
      // ignore: use_build_context_synchronously
      context: context,
      sheetAnimationStyle: sheetSlide,
      backgroundColor: kPanel,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(side: BorderSide(color: kVeil, width: 3)),
      builder: (_) => PrepSheet(
        species: species,
        level: level,
        seals: seals,
        count: state.count,
        tonics: state.count(_tonicId),
        behavior: eco.behavior,
        variant: data.variantInfo(biome: eco.variant, shiny: eco.shiny),
      ),
    );
    if (prep == null || !context.mounted) return; // cancelar não custa nada
    state.take(prep.seal.id);
    final tonic = prep.tonic && state.take(_tonicId) ? data.tuning.tonics.first : null;
    final run = await navigator.push<TuningRun>(MaterialPageRoute(
      builder: (_) => TuningScreen(
        encounter: true,
        pool: [species],
        buildSetup: (_) => TuningSetup(
          type: species.type,
          ecoLevel: level,
          playerLevel: state.playerLevel,
          seal: prep.seal,
          tonic: tonic,
          circleStrong: strongInCircle(state, data, species.type),
          toleranceMult: state.cb.toleranceMultFor(state.conjurer.school),
          progressUpMult: state.cb.progressUpMultFor(state.conjurer.school),
          intensityAdd: (eco.behavior == EcoBehavior.aggressive ? data.street.aggressiveIntensityAdd : 0) + (species.isSpirit ? state.cb.spiritResistanceAdd : 0), // Espírito: resistência forte do tipo
          wanderScale: switch (eco.behavior) {
            EcoBehavior.skittish => data.street.skittishWanderScale,
            EcoBehavior.hidden => data.street.hiddenWanderScale,
            _ => 1.0,
          },
        ),
        balance: data.tuning.balance,
        balanceVersion: data.tuning.balanceVersion,
        appBuild: '',
        vibration: vibration,
        resultNote: (run) => run.outcome.success ? '${species.name} NV $level vai para a sua coleção' : '',
      ),
    ));
    if (run == null) return; // saiu no meio: o selo já foi gasto
    final o = run.outcome;
    if (o.success) {
      final first = !state.hasCaptured(species.id);
      state.capture(uid: eco.uid, speciesId: species.id, level: level, nowUtc: nowUtc(), variant: eco.variant, shiny: eco.shiny);
      state.add('item.ectoplasm', o.ectoplasm);
      state.recordEvent('capture', species.type.name, 1);
      final b = state.balance;
      final up = state.gainXp(tuningXp(level, b) + (first ? b.firstCapture : 0), nowUtc());
      final notes = [
        if (first) 'Primeira ${species.name}! +${b.firstCapture} XP',
        if (up > 0) 'Nível ${state.progress.level}!',
        for (final c in awardCircleXp(state)) '${data.species(c.speciesId)?.name ?? c.speciesId} nível ${c.level}',
      ];
      if (notes.isNotEmpty) onMessage?.call(notes.join(' · '));
      world.remove(eco);
      return;
    }
    if (o.fled) {
      state.markDone(eco.uid, nowUtc()); // a fuga entra no registro
      world.remove(eco);
      return;
    }
  }
}

/// A folha de preparo: o Eco, os selos que o jogador tem e o tônico, se houver.
class PrepSheet extends StatefulWidget {
  const PrepSheet({
    required this.species,
    required this.level,
    required this.seals,
    required this.count,
    required this.tonics,
    this.behavior = EcoBehavior.passive,
    this.variant,
    super.key,
  });

  final EcoSpecies species;
  final int level;
  final List<Seal> seals;
  final int Function(String itemId) count;
  final int tonics;

  /// O comportamento do Eco e a variante (ou Brilhante) dele, mostrados na folha.
  final EcoBehavior behavior;
  final VariantInfo? variant;

  @override
  State<PrepSheet> createState() => _PrepSheetState();
}

class _PrepSheetState extends State<PrepSheet> {
  late Seal? _seal = widget.seals.isEmpty ? null : widget.seals.first;
  bool _tonic = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.species.name} · NV ${widget.level}', style: const TextStyle(fontSize: 16, color: kText)),
            const SizedBox(height: 4),
            Text(typeLabel(widget.species.type), style: TextStyle(fontSize: 8, color: typeColorOf(widget.species))),
            if (widget.variant != null)
              Text('VARIANTE ${widget.variant!.name.toUpperCase()} · ${widget.variant!.trait.toUpperCase()}', key: const Key('prep-variant'), style: TextStyle(fontSize: 8, color: Color(widget.variant!.tint), height: 1.8)),
            if (widget.behavior != EcoBehavior.passive)
              Text('${widget.behavior.label}: ${behaviorHint(widget.behavior)}'.toUpperCase(), key: const Key('prep-behavior'), style: const TextStyle(fontSize: 8, color: kEssence, height: 1.8)),
            const SizedBox(height: 16),
            if (widget.seals.isEmpty)
              const Text('VOCÊ NÃO TEM SELOS. FABRIQUE UM NA BOLSA (GIZ + ECTOPLASMA).', style: TextStyle(fontSize: 8, color: kEssence, height: 1.8))
            else ...[
              const Text('ESCOLHA O SELO', style: TextStyle(fontSize: 8, color: kDim)),
              const SizedBox(height: 8),
              for (final s in widget.seals)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _seal = s),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(border: Border.all(color: _seal == s ? kSignal : kPanelLine, width: 3)),
                    child: Row(children: [
                      Expanded(child: Text(s.name.toUpperCase(), style: TextStyle(fontSize: 8, color: _seal == s ? kSignal : kText))),
                      Text('×${widget.count(s.id)}  TOL ${s.tolerance}', style: const TextStyle(fontSize: 8, color: kDim)),
                    ]),
                  ),
                ),
              if (widget.tonics > 0)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Tônico de foco (×${widget.tonics})', style: const TextStyle(fontSize: 8)),
                  subtitle: const Text('+5 s na sintonia', style: TextStyle(fontSize: 8, color: kDim)),
                  value: _tonic,
                  activeThumbColor: kSignal,
                  onChanged: (v) => setState(() => _tonic = v),
                ),
            ],
            const SizedBox(height: 12),
            if (_seal != null) PixelButton(label: 'Sintonizar', color: kSignal, onTap: () => Navigator.of(context).pop((seal: _seal!, tonic: _tonic))),
            if (_seal != null) const SizedBox(height: 8),
            PixelButton(label: 'Cancelar', color: kDim, onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }

  Color typeColorOf(EcoSpecies s) => typeColor(s.type);
}

/// O que o comportamento faz, em uma frase, para a folha de preparo.
String behaviorHint(EcoBehavior b) => switch (b) {
      EcoBehavior.passive => 'sinal normal',
      EcoBehavior.skittish => 'foge se você chegar correndo; o sinal oscila mais',
      EcoBehavior.aggressive => 'resistência mais forte',
      EcoBehavior.hidden => 'só aparece com o Radar; o sinal é mais estável',
    };
