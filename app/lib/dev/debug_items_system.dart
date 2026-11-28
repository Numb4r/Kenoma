/// Aba Sistema: o desempenho (latência do toque, a simulação do tráfego), o feed de regiões e a identidade e a época (o
/// player_id, o log de versões e a cadeia de hashes que assina a história do save).
library;

import '../net/feed_config.dart' show kFeedBaseUrl;
import 'debug_env.dart';
import 'debug_registry.dart';
import 'identity_section.dart';
import 'tap_latency.dart';

List<DebugEntry> systemEntries(DebugEnv env) {
  final tools = env.tools;
  IdentityInfo? identity;
  String? identityError;
  return [
    DebugEntry(
      id: 'system.tap_latency',
      name: 'Latência do toque',
      tab: DebugTab.system,
      kind: DebugKind.view,
      aliases: const ['perf.tap_latency'],
      keywords: const ['fps', 'sonda', 'mediana', 'toque', 'quadro', 'desempenho'],
      info: 'Do dedo encostar até o primeiro quadro pronto depois dele. A meta é 100 ms.',
      read: () {
        final t = TapLatency.instance;
        return t.samples.isEmpty ? 'Nenhum toque medido ainda.' : 'Mediana ${t.median!.toStringAsFixed(0)} ms · pior ${t.worst!.toStringAsFixed(0)} ms (${t.samples.length} toques).';
      },
    ),
    DebugEntry(
      id: 'system.tap_latency_reset',
      name: 'Zerar a latência do toque',
      tab: DebugTab.system,
      kind: DebugKind.action,
      keywords: const ['latência', 'zerar', 'desempenho'],
      run: (_) {
        TapLatency.instance.clear();
        return 'Medição zerada';
      },
    ),
    DebugEntry(
      id: 'system.traffic_stats',
      name: 'Simulação do tráfego',
      tab: DebugTab.system,
      kind: DebugKind.view,
      keywords: const ['tráfego', 'carros', 'passantes', 'agentes', 'custo', 'desempenho'],
      read: () => tools.trafficStats?.call() ?? 'Abra o mapa do jogo para a simulação começar.',
    ),
    DebugEntry(
      id: 'system.feed_url',
      name: 'URL do feed de regiões',
      tab: DebugTab.system,
      kind: DebugKind.action,
      aliases: const ['sign.feed_url'],
      keywords: const ['regions.json', 'região', 'pacote', 'servidor local', 'adb reverse', 'url', 'assinatura'],
      info: 'Vale até fechar o app. A assinatura continua obrigatória: o servidor precisa servir regions.json e pacotes assinados.',
      params: const [DebugParam('url', 'URL base', kind: DebugParamKind.text)],
      status: () => tools.feedBaseUrl,
      run: (c) {
        if (c['url'].isEmpty) throw const DebugError('diga a URL');
        tools.setFeedBaseUrl(c['url']);
        return 'Feed em ${tools.feedBaseUrl}';
      },
      offReal: () => tools.feedBaseUrl == kFeedBaseUrl ? null : 'feed local',
      toReal: () => tools.setFeedBaseUrl(null),
    ),
    DebugEntry(
      id: 'system.identity',
      name: 'Identidade e época',
      tab: DebugTab.system,
      kind: DebugKind.view,
      aliases: const ['sign.identity'],
      keywords: const ['player_id', 'versions_seen', 'log de versões', 'época', 'fundador', 'grupo', 'seed', 'schema', 'cadeia', 'hash', 'assinatura'],
      info: 'Lido do save em disco: funciona antes de abrir o mapa. O botão de copiar leva o player_id inteiro e o log de versões.',
      load: () async {
        try {
          identity = await readIdentity(tools.clock, store: await env.openSave());
          identityError = null;
        } catch (e) {
          identityError = 'Erro: $e';
        }
      },
      read: () => identityError ?? identity?.line ?? 'Lendo o save...',
      copy: () => identity?.full,
      extra: (_) => IdentityDetails(info: identity),
    ),
  ];
}
