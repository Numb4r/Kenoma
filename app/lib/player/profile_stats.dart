/// Apresentação do Perfil: textos e contas curtas que a tela só desenha. Dart puro.
library;

import '../save/founder.dart';
import 'bestiary.dart';
import 'conjurer_balance.dart';

const int kPlayerNameMax = 20;

/// Distância em km com uma casa e vírgula decimal: `1250` m vira `1,3 km`.
String formatKm(num meters) => '${(meters / 100).round() / 10} km'.replaceFirst('.', ',');

/// Área em km² com duas casas e vírgula decimal.
String formatKm2(double km2) => '${km2.toStringAsFixed(2).replaceFirst('.', ',')} km²';

/// Dias inteiros de descanso que o saldo [restBalance] cobre, dado o [daily] de XP em dobro por dia.
int restDays(int restBalance, int daily) => daily <= 0 ? 0 : restBalance ~/ daily;

/// `1 dia` ou `N dias`.
String daysLabel(int n) => n == 1 ? '1 dia' : '$n dias';

/// Só letras, números e espaços; sem espaços nas pontas; no máximo [kPlayerNameMax] caracteres.
String sanitizeName(String raw) {
  final clean = raw.replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '').trim();
  return String.fromCharCodes(clean.runes.take(kPlayerNameMax)).trim();
}

/// Espécies com pelo menos uma captura, sem contar as chaves de variante e Brilhante (`espécie@...`).
int speciesRegistered(Map<String, BestiaryEntry> bestiary) =>
    bestiary.entries.where((e) => e.value.captured && !e.key.contains('@')).length;

String schoolLabel(School? s) => s?.label ?? 'Sem escola';

/// Data local `dd/mm/aaaa` de um instante UTC.
String formatDate(int utcSeconds) {
  final t = DateTime.fromMillisecondsSinceEpoch(utcSeconds * 1000, isUtc: true).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year}';
}

/// Os certificados do Conjurador, na ordem da tela. Por ora só o de fundador; eventos entram aqui quando existirem.
List<String> certificateIds(Founder? founder) => [if (founder != null) 'founder'];
