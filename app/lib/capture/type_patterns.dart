/// Os padrões de resistência dos nove tipos da fase 1 (docs/GDD.md, tabela de resistência no dial). Como os três do MVP,
/// mexem no sinal e nunca no dial, e saem todos de sorteios do `Pcg32` da sintonia (feitos no fim da sequência, para os
/// sinais do Fogo, da Água e da Planta continuarem os mesmos). Lógica pura; a tela só desenha [TypeFx].
///
/// Todos, menos o Elétrico (que só salta), têm uma deriva própria em onda, que cresce com a intensidade.
///
/// - Terra: faixas pesadas e fixas no dial (estratos de rocha); dentro delas o progresso sobe devagar.
/// - Elétrico: o sinal salta entre duas ou três frequências em ritmo fixo.
/// - Metal: de tempos em tempos sobe a blindagem; alinhado, só solta faísca, sem progresso.
/// - Luz: clarões apagam a onda por um instante e fica a imagem residual de onde ela estava.
/// - Sombra: a onda afunda em tinta preta; o pulso continua fraco no dial.
/// - Espectral: uma cópia cinza imita a real com atraso.
/// - Digital: cópias falsas que pulam de lugar, com glitch.
/// - Feérico: inverte o sentido do dial de tempos em tempos e troca de padrão no meio (`stage_s`).
/// - Dracônico: começa calmo e a cada etapa (`stage_s`, um terço de uma sintonia forte) soma o padrão de outro tipo.
library;

import 'dart:math' as math;

import '../core/pcg32.dart';
import 'eco_type.dart';
import 'tuning_balance.dart';

/// O que a tela precisa para desenhar o padrão em um instante.
class TypeFx {
  const TypeFx({
    this.strata = const [],
    this.hopFlash = 0,
    this.armored = false,
    this.flash = 0,
    this.afterimage,
    this.ink = 0,
    this.ghost,
    this.decoys = const [],
    this.glitch = 0,
    this.inverted = false,
    this.stage = 0,
  });

  static const none = TypeFx();

  /// Terra: as faixas pesadas `[lo, hi]` do eixo do dial.
  final List<(double, double)> strata;

  /// Elétrico: de 1 (acabou de saltar) a 0, para o arco.
  final double hopFlash;

  /// Metal: a blindagem está de pé.
  final bool armored;

  /// Luz: a força do clarão (0 a 1) e a frequência em que a onda estava quando ele veio.
  final double flash;
  final double? afterimage;

  /// Sombra: quanto da onda a tinta cobre (0 a 1).
  final double ink;

  /// Espectral: a frequência da cópia cinza.
  final double? ghost;

  /// Digital: as frequências das cópias falsas e a fase do glitch (muda a cada pulo).
  final List<double> decoys;
  final int glitch;

  /// Feérico: o dial está invertido.
  final bool inverted;

  /// Dracônico: quantos padrões já somou (0, 1 ou 2). Feérico: 0 antes da troca, 1 depois.
  final int stage;
}

class TypePattern {
  TypePattern._(this.type, this.intensity, this._b, this.strata, this._hops, this._hopPeriod, this._phase, this._flashes, this._decoyBase, this._jumpS, this._invertEvery);

  /// Sem padrão: os três do MVP, ou sem resistência.
  static final none = TypePattern._(EcoType.fire, 0, null, const [], const [], 1, 0, const [], const [], 1, 0);

