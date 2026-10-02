/// Leitura do instante UTC digitado no menu de debug. Sempre UTC (CLAUDE.md, regra 3): nada de fuso.
library;

/// Lê `aaaa-mm-dd hh:mm` (ou com `T`, com segundos opcionais e `Z` opcional) como instante UTC e devolve
/// os segundos desde a época Unix. `null` se não for uma data e hora válidas.
int? parseUtcInput(String text) {
  final m = RegExp(r'^\s*(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?\s*Z?\s*$').firstMatch(text);
  if (m == null) return null;
  final y = int.parse(m.group(1)!), mo = int.parse(m.group(2)!), d = int.parse(m.group(3)!);
  final h = int.parse(m.group(4) ?? '0'), mi = int.parse(m.group(5) ?? '0'), s = int.parse(m.group(6) ?? '0');
  if (mo < 1 || mo > 12 || d < 1 || h > 23 || mi > 59 || s > 59) return null;
  final t = DateTime.utc(y, mo, d, h, mi, s);
  if (t.month != mo || t.day != d) return null; // 31 de fevereiro e afins
  return t.millisecondsSinceEpoch ~/ 1000;
}

/// O instante em `aaaa-mm-dd hh:mm:ss` UTC, o formato que [parseUtcInput] lê.
String formatUtc(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  final u = t.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)} ${two(u.hour)}:${two(u.minute)}:${two(u.second)}';
}
