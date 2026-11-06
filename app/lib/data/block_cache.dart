/// Os blocos do fallback em disco: `<raiz>/e<época>/<tx>_<ty>.blk`. Escrita atômica, limite total (saem os mais antigos) e
/// leitura sem rede, caindo para a época anterior mais recente. Nunca lança.
library;

import 'dart:io';
import 'dart:typed_data';

class BlockCache {
  BlockCache(this.root, {required this.limitBytes});

  final Directory root;
  final int limitBytes;

  File _file(int epoch, int tx, int ty) => File('${root.path}/e$epoch/${tx}_$ty.blk');

  /// As épocas em disco até [epoch], da mais nova para a mais antiga.
  Future<List<int>> _epochsUpTo(int epoch) async {
    if (!await root.exists()) return const [];
    final out = <int>[];
    await for (final e in root.list()) {
      final name = e.path.split('/').last;
      final id = e is Directory && name.startsWith('e') ? int.tryParse(name.substring(1)) : null;
      if (id != null && id <= epoch) out.add(id);
    }
    return out..sort((a, b) => b - a);
  }

  /// Os bytes do bloco, época vigente primeiro. A cada candidato, [accept] decodifica; o que não abre é apagado.
  Future<T?> read<T>(int epoch, int tx, int ty, Future<T> Function(Uint8List bytes) accept) async {
    try {
      for (final e in await _epochsUpTo(epoch)) {
        final f = _file(e, tx, ty);
        if (!await f.exists()) continue;
        try {
          return await accept(await f.readAsBytes());
        } catch (_) {
          await f.delete(); // corrompido: nunca mais
        }
      }
    } catch (_) {
      // sem disco: como se não houvesse
    }
    return null;
  }

  Future<void> write(int epoch, int tx, int ty, Uint8List bytes) async {
    try {
      final f = _file(epoch, tx, ty);
      await f.parent.create(recursive: true);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(f.path);
      await _trim();
    } catch (_) {
      // sem disco: o bloco vale só nesta sessão
    }
  }

  Future<void> _trim() async {
    final files = <(File, FileStat)>[];
    await for (final e in root.list(recursive: true)) {
      if (e is File && e.path.endsWith('.blk')) files.add((e, await e.stat()));
    }
    var total = files.fold<int>(0, (sum, f) => sum + f.$2.size);
    files.sort((a, b) => a.$2.modified.compareTo(b.$2.modified));
    for (final (f, stat) in files) {
      if (total <= limitBytes) break;
      await f.delete();
      total -= stat.size;
    }
  }
}