  /// Monta o padrão do tipo [type] na [intensity], sorteando de [rng].
  factory TypePattern.generate({required EcoType type, required double intensity, required Pcg32 rng, required Phase1Balance balance, double horizonS = 60}) {
    if (intensity <= 0 || EcoType.mvp.contains(type)) return none;
    final t = type.name;
    final phase = 2 * math.pi * rng.nextFloat();
    var strata = const <(double, double)>[];
    var hops = const <double>[];
    var hopPeriod = 1.0, jump = 1.0, invert = 0.0;
    var flashes = const <double>[];
    var decoys = const <double>[];
    List<double> hopSet(String ty, String key, int n) {
      final spread = balance.at(ty, key, intensity);
      // Frequências fixas em volta do zero, embaralhadas: o salto nunca cai no mesmo lugar duas vezes seguidas.
      final set = [for (var i = 0; i < n; i++) spread * (n == 1 ? 0.0 : (2 * i / (n - 1) - 1))];
      for (var i = set.length - 1; i > 0; i--) {
        final j = rng.nextInt(i + 1), tmp = set[i];
        set[i] = set[j];
        set[j] = tmp;
      }
      return set;
    }

    switch (type) {
      case EcoType.earth:
        final n = balance.at(t, 'bands', intensity).round(), w = balance.at(t, 'width', intensity);
        // Uma faixa em cada fatia do eixo, em lugar sorteado dentro dela (a fatia é mais larga que a faixa: não se sobrepõem).
        strata = [
          for (var i = 0; i < n; i++)
            () {
              final lo = i / n + rng.nextFloat() * (1 / n - w);
              return (lo, lo + w);
            }(),
        ];
      case EcoType.electric:
        hops = hopSet(t, 'spread', balance.at(t, 'freqs', intensity).round());
        hopPeriod = balance.at(t, 'period_s', intensity);
      case EcoType.metal:
        break; // só a fase
      case EcoType.light:
        final every = balance.at(t, 'every_s', intensity);
        final list = <double>[];
        for (var at = every * (0.5 + 0.5 * rng.nextFloat()); at < horizonS; at += every * (0.75 + 0.5 * rng.nextFloat())) {
          list.add(at);
        }
        flashes = list;
      case EcoType.shadow || EcoType.spectral:
        break;
      case EcoType.digital:
        final n = balance.at(t, 'decoys', intensity).round(), spread = balance.at(t, 'spread', intensity);
        decoys = [for (var i = 0; i < n; i++) spread * (0.5 + 0.5 * rng.nextFloat()) * (rng.nextFloat() < 0.5 ? -1 : 1)];
        jump = balance.at(t, 'jump_s', intensity);
      case EcoType.fae:
        hops = hopSet(t, 'hop', 3);
        hopPeriod = balance.at(t, 'hop_period_s', intensity);
        invert = balance.at(t, 'invert_every_s', intensity);
      case EcoType.draconic:
        hops = hopSet(t, 'hop', 3);
        hopPeriod = balance.at(t, 'hop_period_s', intensity);
      case EcoType.fire || EcoType.water || EcoType.plant:
        break;
    }
    return TypePattern._(type, intensity, balance, strata, hops, hopPeriod, phase, flashes, decoys, jump, invert);
  }

  final EcoType type;
  final double intensity;
  final Phase1Balance? _b;

  /// Terra: as faixas pesadas do dial.
  final List<(double, double)> strata;
  final List<double> _hops;
  final double _hopPeriod, _phase;
  final List<double> _flashes, _decoyBase;
  final double _jumpS, _invertEvery;

  bool get isNone => _b == null;
  String get _t => type.name;

  /// Quando o padrão muda: o Feérico troca neste instante; o Dracônico soma um padrão a cada tanto destes.
  double get _stageS => _at('stage_s');
  double _at(String key) => _b!.at(_t, key, intensity);

  /// Em que etapa o padrão está em [t]: o Feérico troca na metade (0, 1); o Dracônico soma um padrão a cada terço (0, 1, 2).
  int stageAt(double t) {
    if (isNone) return 0;
    if (type == EcoType.fae) return t < _stageS ? 0 : 1;
    if (type == EcoType.draconic) return math.min(2, (t / (_stageS)).floor());
    return 0;
  }

  double _sine(String amp, String period, double t) => _at(amp) * math.sin(2 * math.pi * t / _at(period) + _phase);

  /// O salto entre frequências fixas a partir de [from]: muda a cada período, com um deslize curto.
  double _hop(double t, double from) {
    if (_hops.isEmpty || t < from) return 0;
    final k = ((t - from) / _hopPeriod).floor(), into = (t - from) - k * _hopPeriod;
    final now = _hops[k % _hops.length], before = k == 0 ? 0.0 : _hops[(k - 1) % _hops.length];
    final glide = _b!.glideS;
    final u = (into / glide).clamp(0.0, 1.0);
    return before + (now - before) * u * u * (3 - 2 * u);
  }

  /// Os instantes dos saltos até [horizonS] (Elétrico; no Feérico e no Dracônico, os da etapa em que há saltos).
  List<double> hopTimes(double horizonS) {
    if (_hops.isEmpty) return const [];
    final from = switch (type) { EcoType.fae => _stageS, EcoType.draconic => 2 * _stageS, _ => 0.0 };
    return [for (var at = from + (type == EcoType.electric ? _hopPeriod : 0); at <= horizonS; at += _hopPeriod) at];
  }

  /// Quanto o padrão soma à frequência do sinal em [t] (antes de dobrar nas bordas).
  double offsetAt(double t) {
    if (isNone) return 0;
    switch (type) {
      case EcoType.electric:
        return _hop(t, 0);
      case EcoType.earth || EcoType.metal || EcoType.light || EcoType.shadow || EcoType.spectral || EcoType.digital:
        // A deriva própria do tipo: sem ela o clarão, a tinta e as cópias não custariam nada. Entra aos poucos: a
        // sintonia começa na frequência sorteada, como nos outros tipos.
        return _sine('drift', 'drift_period_s', t) * (t / _b!.blendS).clamp(0.0, 1.0);
      case EcoType.fae:
        // Primeira metade: deriva em onda. Segunda: saltos. A troca é contínua (o salto começa do zero).
        final half = _stageS;
        return t < half ? _sine('drift', 'drift_period_s', t) * _fadeOut(t, half) : _hop(t, half);
      case EcoType.draconic:
        final third = _stageS;
        final drift = t < third ? 0.0 : _sine('drift', 'drift_period_s', t) * ((t - third) / _b!.blendS).clamp(0.0, 1.0);
        return drift + _hop(t, 2 * third);
      default:
        return 0;
    }
  }

