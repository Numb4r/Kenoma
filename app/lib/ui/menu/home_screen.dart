/// O app Casa (0.28.0, GDD rev 400): sem casa, definir no lugar; dentro do raio, mexer nas estações, recolher e arrumar o
/// Armazém; fora dele, só o estado (o que cada estação fez e quanto falta para encher) e o aviso de que é preciso estar em
/// casa. Os textos vêm de `home.json`; a regra, de `crafting/home_actions.dart`.
library;

import 'package:flutter/material.dart';

import '../../core/plural.dart';
import '../../core/tiles.dart';
import '../../crafting/home_actions.dart';
import '../../crafting/quality.dart';
import '../../crafting/stations.dart';
import '../../data/game_data.dart';
import '../../player/game_state.dart';
import '../colors.dart';
import '../craft/craft_context.dart';
import '../kit.dart' show KitAlertDialog, UiIcon;
import '../tuning/tuning_screen.dart' show PixelButton;
import 'screen_frame.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({required this.state, required this.data, required this.ctx, super.key});

  final GameState state;
  final GameData data;
  final CraftContext ctx;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// O seletor aberto: `assign:<estação>`, `choose:<estação>`, `bag` ou `sanctum`; `null`: nenhum.
  String? _open;

  GameState get _s => widget.state;
  GameData get _d => widget.data;
  String _t(String key) => _d.home.text(key);
  int get _now => widget.ctx.nowUtc();

  HerePos get _here {
    final h = widget.ctx.here();
    return (lat: h.lat, lon: h.lon);
  }

  void _say(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  void _result(HomeResult r) {
    final msg = switch (r) {
      HomeResult.ok => null,
      HomeResult.storageFull => _t('storage_full'),
      HomeResult.sanctumFull => _t('sanctum_full'),
      HomeResult.slotsFull => 'Sem vaga: a próxima abre com o nível.',
      HomeResult.away => _t('away_title'),
      HomeResult.cooldown => _t('cooldown').replaceAll('{dias}', countText((cooldownLeftS(_s, _now) / 86400).ceil(), 'dia')),
      HomeResult.locked => 'A casa abre no nível ${_s.balance.home.unlockLevel}.',
      HomeResult.noHome || HomeResult.invalid => 'Não deu.',
    };
    if (msg != null) _say(msg);
    setState(() => _open = null);
  }

  Future<void> _confirmSet() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => KitAlertDialog(
        title: Text(_t('set_title')),
        content: Text(_t('set_body'), style: const TextStyle(fontSize: 8)),
        actions: [
          PixelButton(key: const Key('home-set-no'), label: _t('set_no'), color: kDim, onTap: () => Navigator.pop(c, false)),
          PixelButton(key: const Key('home-set-yes'), label: _t('set_yes'), color: kSignal, onTap: () => Navigator.pop(c, true)),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    final h = _here;
    _result(setHome(_s, latLonToTile(h.lat, h.lon, biomeZoom), _now));
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _s,
        builder: (context, _) {
          final h = _here;
          final dist = _s.home.distanceM(h.lat, h.lon);
          final inside = atHome(_s, h);
          final subtitle = _s.home.cell == null ? 'Sem casa' : (inside ? 'Em casa' : '${_t('away_title')} · ${_km(dist!)}');
          return ScreenFrame(title: 'Casa', subtitle: subtitle, children: [
            if (_s.home.cell == null) ..._noHome() else ...[
              if (!inside) _away(),
              for (final def in _d.home.stations) _station(def, inside),
              ..._storage(inside),
              ..._sanctum(inside),
              ..._furniture(inside),
              ..._move(),
            ],
          ]);
        },
      );

  String _km(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';

  List<Widget> _noHome() => [
        Text(_t('no_home'), key: const Key('home-none'), style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: PixelButton(key: const Key('home-set'), label: _t('set_button'), color: kSignal, onTap: _confirmSet)),
      ];

  Widget _away() => Container(
        key: const Key('home-away'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: panelBox(line: kVeil),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_t('away_title').toUpperCase(), style: const TextStyle(fontSize: 12, color: kVeil)),
          const SizedBox(height: 6),
          Text(_t('away_body'), style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
        ]),
      );

  String _creatureName(String uid) {
    final c = _s.creature(uid);
    return c == null ? uid : '${_d.species(c.speciesId)?.name ?? c.speciesId} nv ${c.level}';
  }

  String _choiceName(StationDef def, String? choice) {
    if (choice == null) return def.kind == StationKind.out ? _d.itemName(def.outId ?? '') : 'nada escolhido';
    return switch (def.kind) {
      StationKind.recipe || StationKind.seals => _d.itemName(_d.recipes[choice]?.outId ?? choice),
      StationKind.age => '${_d.itemName(parseStack(choice).id)} (${parseStack(choice).q.label} → ${parseStack(choice).q.up().label})',
      StationKind.research => _d.species(choice)?.name ?? choice,
      StationKind.out => _d.itemName(def.outId ?? ''),
    };
  }

  String _eta(StationView v) {
    if (v.full) return _t('deposit_full');
    if (v.workers.isEmpty) return _t('empty_slot');
    if (v.plan == null) return 'Escolha o que ela faz.';
    if (v.fullAtUtc case final at?) {
      final m = ((at - _now) / 60).ceil();
      return 'Enche em ${m >= 60 ? '${(m / 60).ceil()} h' : '$m min'}.';
    }
    return v.starved ? 'A carga acaba antes de encher: ponha mais no Armazém.' : '';
  }

  Widget _station(StationDef def, bool inside) {
    final v = stationView(_s, _d, def, _now);
    final st = _s.home.stations[def.id];
    final family = _d.families.where((f) => f.id == def.family).firstOrNull?.name ?? def.family;
    final slots = _s.balance.home.slotsAt(_s.playerLevel);
    final choices = stationChoices(_s, _d, def);
    final eligible = [
      for (final c in _s.collection)
        if (canWork(def, c, _s.balance.home) && _s.home.stationOf(c.uid) == null) c,
    ];
    return Container(
      key: Key('home-station-${def.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: cardBox(line: v.full ? kEssence : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          UiIcon('icons/${def.icon}', size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(def.name.toUpperCase(), style: const TextStyle(fontSize: 12, color: kText)),
              Text(_t('family_only').replaceAll('{familia}', family), style: const TextStyle(fontSize: 8, color: kDim, height: 1.6)),
            ]),
          ),
          Text('${v.ready}/${v.cap}', key: Key('home-ready-${def.id}'), style: TextStyle(fontSize: 12, color: v.full ? kEssence : kSignal)),
        ]),
        const SizedBox(height: 6),
        Text(def.about, style: const TextStyle(fontSize: 8, color: kDim, height: 1.6)),
        Text('FAZ: ${_choiceName(def, st?.choice).toUpperCase()}', style: const TextStyle(fontSize: 8, color: kText, height: 1.8)),
        Text('VAGAS ${v.workers.length}/$slots', style: const TextStyle(fontSize: 8, color: kDim, height: 1.8)),
        for (final w in st?.workers ?? const <String>[])
          Row(children: [
            Expanded(child: Text(_creatureName(w).toUpperCase(), style: const TextStyle(fontSize: 8, color: kText, height: 1.8))),
            if (inside) PixelButton(key: Key('home-unassign-$w'), label: 'Tirar', color: kDim, onTap: () => _result(unassign(_s, _d, _here, def.id, w, _now))),
          ]),
        if (_eta(v).isNotEmpty) Text(_eta(v), key: Key('home-eta-${def.id}'), style: TextStyle(fontSize: 8, color: v.full ? kEssence : kDim, height: 1.8)),
        if (inside) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            PixelButton(key: Key('home-collect-${def.id}'), label: 'Recolher', color: kSignal, onTap: () => _result(collect(_s, _d, _here, def.id, _now))),
            if (eligible.isNotEmpty && v.workers.length < slots)
              PixelButton(key: Key('home-assign-${def.id}'), label: 'Pôr para trabalhar', color: kVeil, onTap: () => setState(() => _open = _open == 'assign:${def.id}' ? null : 'assign:${def.id}')),
            if (choices.isNotEmpty)
              PixelButton(key: Key('home-choose-${def.id}'), label: 'Escolher', color: kVeil, onTap: () => setState(() => _open = _open == 'choose:${def.id}' ? null : 'choose:${def.id}')),
          ]),
          if (_open == 'assign:${def.id}')
            for (final c in eligible) _pick('home-pick-${c.uid}', _creatureName(c.uid), () => _result(assign(_s, _d, _here, def.id, c.uid, _now))),
          if (_open == 'choose:${def.id}')
            for (final ch in choices) _pick('home-pick-$ch', _choiceName(def, ch), () => _result(choose(_s, _d, _here, def.id, ch, _now))),
        ],
      ]),
    );
  }

  Widget _pick(String key, String label, VoidCallback onTap) => GestureDetector(
        key: Key(key),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: cellBox(),
          margin: const EdgeInsets.only(top: 4),
          child: Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, color: kText)),
        ),
      );

  String _stackName(String key) {
    final (:id, :q) = parseStack(key);
    return q == Quality.common ? _d.itemName(id) : '${_d.itemName(id)} (${q.label})';
  }

  List<Widget> _storage(bool inside) {
    final keys = [for (final e in _s.home.storage.entries) if (e.value > 0) e.key]..sort();
    final bag = [for (final e in _s.inventory.entries) if (e.value > 0) e.key]..sort();
    return [
      SectionTitle('Armazém · ${storageUsed(_s, _d)}/${storageCap(_s, _d)}'),
      if (keys.isEmpty) const Text('VAZIO.', style: TextStyle(fontSize: 8, color: kDim)),
      for (final k in keys)
        Row(children: [
          Expanded(child: Text('${_s.home.storage[k]} × ${_stackName(k)}'.toUpperCase(), style: const TextStyle(fontSize: 8, color: kText, height: 2))),
          if (inside) PixelButton(key: Key('home-take-$k'), label: 'Para a Bolsa', color: kDim, onTap: () => _result(takeItem(_s, _here, k, _s.home.storage[k] ?? 0))),
        ]),
      if (inside && bag.isNotEmpty) ...[
        const SizedBox(height: 6),
        PixelButton(key: const Key('home-from-bag'), label: 'Guardar da Bolsa', color: kSignal, onTap: () => setState(() => _open = _open == 'bag' ? null : 'bag')),
        if (_open == 'bag')
          for (final k in bag) _pick('home-store-$k', '${_s.inventory[k]} × ${_stackName(k)}', () => _result(storeItem(_s, _d, _here, k, _s.inventory[k] ?? 0))),
      ],
    ];
  }

  List<Widget> _sanctum(bool inside) {
    final candidates = [for (final c in _s.collection) if (!_s.home.holds(c.uid)) c];
    return [
      SectionTitle('Santuário · ${sanctumUsed(_s)}/${sanctumCap(_s, _d)}'),
      const Text('QUEM TRABALHA TAMBÉM OCUPA UM ESPAÇO.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
      for (final uid in _s.home.stored)
        Row(children: [
          Expanded(child: Text(_creatureName(uid).toUpperCase(), style: const TextStyle(fontSize: 8, color: kText, height: 2))),
          if (inside) PixelButton(key: Key('home-retrieve-$uid'), label: 'Trazer', color: kDim, onTap: () => _result(retrieveCreature(_s, _d, _here, uid, _now))),
        ]),
      if (inside && candidates.isNotEmpty) ...[
        const SizedBox(height: 6),
        PixelButton(key: const Key('home-store-creature'), label: 'Guardar criatura', color: kVeil, onTap: () => setState(() => _open = _open == 'sanctum' ? null : 'sanctum')),
        if (_open == 'sanctum')
          for (final c in candidates.reversed) _pick('home-keep-${c.uid}', _creatureName(c.uid), () => _result(storeCreature(_s, _d, _here, c.uid))),
      ],
    ];
  }

  List<Widget> _furniture(bool inside) {
    final ids = {
      for (final k in [..._s.inventory.keys, ..._s.home.storage.keys])
        if (_d.craft.item(parseStack(k).id)?.kind == 'furniture') parseStack(k).id,
    };
    return [
      const SectionTitle('Móveis'),
      if (_s.home.furniture.isEmpty) const Text('NENHUM AINDA. A PÁGINA DOS MÓVEIS ESTÁ NO GRIMÓRIO.', style: TextStyle(fontSize: 8, color: kDim, height: 1.8)),
      for (final e in _s.home.furniture.entries)
        Text('${e.value} × ${_d.itemName(e.key)}'.toUpperCase(), style: const TextStyle(fontSize: 8, color: kText, height: 2)),
      if (inside)
        for (final id in ids)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Align(alignment: Alignment.centerLeft, child: PixelButton(key: Key('home-install-$id'), label: 'Instalar ${_d.itemName(id)}', color: kSignal, onTap: () => _result(installFurniture(_s, _d, _here, id)))),
          ),
    ];
  }

  List<Widget> _move() {
    final left = cooldownLeftS(_s, _now);
    return [
      const SectionTitle('Lugar'),
      if (left > 0)
        Text(_t('cooldown').replaceAll('{dias}', countText((left / 86400).ceil(), 'dia')), key: const Key('home-cooldown'), style: const TextStyle(fontSize: 8, color: kDim, height: 1.8))
      else
        Align(alignment: Alignment.centerLeft, child: PixelButton(key: const Key('home-set'), label: _t('set_button'), color: kDim, onTap: _confirmSet)),
    ];
  }
}
