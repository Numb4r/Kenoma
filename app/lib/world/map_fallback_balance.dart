/// Números do fallback de mapa e dos pacotes baixáveis, lidos de `balance.json` (chave `map_fallback`). Nenhum número vive no
/// código.
library;

const int _mb = 1 << 20;

class MapFallbackBalance {
  MapFallbackBalance(Map<String, dynamic> balance) : this._(balance['map_fallback'] as Map<String, dynamic>);

  MapFallbackBalance._(Map<String, dynamic> m)
      : servers = [for (final s in m['servers'] as List<dynamic>) Uri.parse(s as String)],
        timeoutS = m['timeout_s'] as int,
        minGapS = m['min_gap_s'] as int,
        retryS = m['retry_s'] as int,
        maxQuerySpeedKmh = (m['max_query_speed_kmh'] as num).toDouble(),
        maxReplyBytes = (m['max_reply_mb'] as int) * _mb,
        diskLimitBytes = (m['disk_limit_mb'] as int) * _mb,
        memoryBlocks = m['memory_blocks'] as int,
        regionConfirmBytes = (m['region_confirm_mb'] as int) * _mb,
        floorGridCells = m['floor_grid_cells'] as int,
        prefetchBlocks = m['prefetch_blocks'] as int,
        networkCheckS = m['network_check_s'] as int;

  /// Servidores Overpass, na ordem: troca no erro, no timeout, no 429 e no 504.
  final List<Uri> servers;

  /// Tempo máximo de uma consulta e a espera mínima entre duas.
  final int timeoutS;
  final int minGapS;

  /// Depois de todos os servidores falharem, quanto esperar para tentar de novo.
  final int retryS;

  /// Acima disto (GPS) não se consulta: ônibus fica no piso até parar.
  final double maxQuerySpeedKmh;
  final int maxReplyBytes;

  /// Limite dos blocos em disco (remove os mais antigos) e quantos ficam em memória.
  final int diskLimitBytes;
  final int memoryBlocks;

  /// Acima disto, baixar uma região pede confirmação.
  final int regionConfirmBytes;

  /// Lado da grade fraca do piso, em células z21.
  final int floorGridCells;

  /// Com Wi-Fi, quantos blocos à frente pré-carregar, e de quanto em quanto tempo conferir se a rede é sem cobrança.
  final int prefetchBlocks;
  final int networkCheckS;
}
