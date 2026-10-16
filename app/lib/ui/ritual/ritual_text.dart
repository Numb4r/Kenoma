/// Os textos dos espaços do ritual, para a tela de ritual e o Bestiário: o que a pesquisa já revelou aparece escrito, o
/// resto fica ???. Só texto de interface.
library;

import '../../capture/eco_type.dart';
import '../../core/astro.dart' show moonPhaseNames, MoonPhase;
import '../../core/weather.dart' show Weather;
import '../../crafting/ritual_data.dart';
import '../type_label.dart';

const String ritualUnknown = '???';

const Map<String, String> _biomeNames = {'urban': 'Urbano', 'green': 'Verde', 'water': 'Água', 'residential': 'Residencial', 'void': 'Vazio'};

String conditionText(RitualCondition c) => switch (c.kind) {
      ConditionKind.hour => 'Entre ${c.from}h e ${c.to}h',
      ConditionKind.biome => 'Bioma ${_biomeNames[c.value] ?? c.value}',
      ConditionKind.moon => moonPhaseNames[MoonPhase.values.firstWhere((p) => p.name == c.value)]!,
      ConditionKind.weather => 'Clima: ${Weather.parse(c.value).label}',
    };

/// O texto do mundo agora, para o jogador comparar com o que já sabe.
String worldText(WorldCondition w) =>
    '${w.hour}h · ${_biomeNames[w.biome] ?? w.biome} · ${moonPhaseNames[w.moon]} · ${w.weather.label}';

/// O que o espaço [index] da receita pede, ou ??? se a pesquisa ainda não chegou nele ([revealed] espaços revelados).
String ritualSlotText(RitualRecipe r, int index, int revealed, EcoType target, String Function(String item) itemName) {
  if (index >= revealed) return ritualUnknown;
  if (index == 0) return conditionText(r.condition);
  if (index == r.circleIndex) {
    final strong = EcoType.values.firstWhere((t) => t.beats(target));
    return 'Criatura de ${typeLabel(strong)}, nível ${r.circleMinLevel}+';
  }
  final m = r.materials[index - 1];
  return '${m.qty}× ${itemName(m.item)}';
}
