/// O HTTP real do mapa: o POST da Overpass e o GET com retomada dos pacotes. Os dois são injetados em quem os usa.
library;

import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import '../world/fallback_service.dart' show HttpReply;
import 'feed_config.dart';

/// Resposta de um GET com retomada: 206 continua de onde parou, 200 recomeça do zero.
class RangeReply {
  const RangeReply(this.status, this.body);

  final int status;
  final Stream<List<int>> body;
}

typedef RangeGet = Future<RangeReply> Function(Uri url, int from);

Future<HttpReply> httpPostForm(Uri url, String body, {required String userAgent, required Duration timeout, required int maxBytes}) async {
  final client = HttpClient()
    ..connectionTimeout = kFeedTimeout
    ..userAgent = userAgent;
  Future<HttpReply> run() async {
    final req = await client.postUrl(url);
    req.headers.contentType = ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    req.write(body);
    final res = await req.close();
    final out = BytesBuilder(copy: false);
    await for (final chunk in res) {
      out.add(chunk);
      if (out.length > maxBytes) throw const HttpException('Resposta grande demais');
    }
    return HttpReply(res.statusCode, out.takeBytes());
  }

  try {
    return await run().timeout(timeout);
  } finally {
    client.close(force: true);
  }
}

Future<RangeReply> httpRangeGet(Uri url, int from) async {
  final client = HttpClient()
    ..connectionTimeout = kFeedTimeout
    ..autoUncompress = false; // os bytes exatos: a retomada e a assinatura contam com eles
  try {
    final req = await client.getUrl(url);
    req.headers.removeAll(HttpHeaders.acceptEncodingHeader);
    if (from > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$from-');
    final res = await req.close().timeout(kFeedTimeout);
    client.close(); // termina sozinho quando o corpo acabar
    return RangeReply(res.statusCode, res);
  } catch (_) {
    client.close(force: true);
    rethrow;
  }
}
