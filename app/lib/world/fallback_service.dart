/// Fallback sob demanda (docs/GDD.md): pede à Overpass o bloco do jogador e os vizinhos na direção do movimento, guarda em
/// disco e entrega ao [LayeredWorld]. A data da consulta é o início da época vigente, para dois aparelhos receberem o mesmo
/// OSM em dias diferentes. Dart puro, com o HTTP injetado. Falha de rede nunca aparece: fica no piso e tenta de novo.
library;

import 'dart:convert';
import 'dart:io' show HttpException;
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import '../core/epochs.dart';
import '../core/tiles.dart';
import '../data/block_cache.dart';
import 'fallback/block.dart';
import 'geo_fix.dart';
import 'layered_world.dart';
import 'map_fallback_balance.dart';

/// As funções do bloco, injetadas. As regras do OSM já vêm ligadas a elas. `build`, `encode` e `decode` rodam em Isolate:
/// o que elas capturam tem de poder atravessar.
class FallbackCodec {
  const FallbackCodec({required this.query, required this.build, required this.encode, required this.decode});

  final String Function({required int tx, required int ty, required String dateIso}) query;
  final FallbackBlock Function({required String overpassJson, required int tx, required int ty, required int epochId}) build;
  final Uint8List Function(FallbackBlock block) encode;
  final FallbackBlock Function(Uint8List bytes) decode;
}

class HttpReply {
  const HttpReply(this.status, this.body);

  final int status;
  final Uint8List body;
}

/// Um POST `application/x-www-form-urlencoded` com [body]. Lança em erro de rede, timeout ou resposta maior que [maxBytes].
typedef PostForm = Future<HttpReply> Function(Uri url, String body, {required String userAgent, required Duration timeout, required int maxBytes});

/// Segundos UTC em ISO, no formato da Overpass.
String isoUtc(int seconds) => DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true).toIso8601String().replaceFirst('.000Z', 'Z');

/// Roda fora da tela: nada da resposta é conferido na thread do jogo. A Overpass pode responder 200 com `remark` quando estoura
/// o tempo no meio: esse bloco viria cortado e ficaria no cache para sempre.
(FallbackBlock, Uint8List) _buildBlock(FallbackCodec codec, Uint8List body, int tx, int ty, int epochId, String dateIso) {
  final text = utf8.decode(body);
  final json = jsonDecode(text) as Map<String, dynamic>;
  final remark = json['remark'];
  if (remark != null) throw FormatException('Overpass: $remark');
  // Um espelho com a base atrasada responde à consulta com data usando o que tem: o mundo sairia diferente do dos amigos.
  // Visto em 2026-11-09: overpass.private.coffee com base de 2026-05-31. A base tem de cobrir a data pedida.
  final base = (json['osm3s'] as Map<String, dynamic>?)?['timestamp_osm_base'] as String?;
  if (base != null && DateTime.parse(base).isBefore(DateTime.parse(dateIso))) {
    throw FormatException('Overpass com base de $base, anterior a $dateIso');
  }
  final block = codec.build(overpassJson: text, tx: tx, ty: ty, epochId: epochId);
  return (block, codec.encode(block));
}

// Funções soltas: um closure dentro da classe levaria o serviço inteiro para o Isolate.
Future<(FallbackBlock, Uint8List)> _buildInIsolate(FallbackCodec codec, Uint8List body, int tx, int ty, int epochId, String dateIso) =>
    Isolate.run(() => _buildBlock(codec, body, tx, ty, epochId, dateIso));

Future<FallbackBlock> _decodeInIsolate(FallbackCodec codec, Uint8List bytes) => Isolate.run(() => codec.decode(bytes));

class FallbackService {
  FallbackService({
    required this.world,
    required this.schedule,
    required this.codec,
    required this.balance,
    required this.post,
    required this.cache,
    required this.appVersion,
    required this.nowUtc,
    required this.realNowUtc,
  });

  final LayeredWorld world;
  final EpochSchedule schedule;
  final FallbackCodec codec;
  final MapFallbackBalance balance;
  final PostForm post;
  final BlockCache cache;
  final String appVersion;

  /// O relógio do jogo decide a época; o real decide as esperas.
  final int Function() nowUtc;
  final int Function() realNowUtc;

  /// Rede sem cobrança (Wi-Fi): pré-carrega os blocos à frente, com as mesmas regras de uma consulta por bloco e da espera
  /// entre consultas. Nos dados móveis, só o bloco do jogador e os seguintes na direção do movimento.
  bool Function() unmetered = _metered;

  static bool _metered() => false;

  /// Velocidade pelo GPS, em m/s, e a direção do movimento em z21 (`-1`, `0` ou `1` por eixo).
  double speedMps = 0;
  (int, int) _dir = (0, 0);
  GeoFix? _anchor;

  /// Janela da medida: o tremor do GPS pesa menos que entre duas leituras seguidas.
  static const int _windowMs = 3000;

  /// O movimento conta para um eixo a partir de sen(22,5°) da velocidade: oito direções.
  static const double _axis = 0.38;

  /// Abaixo disto não há direção: o jogador está parado.
  static const double _movingMps = 0.5;

  int _server = 0, _fails = 0, _nextAt = 0;
  bool _querying = false;

  /// Por (época, tx, ty): consulta já bem-sucedida.
  final _done = <(int, int, int)>{};

  /// Por (época, tx, ty): o disco já foi lido; `true` se tinha bloco.
  final _disk = <(int, int, int), bool>{};

