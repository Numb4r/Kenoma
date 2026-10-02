/// Contas pequenas que o sinal e as ondas partilham.
library;

/// Dobra o valor para dentro de `[0, 1]`, refletindo nas bordas.
double fold01(double f) {
  final m = f % 2;
  final x = m < 0 ? m + 2 : m;
  return x > 1 ? 2 - x : x;
}

/// Easing smoothstep: 0 em `x <= 0`, 1 em `x >= 1`, com derivada zero nas pontas.
double smoothstep(double x) {
  final c = x.clamp(0.0, 1.0);
  return c * c * (3 - 2 * c);
}
