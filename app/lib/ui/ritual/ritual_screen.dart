/// A tela do ritual básico: um círculo com espaços para materiais, a condição do mundo e uma criatura do Círculo. Os espaços
/// que a pesquisa ainda não revelou aparecem como ???. Acertou, o sigilo se fecha (~2 s, dá para pular); errou, a criatura
/// escapa e os materiais se perdem. A UI nunca diz qual espaço errou. As regras estão em `crafting/ritual.dart`.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../crafting/ritual.dart';
import '../../crafting/ritual_data.dart';
import '../../data/game_data.dart';
import '../../data/tuning_data.dart';
import '../../player/game_state.dart';
import '../menu/phone_shell.dart';
import '../sprites/sprite_image.dart';
import '../menu/screen_frame.dart' show SpeciesImage;
import '../tema.dart';
import '../type_label.dart';
import 'ritual_painter.dart';
import 'ritual_sheets.dart';
import 'ritual_text.dart';

/// Abre o ritual do Eco [uid] como rota cheia. Devolve o resultado, ou `null` se o jogador saiu sem tentar.
Future<RitualStatus?> runRitual(
  BuildContext context, {
  required GameState state,
  required GameData data,
  required RitualRecipe recipe,
  required int uid,
  required int level,
  required WorldCondition Function() world,
  required int Function() nowUtc,
  String? variant,
  bool shiny = false,
}) =>
    Navigator.of(context).push(phoneRoute<RitualStatus>(RitualScreen(
      state: state,
      data: data,
      recipe: recipe,
      uid: uid,
      level: level,
      world: world,
      nowUtc: nowUtc,
      variant: variant,
      shiny: shiny,
    )));

enum _Phase { build, sealing, sealed, escaped }

class RitualScreen extends StatefulWidget {
  const RitualScreen({
    required this.state,
    required this.data,
    required this.recipe,
    required this.uid,
    required this.level,
    required this.world,
    required this.nowUtc,
    this.variant,
    this.shiny = false,
    super.key,
  });

  final GameState state;
  final GameData data;
  final RitualRecipe recipe;
  final int uid;
  final int level;

  /// O mundo no instante da tentativa (hora, bioma da célula do Eco, lua e clima).
  final WorldCondition Function() world;
  final int Function() nowUtc;
  final String? variant;
  final bool shiny;

  @override
  State<RitualScreen> createState() => _RitualScreenState();
}

