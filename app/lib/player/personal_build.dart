/// A build do jogador ao longo do tempo, para a camada pessoal de spawn (GDD, "Geração determinística"). A camada pessoal
/// de uma célula usa a build que valia no COMEÇO da janela dela: trocar o Círculo muda o que nasce a partir da janela
/// seguinte, nunca a atual (parado, trocar de build não sorteia de novo). Dart puro; vai para o save (`personal_builds`).
library;

/// Uma build: as habilidades de mapa do Círculo (o maior valor de cada uma), valendo a partir de [fromUtc].
class BuildEntry {
  const BuildEntry({required this.fromUtc, required this.values});

  factory BuildEntry.fromJson(Map<String, dynamic> j) => BuildEntry(
        fromUtc: j['from'] as int,
        values: {for (final e in ((j['values'] as Map<String, dynamic>?) ?? const {}).entries) e.key: (e.value as num).toDouble()},
      );

  final int fromUtc;
  final Map<String, double> values;

  double of(String kind) => values[kind] ?? 0;

  bool sameValues(Map<String, double> other) => other.length == values.length && other.entries.every((e) => values[e.key] == e.value);

  Map<String, dynamic> toJson() => {'from': fromUtc, 'values': values};
}

/// A build que valia em [t]: a última que começou até [t]. Antes da primeira, nenhuma.
BuildEntry? buildAt(List<BuildEntry> history, int t) {
  BuildEntry? out;
  for (final b in history) {
    if (b.fromUtc <= t) out = b;
  }
  return out;
}

/// Anota a build de agora em [history]. Se mudou, entra uma nova valendo de [nowUtc] (a primeira de todas vale desde
/// sempre: quem atualiza o app não espera uma janela). Guarda só o que uma janela ainda pode pedir: as de mais de
/// [keepS] atrás saem, menos a última delas. Devolve `true` se mudou.
bool noteBuild(List<BuildEntry> history, Map<String, double> values, int nowUtc, {int keepS = 86400}) {
  if (history.isNotEmpty && history.last.sameValues(values)) return false;
  // O relógio do debug pode voltar: a build nova nunca começa antes da anterior.
  final from = history.isEmpty ? 0 : (nowUtc < history.last.fromUtc ? history.last.fromUtc : nowUtc);
  history.add(BuildEntry(fromUtc: from, values: {...values}));
  while (history.length > 2 && history[1].fromUtc <= nowUtc - keepS) {
    history.removeAt(0);
  }
  return true;
}