  /// A deriva some no último segundo antes da troca, para o sinal não pular.
  double _fadeOut(double t, double end) => ((end - t) / _b!.blendS).clamp(0.0, 1.0);

  /// Metal (e o Dracônico no último terço): a blindagem está de pé em [t].
  bool armoredAt(double t) {
    if (isNone) return false;
    if (type == EcoType.metal) return _window(t, _at('period_s'), _at('duty'));
    if (type == EcoType.draconic && stageAt(t) >= 2) return _window(t, _at('armor_period_s'), _at('armor_duty'));
    return false;
  }

  bool _window(double t, double period, double duty) {
    final u = (t / period + _phase / (2 * math.pi)) % 1.0;
    return u > 1 - duty;
  }

  /// Quanto o progresso sobe com o dial em [dial] alinhado em [t]: 1 normal; menos dentro de uma faixa de Terra; 0 com a
  /// blindagem do Metal de pé.
  double progressFactor(double dial, double t) {
    if (isNone) return 1;
    if (armoredAt(t)) return 0;
    if (type == EcoType.earth) {
      for (final (lo, hi) in strata) {
        if (dial >= lo && dial <= hi) return _at('slow');
      }
    }
    return 1;
  }

  /// Feérico: o sentido do dial em [t]: 1 normal, -1 invertido.
  double dialSignAt(double t) {
    if (isNone || type != EcoType.fae || _invertEvery <= 0) return 1;
    return ((t + _phase / (2 * math.pi) * _invertEvery) / _invertEvery).floor().isOdd ? -1 : 1;
  }

  /// Luz: o clarão em [t]: a força (1 no começo, caindo até 0 no fim do tempo cego) e o instante em que veio.
  (double, double)? flashAt(double t) {
    if (isNone || type != EcoType.light) return null;
    final blind = _at('blind_s');
    for (final at in _flashes) {
      if (t >= at && t < at + blind) return (1 - (t - at) / blind, at);
    }
    return null;
  }

  /// Sombra: quanto da onda a tinta cobre em [t], de 0 a 1.
  double inkAt(double t) {
    if (isNone || type != EcoType.shadow) return 0;
    final period = _at('period_s'), duty = _at('duty');
    final u = (t / period + _phase / (2 * math.pi)) % 1.0;
    if (u > duty) return 0;
    // Afunda, fica e volta: um trapézio dentro da janela.
    final x = u / duty, edge = 0.2;
    final k = x < edge ? x / edge : (x > 1 - edge ? (1 - x) / edge : 1.0);
    return k * _at('depth');
  }

  /// Espectral: o atraso da cópia cinza em [t], em segundos.
  double get ghostDelayS => isNone || type != EcoType.spectral ? 0 : _at('delay_s');

  /// Digital: os deslocamentos das cópias falsas em [t] (somados à frequência real) e a fase do glitch.
  (List<double>, int) decoysAt(double t) {
    if (isNone || type != EcoType.digital) return (const [], 0);
    final k = (t / _jumpS).floor();
    // A cada pulo as cópias trocam de lado e de distância, sem sorteio novo: a ordem roda e o sinal alterna.
    return ([for (var i = 0; i < _decoyBase.length; i++) _decoyBase[(i + k) % _decoyBase.length] * ((k + i).isEven ? 1 : -1)], k);
  }

  /// Os instantes dos clarões (Luz).
  List<double> get flashTimes => _flashes;

  /// O que a tela desenha em [t]. [frequencyAt] é o sinal real (a cópia espectral e a imagem residual saem dele).
  TypeFx fxAt(double t, double Function(double t) frequencyAt) {
    if (isNone) return TypeFx.none;
    final flash = flashAt(t);
    final (decoys, glitch) = decoysAt(t);
    final f = frequencyAt(t);
    var hopFlash = 0.0;
    if (_hops.isNotEmpty) {
      final from = switch (type) { EcoType.fae => _stageS, EcoType.draconic => 2 * _stageS, _ => 0.0 };
      if (t >= from) hopFlash = (1 - (((t - from) % _hopPeriod) / 0.35)).clamp(0.0, 1.0);
      if (type == EcoType.electric && t < _hopPeriod) hopFlash = 0;
    }
    return TypeFx(
      strata: strata,
      hopFlash: hopFlash,
      armored: armoredAt(t),
      flash: flash?.$1 ?? 0,
      afterimage: flash == null ? null : frequencyAt(flash.$2),
      ink: inkAt(t),
      ghost: type == EcoType.spectral ? frequencyAt(math.max(0, t - ghostDelayS)) : null,
      decoys: [for (final d in decoys) (f + d).clamp(0.0, 1.0)],
      glitch: glitch,
      inverted: dialSignAt(t) < 0,
      stage: stageAt(t),
    );
  }
}
