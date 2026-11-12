/// O que a tela do Bestiário mostra, tirado dos dados e do save: as formas de cada família (Fagulha, Eco, Espírito), o
/// estado de cada uma, a pesquisa em porcentagem, o filtro, a busca e as bolinhas de variante. Dart puro.
library;

import '../data/game_data.dart';
import 'bestiary.dart';
import 'research.dart';

enum FormLayer { spark, eco, spirit, ritual }

const Map<FormLayer, String> formLayerNames = {FormLayer.spark: 'Fagulha', FormLayer.eco: 'Eco', FormLayer.spirit: 'Espírito', FormLayer.ritual: 'Ritual'};

/// Uma forma do Bestiário: a Fagulha (o item de pó do tipo) ou uma espécie.
class BestiaryForm {
  const BestiaryForm({required this.family, required this.layer, required this.id, required this.name, required this.number});

  final FamilyDef family;
  final FormLayer layer;

  /// A chave no bestiário do save: o id da espécie, ou o do item da Fagulha (`item.dust.fire`).
  final String id;
  final String name;

  /// O número de catálogo, na ordem das famílias.
  final int number;

  bool get isSpark => layer == FormLayer.spark;

  /// A chave do sprite (`hum.eco`, `hum.mote`).
  String get spriteKey => isSpark ? '${family.id}.mote' : id;
}

/// As formas de [family], na ordem da linha de fusão. O Espírito que só o ritual chama (as três do MVP) vem por último.
List<BestiaryForm> familyForms(FamilyDef family, GameData data, int firstNumber) {
  var n = firstNumber;
  return [
    BestiaryForm(family: family, layer: FormLayer.spark, id: family.sparkItem, name: family.sparkName, number: n++),
    for (final (suffix, layer) in const [('eco', FormLayer.eco), ('spirit', FormLayer.spirit), ('ritual', FormLayer.ritual)])
      if (data.species('${family.id}.$suffix') case final s?) BestiaryForm(family: family, layer: layer, id: s.id, name: s.name, number: n++),
  ];
}

/// Todas as formas, família por família.
List<BestiaryForm> bestiaryForms(GameData data) {
  final out = <BestiaryForm>[];
  for (final f in data.families) {
    out.addAll(familyForms(f, data, out.length + 1));
  }
  return out;
}

/// A família já apareceu para o jogador: alguma forma dela foi vista ou capturada. Antes disso é "Família ???".
bool familyKnown(FamilyDef f, GameData data, Map<String, BestiaryEntry> b) =>
    familyForms(f, data, 1).any((form) => formState(form.id, b) != FormStatus.unknown);

/// O nível de pesquisa (0 a 5) de uma forma; a Fagulha tem um nível só, o de coletar.
int formResearchLevel(BestiaryForm form, GameData data, Map<String, BestiaryEntry> b) {
  if (form.isSpark) return formState(form.id, b) == FormStatus.captured ? 1 : 0;
  final lore = data.lore[form.id];
  return lore == null ? (formState(form.id, b) == FormStatus.captured ? 1 : 0) : researchLevel(lore.research, form.id, b);
}

int formResearchMax(BestiaryForm form, GameData data) => form.isSpark ? 1 : (data.lore[form.id]?.research.length ?? 1);

/// A pesquisa da família, de 0 a 100: os níveis feitos sobre os níveis que existem.
int familyPercent(FamilyDef f, GameData data, Map<String, BestiaryEntry> b) {
  var done = 0, total = 0;
  for (final form in familyForms(f, data, 1)) {
    done += formResearchLevel(form, data, b);
    total += formResearchMax(form, data);
  }
  return total == 0 ? 0 : (100 * done / total).floor();
}

/// A pesquisa do Bestiário inteiro, de 0 a 100.
int bestiaryPercent(GameData data, Map<String, BestiaryEntry> b) {
  var done = 0, total = 0;
  for (final form in bestiaryForms(data)) {
    done += formResearchLevel(form, data, b);
    total += formResearchMax(form, data);
  }
  return total == 0 ? 0 : (100 * done / total).floor();
}

/// O filtro da grade e a busca. Conjunto vazio em [types], [layers] ou [states] quer dizer "todos".
class BestiaryFilter {
  const BestiaryFilter({this.types = const {}, this.layers = const {}, this.states = const {}, this.incompleteOnly = false, this.query = ''});

  final Set<String> types;
  final Set<FormLayer> layers;
  final Set<FormStatus> states;

  /// Só as formas com pesquisa por fazer.
  final bool incompleteOnly;

  /// Busca por nome, tipo ou lugar.
  final String query;

  bool get isEmpty => types.isEmpty && layers.isEmpty && states.isEmpty && !incompleteOnly && query.trim().isEmpty;

  BestiaryFilter copyWith({Set<String>? types, Set<FormLayer>? layers, Set<FormStatus>? states, bool? incompleteOnly, String? query}) => BestiaryFilter(
        types: types ?? this.types,
        layers: layers ?? this.layers,
        states: states ?? this.states,
        incompleteOnly: incompleteOnly ?? this.incompleteOnly,
        query: query ?? this.query,
      );

  /// [typeLabel] dá o nome do tipo na interface ("Elétrico"), para a busca por tipo.
  bool matches(BestiaryForm form, GameData data, Map<String, BestiaryEntry> b, String Function(String type) typeLabel) {
    final state = formState(form.id, b);
    if (types.isNotEmpty && !types.contains(form.family.type)) return false;
    if (layers.isNotEmpty && !layers.contains(form.layer)) return false;
    if (states.isNotEmpty && !states.contains(state)) return false;
    if (incompleteOnly && formResearchLevel(form, data, b) >= formResearchMax(form, data)) return false;
    final q = _fold(query.trim());
    if (q.isEmpty) return true;
    // O que o jogador ainda não viu não se acha pelo nome nem pelo lugar: só o que já está revelado entra na busca.
    final known = state != FormStatus.unknown;
    return [
      if (known) form.name,
      if (known) typeLabel(form.family.type),
      if (known) formLayerNames[form.layer]!,
      if (familyKnown(form.family, data, b)) form.family.name,
      if (known) ...form.family.where.values,
    ].any((text) => _fold(text).contains(q));
  }
}

/// Minúsculas e sem acento, para a busca ("eletrico" acha "Elétrico").
String _fold(String s) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç', to = 'aaaaaeeeeiiiiooooouuuuc';
  final out = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    out.write(i < 0 ? ch : to[i]);
  }
  return out.toString();
}

/// Uma bolinha de variante: a chave (`''` é a forma comum; `urban`, `shiny`, `crimson`...) e o estado.
typedef VariantDot = ({String key, FormStatus state});

/// As bolinhas de uma espécie: a comum, as de bioma, a Brilhante e a Carmesim, na ordem de `creatures.json`. Preenchida
/// se capturada, só contorno se vista, escura se desconhecida.
List<VariantDot> variantDots(String speciesId, GameData data, Map<String, BestiaryEntry> b) => [
      (key: '', state: formState(speciesId, b)),
      for (final key in data.variants.keys) (key: key, state: formState('$speciesId@$key', b)),
    ];