class _RitualScreenState extends State<RitualScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: Duration(milliseconds: (widget.data.ritual.balance.sealAnimS * 1000).round()))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && _phase == _Phase.sealing) setState(() => _phase = _Phase.sealed);
    });
  late final List<PlacedMaterial?> _placed = List.filled(widget.recipe.materials.length, null);
  String? _circleUid;
  _Phase _phase = _Phase.build;
  String _note = '';
  EcoSprite? _sprite;
  RitualStatus? _status;

  EcoSpecies get _species => widget.data.species(widget.recipe.speciesId)!;
  bool get _locked => widget.state.playerLevel < widget.state.cb.ritualLevel;

  @override
  void initState() {
    super.initState();
    EcoSprite.load(widget.recipe.speciesId).then((s) {
      if (mounted) setState(() => _sprite = s);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _perform() {
    final out = performRitual(
      state: widget.state,
      data: widget.data,
      recipe: widget.recipe,
      attempt: RitualAttempt(materials: _placed, circleUid: _circleUid, world: widget.world()),
      uid: widget.uid,
      level: widget.level,
      nowUtc: widget.nowUtc(),
      variant: widget.variant,
      shiny: widget.shiny,
    );
    if (out.status == RitualStatus.blocked) {
      setState(() => _note = out.blockedReason);
      return;
    }
    _status = out.status;
    setState(() => _phase = out.success ? _Phase.sealing : _Phase.escaped);
    if (out.success) _anim.forward(from: 0);
  }

  Future<void> _pickMaterial(int i) async {
    final r = await showModalBottomSheet<RitualPick>(
      context: context,
      backgroundColor: KCores.superficie1,
      builder: (_) => RitualMaterialSheet(state: widget.state, data: widget.data, current: _placed[i], maxQty: widget.data.ritual.balance.materialMaxQty),
    );
    if (r != null) setState(() => _placed[i] = r.material);
  }

  Future<void> _pickCircle() async {
    final r = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: KCores.superficie1,
      builder: (_) => RitualCircleSheet(state: widget.state, data: widget.data),
    );
    if (r != null) setState(() => _circleUid = r.isEmpty ? null : r);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != _Phase.sealing,
      onPopInvokedWithResult: (_, _) {},
      child: PhoneScreen(
        title: 'Ritual',
        child: _locked ? _lockedView() : _body(),
      ),
    );
  }

  Widget _lockedView() => Padding(
        padding: const EdgeInsets.all(KEspaco.s3),
        child: Center(
          child: Text('Esta criatura não responde à sintonia. O mentor ensina o ritual no nível ${widget.state.cb.ritualLevel}.',
              key: const Key('ritual-locked'), textAlign: TextAlign.center, style: KTexto.corpo),
        ),
      );

  Widget _body() {
    final done = _phase == _Phase.sealed || _phase == _Phase.escaped;
    final revealed = ritualRevealed(widget.state, widget.recipe);
    return ListView(padding: const EdgeInsets.fromLTRB(KEspaco.s2, 0, KEspaco.s2, KEspaco.s4), children: [
      Text('${_species.name.toUpperCase()} · ${typeLabel(_species.type).toUpperCase()} · NV ${widget.level}', style: KTexto.rotulo.copyWith(color: KCores.veuClaro)),
      const SizedBox(height: KEspaco.s1),
      GestureDetector(
        key: const Key('ritual-stage'),
        behavior: HitTestBehavior.opaque,
        onTap: _phase == _Phase.sealing ? () => _anim.value = 1 : null, // pular a animação
        child: SizedBox(height: 360, child: _stage(revealed)),
      ),
      if (_phase == _Phase.build) ...[
        Text('Agora: ${worldText(widget.world())}', key: const Key('ritual-world'), style: KTexto.corpoPequeno),
        const SizedBox(height: KEspaco.s2),
        if (_note.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: KEspaco.s1), child: Text(_note, key: const Key('ritual-note'), style: KTexto.corpo.copyWith(color: KCores.brasaLaranja))),
        _Button(key: const Key('ritual-go'), label: 'Realizar ritual', color: KCores.veuVioleta, onTap: _perform),
      ],
      if (_phase == _Phase.sealing) Text('Toque para pular', key: const Key('ritual-skip'), textAlign: TextAlign.center, style: KTexto.corpoPequeno),
      if (done) ..._result(),
    ]);
  }

  List<Widget> _result() {
    final ok = _phase == _Phase.sealed;
    return [
      Text(ok ? '${_species.name} foi selada. Está na sua coleção.' : '${_species.name} escapou. Os materiais se perderam.',
          key: Key(ok ? 'ritual-sealed' : 'ritual-escaped'), textAlign: TextAlign.center, style: KTexto.corpo.copyWith(color: ok ? KCores.sinalCiano : KCores.falha)),
      const SizedBox(height: KEspaco.s2),
      _Button(key: const Key('ritual-close'), label: 'Voltar', color: KCores.textoMudo, onTap: () => Navigator.of(context).pop(_status)),
    ];
  }

  /// O círculo com a criatura no meio e os espaços ao redor: a condição em cima, os materiais e o Círculo no sentido horário.
  Widget _stage(int revealed) {
    final n = widget.recipe.slotCount;
    final sealing = _phase == _Phase.sealing || _phase == _Phase.sealed;
    return LayoutBuilder(builder: (context, box) {
      final c = Offset(box.maxWidth / 2, 180);
      final radius = math.min(box.maxWidth / 2 - 44, 138.0);
      return AnimatedBuilder(
        animation: _anim,
        builder: (context, _) => Stack(children: [
          Positioned.fill(child: CustomPaint(painter: RitualCirclePainter(seal: sealing ? _anim.value : 0, broken: _phase == _Phase.escaped))),
          Positioned(
            left: c.dx - 36,
            top: c.dy - 36,
            child: Opacity(opacity: _phase == _Phase.escaped ? 0.25 : 1, child: SpeciesImage(sprite: _sprite, silhouette: _phase != _Phase.sealed, size: 72)),
          ),
          if (_phase == _Phase.build || sealing && _anim.value < 1)
            for (var i = 0; i < n; i++)
              Positioned(
                left: c.dx + radius * math.cos(-math.pi / 2 + i * 2 * math.pi / n) - 40,
                top: c.dy + radius * math.sin(-math.pi / 2 + i * 2 * math.pi / n) - 32,
                child: _slotBox(i, revealed),
              ),
        ]),
      );
    });
  }

  Widget _slotBox(int i, int revealed) {
    final r = widget.recipe;
    final isCircle = i == r.circleIndex;
    String? mine;
    if (isCircle) {
      final c = _circleUid == null ? null : widget.state.creature(_circleUid!);
      if (c != null) mine = '${widget.data.species(c.speciesId)?.name ?? c.speciesId}\nNV ${c.level}';
    } else if (i > 0 && _placed[i - 1] != null) {
      mine = '${_placed[i - 1]!.qty}× ${widget.data.itemName(_placed[i - 1]!.item)}';
    }
    final hint = ritualSlotText(r, i, revealed, _species.type, widget.data.itemName);
    final isMine = mine != null;
    return _Slot(
      key: Key('ritual-slot-$i'),
      text: mine ?? hint,
      filled: isMine,
      unknown: !isMine && hint == ritualUnknown,
      // A condição é o mundo, não se coloca: só mostra a dica.
      onTap: _phase != _Phase.build || i == 0 ? null : (isCircle ? _pickCircle : () => _pickMaterial(i - 1)),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.text, required this.filled, required this.unknown, this.onTap, super.key});

  final String text;
  final bool filled;
  final bool unknown;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 80,
          height: 64,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: KCores.superficie1,
            border: Border.all(color: filled ? KCores.sinalCiano : (unknown ? KCores.cidade : KCores.veuVioleta), width: kContornoDp),
            boxShadow: KSombra.pixel,
          ),
          child: Text(text, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: (unknown ? KTexto.rotulo : KTexto.corpoPequeno).copyWith(fontSize: unknown ? 14 : 11, height: 1.1, color: filled ? KCores.texto : KCores.textoMudo)),
        ),
      );
}

class _Button extends StatelessWidget {
  const _Button({required this.label, required this.color, required this.onTap, super.key});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: kToqueMinDp,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: KCores.superficie2, border: Border.all(color: color, width: kContornoDp), boxShadow: KSombra.pixel),
          child: Text(label.toUpperCase(), style: KTexto.rotulo.copyWith(color: color)),
        ),
      );
}
