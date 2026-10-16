/// Feed assinado de épocas e eventos: consulta no máximo uma vez por dia, cache em disco e leitura sempre reverificada.
/// Tudo é opcional e silencioso: qualquer falha (rede, assinatura, JSON) cai no que o app já tem. Nunca lança para fora.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:path_provider/path_provider.dart';

import 'ed25519.dart';
import 'feed_config.dart';
import 'signed_epochs.dart';

typedef FeedFetch = Future<Uint8List?> Function(Uri url);

/// Confere [sigHex] (128 caracteres hex) sobre os bytes exatos de [data].
bool verifySigned(List<int> data, String sigHex, {String publicKeyHex = kFeedPublicKeyHex}) {
  final sig = hexToBytes(sigHex), key = hexToBytes(publicKeyHex);
  return sig != null && key != null && ed25519Verify(publicKey: key, message: data, signature: sig);
}

Future<Directory?> _feedDir() async {
  try {
    final d = Directory('${(await getApplicationDocumentsDirectory()).path}/feed');
    return await d.create(recursive: true);
  } catch (_) {
    return null;
  }
}

/// O JSON de [name] no cache de [dir], só se a assinatura ao lado conferir. `null` em qualquer problema.
Future<Map<String, dynamic>?> readVerifiedCache(Directory dir, String name, {String publicKeyHex = kFeedPublicKeyHex}) async {
  try {
    final data = File('${dir.path}/$name'), sig = File('${dir.path}/$name.sig');
    if (!await data.exists() || !await sig.exists()) return null;
    final bytes = await data.readAsBytes();
    if (!verifySigned(bytes, await sig.readAsString(), publicKeyHex: publicKeyHex)) return null;
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// O `epochs.json` que o app usa: o embutido fundido com o cache do feed (reverificado agora). Sem cache, é o embutido.
Future<Map<String, dynamic>> loadEpochsJson({AssetBundle? bundle, Directory? dir, String publicKeyHex = kFeedPublicKeyHex}) async {
  final assets = bundle ?? rootBundle;
  final bundled = jsonDecode(await assets.loadString('assets/data/epochs.json')) as Map<String, dynamic>;
  try {
    final d = dir ?? await _feedDir();
    if (d == null) return bundled;
    final signed = await readVerifiedCache(d, 'epochs.json', publicKeyHex: publicKeyHex);
    if (signed == null) return bundled;
    return mergeSignedJson(bundled, signed, hasPack: await _packChecker(assets, signed, bundled));
  } catch (_) {
    return bundled;
  }
}

/// Quais pacotes das épocas novas do feed existem nos assets do app.
Future<bool Function(String)> _packChecker(AssetBundle assets, Map<String, dynamic> signed, Map<String, dynamic> bundled) async {
  final known = {for (final e in bundled['epochs'] as List<dynamic>) (e as Map<String, dynamic>)['id'] as int};
  final have = <String>{};
  final files = {
    for (final e in signed['epochs'] as List<dynamic>)
      if (!known.contains((e as Map<String, dynamic>)['id'])) ...epochPackFiles(e),
  };
  for (final f in files) {
    try {
      await assets.load('assets/regions/$f');
      have.add(f);
    } catch (_) {}
  }
  return have.contains;
}

/// Os eventos do feed (cache reverificado). Vazia se não há cache, a assinatura falha ou o JSON é ruim.
/// Ainda não há sistema de eventos: só parse.
Future<List<Map<String, dynamic>>> loadSignedEvents({Directory? dir, String publicKeyHex = kFeedPublicKeyHex}) async {
  try {
    final d = dir ?? await _feedDir();
    if (d == null) return const [];
    final json = await readVerifiedCache(d, 'events.json', publicKeyHex: publicKeyHex);
    return [for (final e in (json?['events'] as List<dynamic>? ?? const [])) e as Map<String, dynamic>];
  } catch (_) {
    return const [];
  }
}

Future<Uint8List?> httpFetch(Uri url) async {
  final client = HttpClient()..connectionTimeout = kFeedTimeout;
  try {
    final res = await (await client.getUrl(url)).close().timeout(kFeedTimeout);
    if (res.statusCode != 200) return null;
    final out = BytesBuilder();
    await for (final chunk in res.timeout(kFeedTimeout)) {
      out.add(chunk);
      if (out.length > 4 * 1024 * 1024) return null;
    }
    return out.takeBytes();
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Uma tentativa por dia UTC (a data da última tentativa fica em `last_try.txt`, mesmo se falhar). Baixa `epochs.json` e
/// `events.json` com `.sig`; cada um só entra no cache se a assinatura bater (e, nas épocas, se a fusão com o embutido
/// for aceita). Devolve quantos arquivos novos foram aceitos.
Future<int> refreshSignedFeed({
  required int nowUtc,
  Directory? dir,
  FeedFetch fetch = httpFetch,
  String baseUrl = kFeedBaseUrl,
  String publicKeyHex = kFeedPublicKeyHex,
  AssetBundle? bundle,
}) async {
  try {
    final d = dir ?? await _feedDir();
    if (d == null) return 0;
    final today = DateTime.fromMillisecondsSinceEpoch(nowUtc * 1000, isUtc: true).toIso8601String().substring(0, 10);
    final stamp = File('${d.path}/last_try.txt');
    if (await stamp.exists() && (await stamp.readAsString()).trim() == today) return 0;
    await stamp.writeAsString(today, flush: true);
    final assets = bundle ?? rootBundle;
    final bundled = jsonDecode(await assets.loadString('assets/data/epochs.json')) as Map<String, dynamic>;
    var accepted = 0;
    for (final name in ['epochs.json', 'events.json']) {
      try {
        final data = await fetch(Uri.parse('$baseUrl$name'));
        final sig = await fetch(Uri.parse('$baseUrl$name.sig'));
        if (data == null || sig == null || !verifySigned(data, utf8.decode(sig), publicKeyHex: publicKeyHex)) continue;
        final json = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
        if (name == 'epochs.json') mergeSignedJson(bundled, json); // lança se alterar época publicada
        if (name == 'events.json' && json['events'] is! List) continue;
        // Os dois arquivos vão para temporários e só depois trocam de nome, um logo após o outro: a janela em que o dado e a
        // assinatura não combinam é de microssegundos (e, se a leitura cair nela, a verificação falha e vale o embutido).
        await File('${d.path}/$name.tmp').writeAsBytes(data, flush: true);
        await File('${d.path}/$name.sig.tmp').writeAsBytes(sig, flush: true);
        await File('${d.path}/$name.sig.tmp').rename('${d.path}/$name.sig');
        await File('${d.path}/$name.tmp').rename('${d.path}/$name');
        accepted++;
      } catch (_) {
        // este arquivo falhou: segue com o que há
      }
    }
    return accepted;
  } catch (_) {
    return 0;
  }
}