  /// Uma leitura crua do GPS: vale o maior entre a velocidade do próprio GPS (Doppler) e a diferença entre posições.
  void noteFix(GeoFix fix) {
    final a = _anchor;
    if (a == null) {
      _anchor = fix;
      return;
    }
    final dt = (fix.timeMs - a.timeMs) / 1000;
    if (dt * 1000 < _windowMs) {
      speedMps = math.max(speedMps, fix.speedMps ?? 0); // subir é imediato; descer espera a janela
      return;
    }
    _anchor = fix;
    final (ax, ay) = latLonToTileFraction(a.lat, a.lon, biomeZoom);
    final (bx, by) = latLonToTileFraction(fix.lat, fix.lon, biomeZoom);
    final dx = bx - ax, dy = by - ay, d = math.sqrt(dx * dx + dy * dy);
    final moved = d * metersPerCell(fix.lat) / dt;
    speedMps = math.max(fix.speedMps ?? 0, moved); // um 0 do GPS não prova que ele parou
    _dir = moved < _movingMps ? (0, 0) : (dx.abs() >= _axis * d ? dx.sign.toInt() : 0, dy.abs() >= _axis * d ? dy.sign.toInt() : 0);
  }

  /// O bloco do jogador e, em seguida, os vizinhos para onde ele vai, nos que um bloco acrescenta algo. Com Wi-Fi, depois
  /// deles, os blocos até `prefetch_blocks` à frente num cone de 90° (parado, os oito em volta), do mais perto ao mais longe.
  List<(int, int)> wanted(double lat, double lon) {
    final (x, y) = latLonToTile(lat, lon, blockZoom);
    final (sx, sy) = _dir;
    final ahead = <(int, int)>[];
    if (unmetered()) {
      final n = balance.prefetchBlocks;
      for (var dy = -n; dy <= n; dy++) {
        for (var dx = -n; dx <= n; dx++) {
          final dot = dx * sx + dy * sy, cross = dx * sy - dy * sx;
          final take = sx == 0 && sy == 0 ? math.max(dx.abs(), dy.abs()) == 1 : dot > 0 && cross.abs() <= dot;
          if (take) ahead.add((dx, dy));
        }
      }
      int ring((int, int) d) => math.max(d.$1.abs(), d.$2.abs());
      ahead.sort((a, b) => ring(a) != ring(b) ? ring(a) - ring(b) : (a.$1 * a.$1 + a.$2 * a.$2) - (b.$1 * b.$1 + b.$2 * b.$2));
    }
    return [
      for (final t in {
        (x, y),
        if (sx != 0) (x + sx, y),
        if (sy != 0) (x, y + sy),
        if (sx != 0 && sy != 0) (x + sx, y + sy),
        for (final (dx, dy) in ahead) (x + dx, y + dy),
      })
        if (world.needsBlock(t.$1, t.$2)) t,
    ];
  }

  /// Um passo: lê do disco o que falta e faz no máximo uma consulta. Pode ser chamado a cada segundo.
  Future<void> tick(double lat, double lon) async {
    final epoch = schedule.select(nowUtc()).epoch;
    final tiles = wanted(lat, lon);
    for (final t in tiles) {
      await _fromDisk(t.$1, t.$2, epoch.id);
    }
    if (_querying || speedMps * 3.6 > balance.maxQuerySpeedKmh || realNowUtc() < _nextAt) return;
    for (final (tx, ty) in tiles) {
      if ((world.block(tx, ty)?.epochId ?? -1) < epoch.id && !_done.contains((epoch.id, tx, ty))) {
        await _query(tx, ty, epoch);
        return;
      }
    }
  }

  Future<void> _fromDisk(int tx, int ty, int epoch) async {
    final key = (epoch, tx, ty);
    final current = world.block(tx, ty);
    if ((current?.epochId ?? -1) >= epoch) return;
    final seen = _disk[key];
    if (seen == false || (seen == true && current != null)) return; // sem arquivo, ou já em memória
    _disk[key] = false;
    final block = await cache.read(epoch, tx, ty, (bytes) => _decodeInIsolate(codec, bytes));
    if (block == null || block.tx != tx || block.ty != ty) return;
    _disk[key] = true;
    world.putBlock(block);
  }

  Future<void> _query(int tx, int ty, Epoch epoch) async {
    _querying = true;
    try {
      final q = codec.query(tx: tx, ty: ty, dateIso: isoUtc(epoch.startsUtc));
      final reply = await post(
        balance.servers[_server],
        'data=${Uri.encodeQueryComponent(q)}',
        userAgent: 'Kenoma/$appVersion',
        timeout: Duration(seconds: balance.timeoutS),
        maxBytes: balance.maxReplyBytes,
      );
      if (reply.status != 200) throw HttpException('Overpass ${reply.status}');
      final (block, bytes) = await _buildInIsolate(codec, reply.body, tx, ty, epoch.id, isoUtc(epoch.startsUtc));
      _done.add((epoch.id, tx, ty));
      world.putBlock(block);
      _fails = 0;
      _nextAt = realNowUtc() + balance.minGapS;
      await cache.write(epoch.id, tx, ty, bytes);
    } catch (_) {
      // Qualquer falha troca de servidor; só depois de passar por todos é que espera o retry.
      _fails++;
      _server = (_server + 1) % balance.servers.length;
      _nextAt = realNowUtc() + (_fails % balance.servers.length == 0 ? balance.retryS : balance.minGapS);
    } finally {
      _querying = false;
    }
  }
}
