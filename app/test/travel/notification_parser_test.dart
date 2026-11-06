// TODOS os textos deste arquivo são SINTÉTICOS, escritos pelo que se conhece dos apps, sem nenhuma notificação real
// capturada. Conferir com corrida real e ajustar `assets/data/ride_patterns.json`.
import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/travel/deep_links.dart';
import 'package:kenoma/travel/notification_parser.dart';
import 'package:kenoma/travel/ride.dart';

import '../support/fixtures.dart';

void main() {
  final patterns = RidePatterns.fromJson(loadJson('assets/data/ride_patterns.json'));
  RideSignal uber(String title, String text) => patterns.parse(kUberPackage, title, text);
  RideSignal taxi(String title, String text) => patterns.parse(k99Package, title, text);

  test('todos os padrões do arquivo são regex válidas', () {
    final j = loadJson('assets/data/ride_patterns.json');
    for (final app in (j['apps'] as Map<String, dynamic>).values) {
      final a = app as Map<String, dynamic>;
      for (final list in (a['states'] as Map<String, dynamic>).values) {
        for (final p in list as List<dynamic>) {
          expect(() => RegExp(p as String, caseSensitive: false, unicode: true), returnsNormally);
        }
      }
    }
  });

  group('sintético, conferir com corrida real: Uber', () {
    test('estados', () {
      expect(uber('Uber', 'Procurando um motorista').state, RideState.searching);
      expect(uber('Seu motorista está a caminho', 'Chega em 5 min').state, RideState.driverComing);
      expect(uber('Seu motorista chegou', 'Encontre João no ponto de embarque').state, RideState.arrived);
      expect(uber('Viagem iniciada', 'A caminho do destino').state, RideState.inTrip);
      expect(uber('Você chegou', 'Avalie sua viagem').state, RideState.finished);
    });

    test('ETA em minutos, sem diferença de maiúsculas', () {
      expect(uber('SEU MOTORISTA ESTÁ A CAMINHO', 'CHEGA EM 12 MIN').etaMin, 12);
      expect(uber('Motorista a caminho', 'Chega em 3 minutos').etaMin, 3);
    });

    test('modelo e cor do carro', () {
      final s = uber('João chega em 4 min', 'Chevrolet Onix Plus prata, placa ABC1D23');
      expect(s.carType, 'sedan');
      expect(s.carColor, 0xFFB8BCC8);
      expect(uber('x', 'Fiat Mobi branco').carType, 'hatch');
      expect(uber('x', 'Hyundai Creta preta').carType, 'suv');
      expect(uber('x', 'Toyota Corolla Cross vermelho').carType, 'suv');
    });

    test('cor com acento e carro sem tabela', () {
      expect(uber('x', 'Carro bordô').carColor, 0xFF6E2438);
      final s = uber('x', 'Veículo Zafrano 3000');
      expect(s.carType, isNull);
      expect(s.carColor, isNull);
    });
  });

  group('sintético, conferir com corrida real: 99', () {
    test('estados', () {
      expect(taxi('99', 'Chamando motoristas').state, RideState.searching);
      expect(taxi('Corrida aceita', 'Maria está a caminho').state, RideState.driverComing);
      expect(taxi('O motorista chegou', 'Vá até o local de embarque').state, RideState.arrived);
      expect(taxi('Corrida iniciada', 'Boa viagem').state, RideState.inTrip);
      expect(taxi('Corrida finalizada', 'Obrigado').state, RideState.finished);
    });
  });

  group('sintético, conferir com corrida real: texto não reconhecido', () {
    test('cai para os botões sem erro', () {
      final s = uber('Promoção', 'Ganhe desconto na próxima viagem!');
      expect(s.isEmpty, isTrue);
      final r = Ride(appName: 'Uber')..onSignal(s, 0);
      expect(r.state, RideState.searching);
      expect(r.buttons, contains(RideButton.boarded));
    });

    test('outro pacote não é lido', () {
      expect(patterns.parse('com.whatsapp', 'Seu motorista chegou', 'em 5 min').isEmpty, isTrue);
    });

    test('sem o arquivo de padrões nada é reconhecido', () {
      expect(RidePatterns.none().parse(kUberPackage, 'Seu motorista chegou', '').isEmpty, isTrue);
    });

    test('um padrão quebrado no arquivo fica de fora, sem derrubar o resto', () {
      final p = RidePatterns.fromJson({
        'apps': {
          kUberPackage: {
            'states': {
              'arrived': ['(quebrado', 'chegou'],
            },
            'eta': ['(\\d+) min'],
          },
        },
      });
      expect(p.parse(kUberPackage, 'Chegou', '').state, RideState.arrived);
    });
  });
}
