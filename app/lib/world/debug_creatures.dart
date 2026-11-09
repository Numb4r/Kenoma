/// "Criar criatura" do menu de debug: Ecos e Espíritos feitos sob medida que nascem na Aura, FORA do mundo determinístico.
/// Vivem só na memória deste aparelho, por [kDebugCreatureS] segundos ou até serem capturados, e o [WorldView] os soma
/// aos spawns do mundo. O uid fica numa faixa própria ([isDebugUid]): é por ele que a captura, a marcação e o bestiário
/// sabem que a criatura é de debug e não conta para o progresso. Dart puro.
library;

import 'dart:math' as math;

import '../core/behavior.dart';
import '../core/fnv.dart';
import '../core/pcg32.dart';
import 'spawn_field.dart';

/// Quanto tempo a criatura de debug fica no mapa (pedido: 20 minutos). Ferramenta de debug, não balanceamento.
const int kDebugCreatureS = 20 * 60;

/// A faixa dos uids de debug: `[base, base + 2^40)`. Os uids do mundo são hashes FNV-1a de 64 bits, então a chance de um
/// deles cair aqui é ~2^-24 por spawn e a de bater num uid de debug existente, ~2^-64.
const int kDebugUidBase = 0x7D00000000000000;
const int _kDebugUidSpan = 1 << 40;

bool isDebugUid(int uid) => uid >= kDebugUidBase && uid < kDebugUidBase + _kDebugUidSpan;

/// A variante pedida: nenhuma, a do bioma do ponto onde nasce, ou Carmesim (`crimson` em `creatures.json`).
enum DebugVariant {
  none('none', 'Nenhuma'),
  biome('biome', 'Bioma'),
  crimson('crimson', 'Carmesim');

  const DebugVariant(this.id, this.label);
  final String id;
  final String label;

  static DebugVariant parse(String? id) => values.firstWhere((v) => v.id == id, orElse: () => none);
}

/// O formulário do "Criar criatura". [speciesId] é a espécie Eco escolhida (`null`: sorteia uma do [type]).
class DebugCreatureSpec {
  const DebugCreatureSpec({
    this.speciesId,
    this.type,
    this.spirit = false,
    this.level = 5,
    this.shiny = false,
    this.variant = DebugVariant.none,
    this.behavior = EcoBehavior.passive,
    this.count = 1,
  });

  factory DebugCreatureSpec.fromJson(Map<String, dynamic> j) => DebugCreatureSpec(
        speciesId: j['species'] as String?,
        type: j['type'] as String?,
        spirit: j['spirit'] == true,
        level: ((j['level'] as num?)?.toInt() ?? 5).clamp(1, 40),
        shiny: j['shiny'] == true,
        variant: DebugVariant.parse(j['variant'] as String?),
        behavior: EcoBehavior.parse(j['behavior'] as String?),
        count: ((j['count'] as num?)?.toInt() ?? 1).clamp(1, 10),
      );

  final String? speciesId;
  final String? type;

  /// Camada: Espírito (`família.spirit`) ou Eco.
  final bool spirit;

  /// 1 a 40. Acima do teto da camada (Eco 20, Espírito 30), a sintonia usa o teto.
  final int level;
  final bool shiny;
  final DebugVariant variant;
  final EcoBehavior behavior;

  /// 1 a 10, cada uma num ponto diferente da Aura.
  final int count;

  Map<String, dynamic> toJson() => {
        if (speciesId != null) 'species': speciesId,
        if (type != null) 'type': type,
        'spirit': spirit,
        'level': level,
        'shiny': shiny,
        'variant': variant.id,
        'behavior': behavior.id,
        'count': count,
      };
}

class DebugCreatures {
  final _pending = <({DebugCreatureSpec spec, List<String> ecoIds})>[];
  final _live = <WorldSpawn>[];
  final _until = <int, int>{};
  int _n = 0;

  /// Pedidos à espera da próxima atualização do mapa (o mapa pode nem estar aberto).
  int get pending => _pending.fold(0, (a, p) => a + p.spec.count);

  /// Pede [spec]. [ecoIds] são as espécies Eco candidatas (a escolhida, ou todas do tipo); a camada troca o sufixo.
  void request(DebugCreatureSpec spec, List<String> ecoIds) {
    if (ecoIds.isEmpty) return;
    _pending.add((spec: spec, ecoIds: ecoIds));
  }

  void clear() {
    _pending.clear();
    _live.clear();
    _until.clear();
  }

  /// As criaturas de debug vivas em [tUtc]. Os pedidos pendentes nascem agora em pontos sorteados dentro de um círculo de
  /// [radiusM] em volta do jogador (células z21 [px], [py]). [biomeAt] dá a chave de bioma de uma célula z20 (variante de
  /// bioma); sem ele, `urban`.
  List<WorldSpawn> around({required double px, required double py, required double metersPerCell21, required double radiusM, required int tUtc, String? Function(int cellX, int cellY)? biomeAt}) {
    for (final p in _pending) {
      for (var i = 0; i < p.spec.count; i++) {
        final s = _place(p.spec, p.ecoIds, px, py, metersPerCell21, radiusM, tUtc, biomeAt);
        _live.add(s);
        _until[s.uid] = tUtc + kDebugCreatureS;
      }
    }
    _pending.clear();
    _live.removeWhere((s) => (_until[s.uid] ?? 0) <= tUtc);
    return List.unmodifiable(_live);
  }

  WorldSpawn _place(DebugCreatureSpec spec, List<String> ecoIds, double px, double py, double mpc, double radiusM, int tUtc, String? Function(int, int)? biomeAt) {
    final n = _n++;
    // Fora do mundo: o sorteio só precisa variar, mas usa o mesmo PCG32 do jogo.
    final rng = Pcg32(fnv1a64([tUtc, n]), saltKenoma);
    final eco = ecoIds[rng.nextInt(ecoIds.length)];
    final id = spec.spirit ? '${eco.substring(0, eco.lastIndexOf('.'))}.spirit' : eco;
    final r = radiusM * math.sqrt(rng.nextFloat()) / mpc, a = 2 * math.pi * rng.nextFloat();
    final x = px + r * math.cos(a), y = py + r * math.sin(a);
    final cx = (x / 2).floor(), cy = (y / 2).floor();
    String? biome() {
      try {
        return biomeAt?.call(cx, cy);
      } catch (_) {
        return null; // fora do pacote
      }
    }

    return WorldSpawn(
      uid: kDebugUidBase + ((tUtc & 0xFFFFFFFF) << 8) + (n & 0xFF),
      kind: 'eco',
      entryId: id,
      quantity: 1,
      x: x,
      y: y,
      cellX: cx,
      cellY: cy,
      window: 0,
      level: spec.level,
      behavior: spec.behavior,
      variant: switch (spec.variant) {
        DebugVariant.none => null,
        DebugVariant.biome => biome() ?? 'urban',
        DebugVariant.crimson => DebugVariant.crimson.id,
      },
      shiny: spec.shiny,
    );
  }
}
