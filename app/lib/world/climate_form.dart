/// Como as marcas do clima no chão se formam e somem (docs/GDD.md, "Tempo, astronomia e clima"): nada aparece pronto. O
/// estado de cada marca é função só do tempo desde o começo do clima no lugar e, depois que ele acaba, do tempo desde o fim.
/// Os dois instantes saem do mundo ([PlayerClimate.runStartUtc], [PlayerClimate.prevEndUtc]), então dois aparelhos juntos
/// veem a mesma fase. Os tempos (`grow_s`, `fade_s`) moram no `clima.json`: é só desenho. Dart puro.
library;

/// Quanto da marca existe (0 a 1): sobe em [growS] segundos desde o começo; depois do fim ([sinceEndS] não nulo), desce
/// em [fadeS] segundos a partir do que chegou a formar. A neve que derrete faz o caminho de volta: o que precisou de mais
/// neve para aparecer (as ruas) some primeiro.
double formAmount({required double sinceStartS, double? sinceEndS, required double growS, required double fadeS}) {
  double grown(double s) => growS <= 0 ? 1.0 : (s / growS).clamp(0.0, 1.0);
  if (sinceStartS < 0) return 0;
  if (sinceEndS == null) return grown(sinceStartS);
  if (sinceEndS < 0) return grown(sinceStartS);
  final peak = grown(sinceStartS - sinceEndS);
  if (fadeS <= 0) return 0;
  return (peak - sinceEndS / fadeS).clamp(0.0, 1.0);
}

/// O trecho `[a, b]` de [amount] levado para 0 a 1 (o estágio de uma marca que começa depois de outra).
double stage(double amount, double a, double b) => b <= a ? (amount >= a ? 1.0 : 0.0) : ((amount - a) / (b - a)).clamp(0.0, 1.0);

/// Os estágios da neve: primeiro um pó fino, depois a grama, o chão e os telhados, e só por último as ruas (as pouco usadas
/// antes das avenidas). Derrete na ordem contrária.
({double dust, double green, double ground, double Function(int roadRank) street}) snowStages(double amount) => (
      dust: stage(amount, 0, 0.2),
      green: stage(amount, 0.1, 0.45),
      ground: stage(amount, 0.2, 0.6),
      // 0: caminho de pedestre, 1: local, 2: secundária, 3: principal.
      street: (rank) => stage(amount, 0.45 + rank * 0.1, 0.75 + rank * 0.08),
    );

/// A fase que o debug mostra: formando, formado ou secando, com a porcentagem.
String formPhaseLabel(double amount, {required bool ending}) {
  final p = (amount * 100).round();
  if (ending) return amount <= 0 ? 'sumiu' : 'secando $p%';
  return amount >= 1 ? 'formado' : 'formando $p%';
}
