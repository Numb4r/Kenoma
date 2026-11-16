import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/world/style_advisor.dart';

/// 0.22.0: a sugestão de trocar para o Simplificado sai uma vez só, depois de um minuto inteiro acima de 20 ms por quadro.
void main() {
  test('um minuto a 25 ms por quadro sugere uma vez; depois nunca mais', () {
    final a = StyleAdvisor();
    var fired = 0;
    for (var i = 0; i < 60 * 40 * 3; i++) {
      if (a.add(0.025)) fired++;
    }
    expect(fired, 1);
    expect(a.alreadySuggested, isTrue);
  });

  test('a 16 ms por quadro não sugere; meio minuto lento também não', () {
    final a = StyleAdvisor();
    for (var i = 0; i < 60 * 60 * 2; i++) {
      expect(a.add(1 / 60), isFalse);
    }
    final b = StyleAdvisor();
    for (var i = 0; i < 30 * 40; i++) {
      expect(b.add(0.025), isFalse);
    }
    expect(b.add(1.0), isFalse, reason: 'uma pausa longa recomeça a janela');
    for (var i = 0; i < 30 * 40; i++) {
      expect(b.add(0.025), isFalse);
    }
  });

  test('com a sugestão já gravada nos Ajustes, nada sai', () {
    final a = StyleAdvisor(alreadySuggested: true);
    for (var i = 0; i < 60 * 40 * 2; i++) {
      expect(a.add(0.03), isFalse);
    }
  });
}
