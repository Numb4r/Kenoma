/// Os pacotes de região baixáveis: catálogo assinado, download com retomada e verificação em Isolate, e a recarga do que já está
/// no disco ao abrir o app. Qualquer falha deixa o jogador no fallback ou no piso, com um aviso curto. Nunca lança.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../core/epochs.dart';
import '../world/layered_world.dart';
import 'feed_config.dart';
import 'map_http.dart';
import 'region_catalog.dart';
import 'signed_feed.dart';

enum RegionStatus {
  /// Dá para baixar.
  available,
  downloading,

  /// No disco e em uso.
  ready,

  /// A última tentativa falhou; o botão tenta de novo.
  failed,

  /// A época vigente não lista este pacote: `epochs.json` manda.
  blocked,
}

/// Pergunta ao jogador se baixa [totalBytes] de [region]. `false` não baixa.
typedef RegionConfirm = Future<bool> Function(RegionEntry region, int totalBytes);

// Função solta: um closure dentro da classe levaria o gerenciador inteiro para o Isolate.
Future<RegionOpen> _openInIsolate(String id, List<RegionFileJob> jobs, String key) => Isolate.run(() => openRegionFiles(id, jobs, publicKeyHex: key));

class RegionManager extends ChangeNotifier {
  RegionManager({
    required this.world,
    required this.schedule,
    required this.dir,
    required this.confirmBytes,
    required this.retryS,
    required this.nowUtc,
    required this.realNowUtc,
    required this.baseUrl,
    this.fetch = httpFetch,
    this.get = httpRangeGet,
    this.publicKeyHex = kFeedPublicKeyHex,
    this.onNotice,
    this.confirm,
  });

  final LayeredWorld world;
  final EpochSchedule schedule;

  /// `getApplicationSupportDirectory()/regions/`.
  final Directory dir;
  final int confirmBytes;
  final int retryS;
  final int Function() nowUtc;
  final int Function() realNowUtc;

  /// A base do feed, terminada em `/`. O debug troca; a assinatura continua obrigatória.
  final String Function() baseUrl;
  final FeedFetch fetch;
  final RangeGet get;
  final String publicKeyHex;

  void Function(String message)? onNotice;
  RegionConfirm? confirm;

  RegionCatalog? catalog;
  final _busy = <String>{};
  final _failed = <String>{};

  /// O jogador recusou nesta sessão: o caminho automático não pergunta de novo.
  final _declined = <String>{};

  /// Quando o caminho automático pode tentar de novo. Arquivo que não confere não volta sozinho: seria baixar tudo de novo a
  /// cada minuto no plano de dados.
  final _autoAt = <String, int>{};
  int _catalogAt = 0;
  bool _refreshing = false;

  Epoch get _epoch => schedule.select(nowUtc()).epoch;

  File get _stamp => File('${dir.path}/regions_try.txt');

  File _dest(RegionFileRef f) => File('${dir.path}/${f.file}');
  File _part(RegionFileRef f) => File('${dir.path}/${f.file}.part');

  RegionStatus statusOf(RegionEntry r) {
    if (world.hasRegion(r.id)) return RegionStatus.ready;
    if (_busy.contains(r.id)) return RegionStatus.downloading;
    if (!catalogMatchesEpoch(r, _epoch)) return RegionStatus.blocked;
    return _failed.contains(r.id) ? RegionStatus.failed : RegionStatus.available;
  }

  /// Ao abrir o app: lê o catálogo do cache e recarrega o que está no disco, conferindo o SHA-256 da época vigente.
  Future<void> loadInstalled() async {
    try {
      await dir.create(recursive: true);
      final cached = await readVerifiedCache(dir, 'regions.json', publicKeyHex: publicKeyHex);
      if (cached != null) catalog = RegionCatalog.fromJson(cached);
    } catch (_) {
      // sem disco, ou catálogo que não abre: segue sem ele
    }
    final epoch = _epoch;
    for (final id in epoch.regionPacks.keys) {
      if (id == kBundledRegion || world.hasRegion(id)) continue;
      final jobs = <RegionFileJob>[
        for (final kind in [kKindLogic, kKindVisual, kKindNoWalk])
          if (epochRefOf(epoch, id, kind) case final ref?) RegionFileJob(kind: kind, path: '${dir.path}/${ref.file}', sha256: ref.sha256),
      ];
      if (!jobs.every((j) => File(j.path).existsSync())) continue;
      await _install(id, await _openInIsolate(id, jobs, publicKeyHex));
    }
    notifyListeners();
  }

  /// Monta a região aberta no mundo; o que não conferiu sai do disco. `true` se entrou.
  Future<bool> _install(String id, RegionOpen open) async {
    for (final p in open.bad) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
    final region = open.region;
    if (region != null) world.addRegion(region);
    return region != null;
  }

