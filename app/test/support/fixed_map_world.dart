/// O mundo fixo dos testes do mapa: relógio, clima e identidade iguais em toda rodada, a qualquer hora em que a suíte
/// rode e com qualquer carga. O relógio real (ou o clima do mundo) só onde o teste é justamente sobre ele.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/dev/dev_tools.dart';
import 'package:kenoma/dev/game_clock.dart';
import 'package:kenoma/dev/gps_simulator.dart';
import 'package:kenoma/player/game_state.dart' show saveSchemaVersion;
import 'package:kenoma/save/fresh_start.dart' show kFreshStartGroupKey;
import 'package:kenoma/save/save_store.dart';
import 'package:kenoma/world/debug_force.dart';
import 'package:kenoma/world/places.dart';
import 'package:kenoma/world/position_source.dart';

/// 2026-10-15 16:00 UTC, na época 1 (sem o fluxo v2): comportamentos aleatórios abririam a folha de preparo no meio dos
/// testes de toque.
const int kTestUtc = 1792080000;
const String kTestPlayerId = '0123456789abcdef0123456789abcdef';
const String kTestGroup = 'KENOMA-TESTE';

/// As ferramentas de dev com o mundo fixo: o relógio do jogo em [clockUtc] (ou [kTestUtc]) andando com o tempo falso do
/// teste, o clima forçado em [weather] (`null`: o do mundo) e o relógio do clima forçado também no tempo falso. Com
/// [realClock], o relógio do jogo é o real (só o teste sobre o relógio). O simulador segue o tempo falso: com o tempo real
/// da máquina, a suíte carregada fazia o Conjurador andar mais e o Eco escolhido sumir antes do toque.
DevTools fixedDevTools(WidgetTester tester, {required PositionSource realSource, int? clockUtc, bool realClock = false, String? weather = 'clear'}) {
  int fakeMs() => tester.binding.clock.now().millisecondsSinceEpoch;
  final tools = DevTools(
    realSource: realSource,
    simulator: SimulatedPositionSource(lat: kUnicamp.$1, lon: kUnicamp.$2, realTime: false),
    clock: realClock ? null : GameClock(realNowMs: fakeMs),
    force: DebugForce(wallS: () => fakeMs() / 1000),
  );
  if (!realClock || clockUtc != null) tools.clock.setUtc(clockUtc ?? kTestUtc);
  if (weather != null) tools.force.set(weather: weather);
  return tools;
}

/// O save de partida dos testes do mapa: a semente do Recomeçar (`fresh_start.dart`), com o `player_id` e o grupo fixos.
/// Sem ela o `player_id` sai do gerador seguro e o grupo do relógio a cada rodada, e os spawns pessoais e o tráfego mudam.
MemorySaveStore fixedSave() => MemorySaveStore()
  ..json = {
    'schema_version': saveSchemaVersion,
    'founder': {'player_id': kTestPlayerId, 'first_install_version': 'dev', 'first_seen_utc': kTestUtc},
    kFreshStartGroupKey: kTestGroup,
  };
