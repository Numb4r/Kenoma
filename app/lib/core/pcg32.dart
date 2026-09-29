/// PCG32, variante XSH RR de referência (docs/fase0-spec.md, seção 3).
library;

const int _multiplier = 6364136223846793005;

class Pcg32 {
  /// Equivale a `pcg32_srandom_r(initstate, initseq)` da referência, com o passo de aquecimento.
  Pcg32(int initstate, int initseq) : _inc = (initseq << 1) | 1 {
    next();
    _state += initstate;
    next();
  }

  int _state = 0;
  final int _inc;

  /// Próxima saída de 32 bits, como inteiro em `[0, 2^32)`.
  int next() {
    final old = _state;
    _state = old * _multiplier + _inc;
    final xorshifted = (((old >>> 18) ^ old) >>> 27) & 0xffffffff;
    final rot = old >>> 59;
    return ((xorshifted >>> rot) | (xorshifted << ((-rot) & 31))) & 0xffffffff;
  }

  /// Float em `[0, 1)`: `next() / 2^32`.
  double nextFloat() => next() / 4294967296.0;

  /// Inteiro em `[0, n)`: `(next() * n) >>> 32`. Exige `0 < n < 2^31` para o produto caber em 64 bits.
  int nextInt(int n) {
    assert(n > 0 && n < 0x80000000, 'n fora de (0, 2^31)');
    return (next() * n) >>> 32;
  }
}