  /// Baixa `regions.json` e `.sig`. Só entra se a assinatura bater. No máximo uma vez por dia, salvo [force] ou URL de debug.
  Future<void> refreshCatalog({bool force = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final base = baseUrl();
      final today = DateTime.fromMillisecondsSinceEpoch(realNowUtc() * 1000, isUtc: true).toIso8601String().substring(0, 10);
      final skip = !force && base == kFeedBaseUrl && await _stamp.exists() && (await _stamp.readAsString()).trim() == today;
      _catalogAt = realNowUtc() + (skip ? 3600 : retryS);
      if (skip) return;
      final data = await fetch(Uri.parse('${base}regions.json'));
      final sig = await fetch(Uri.parse('${base}regions.json.sig'));
      if (data == null || sig == null || !verifySigned(data, utf8.decode(sig), publicKeyHex: publicKeyHex)) return;
      catalog = RegionCatalog.fromJson(jsonDecode(utf8.decode(data)) as Map<String, dynamic>);
      await dir.create(recursive: true);
      await storeVerified(dir, 'regions.json', data, sig);
      await _stamp.writeAsString(today, flush: true);
      _catalogAt = realNowUtc() + 3600;
      notifyListeners();
    } catch (_) {
      // sem rede ou arquivo ruim: tenta depois
    } finally {
      _refreshing = false;
    }
  }

  /// Um passo do caminho automático: dentro da bbox de uma região, com internet, baixa sozinho.
  Future<void> tick(double lat, double lon) async {
    if (world.sourceAt(lat, lon) == MapSourceKind.pack) return;
    final now = realNowUtc();
    if (now >= _catalogAt) await refreshCatalog();
    for (final r in catalog?.regions ?? const <RegionEntry>[]) {
      final status = statusOf(r);
      final waiting = status != RegionStatus.available && status != RegionStatus.failed;
      if (waiting || !r.contains(lat, lon) || _declined.contains(r.id) || now < (_autoAt[r.id] ?? 0)) continue;
      await download(r);
      return;
    }
  }

  /// Baixa e instala [r]: acima do limite pede confirmação, nos dois caminhos. `true` se a região entrou no mundo.
  Future<bool> download(RegionEntry r) async {
    if (_busy.contains(r.id) || world.hasRegion(r.id) || !catalogMatchesEpoch(r, _epoch)) return false;
    _busy.add(r.id); // antes da pergunta: um segundo passo não abre outro diálogo
    notifyListeners();
    try {
      final total = r.totalBytes;
      if (total > confirmBytes && !(await confirm?.call(r, total) ?? false)) {
        _declined.add(r.id);
        return false;
      }
      return await _fetchAndInstall(r);
    } finally {
      _busy.remove(r.id);
      notifyListeners();
    }
  }

  Future<bool> _fetchAndInstall(RegionEntry r) async {
    final jobs = <RegionFileJob>[];
    try {
      await dir.create(recursive: true);
      for (final MapEntry(key: kind, value: f) in r.files.entries) {
        final dest = _dest(f);
        if (!await dest.exists()) await _fetchPart(f, Uri.parse(baseUrl()).resolve(f.url));
        jobs.add(RegionFileJob(kind: kind, path: await dest.exists() ? dest.path : _part(f).path, sha256: f.sha256, sigHex: f.sig));
      }
    } catch (_) {
      _fail(r, retry: true); // a parte fica no disco e o próximo pedido continua dela
      return false;
    }
    final open = await _openInIsolate(r.id, jobs, publicKeyHex);
    if (open.region == null) {
      await _install(r.id, open);
      _fail(r, retry: false);
      return false;
    }
    try {
      for (final f in r.files.values) {
        final part = _part(f);
        if (await part.exists()) await part.rename(_dest(f).path);
      }
    } catch (_) {
      _fail(r, retry: true);
      return false;
    }
    await _install(r.id, open);
    _failed.remove(r.id);
    onNotice?.call('Mapa de ${r.name} pronto');
    return true;
  }

  void _fail(RegionEntry r, {required bool retry}) {
    _autoAt[r.id] = retry ? realNowUtc() + retryS : 1 << 62;
    if (_failed.add(r.id)) onNotice?.call('Não consegui baixar ${r.name}');
  }

  /// Baixa para `.part`: continua do tamanho que já está lá, ou recomeça se o servidor não souber retomar.
  Future<void> _fetchPart(RegionFileRef f, Uri url) async {
    final part = _part(f);
    var from = await part.exists() ? await part.length() : 0;
    if (from > f.bytes) {
      await part.delete();
      from = 0;
    }
    if (from == f.bytes) return; // completo: a verificação decide
    final reply = await get(url, from);
    if (reply.status != 200 && reply.status != 206) throw HttpException('HTTP ${reply.status}');
    final append = reply.status == 206 && from > 0;
    var got = append ? from : 0;
    final sink = part.openWrite(mode: append ? FileMode.append : FileMode.write);
    try {
      await for (final chunk in reply.body.timeout(kDownloadIdle)) {
        got += chunk.length;
        if (got > f.bytes) throw const HttpException('Arquivo maior que o catálogo');
        sink.add(chunk);
      }
    } finally {
      await sink.close();
    }
  }
}
