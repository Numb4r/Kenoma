import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kenoma/net/ed25519.dart';

List<int> h(String s) => hexToBytes(s)!;

void main() {
  // RFC 8032, seção 7.1 (TEST 1 e TEST 2).
  const pk1 = 'd75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a';
  const sig1 = 'e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e065224901555fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b';
  const pk2 = '3d4017c3e843895a92b70aa74d1b7ebc9c982ccf2ec4968cc0cd55f12af4660c';
  const sig2 = '92a009a9f0d4cab8720e820b5f642540a2b27b5416503f8fb3762223ebdb69da085ac1e43e15996e458f3613d0f11d8c387b2eaeb4302aeeb00d291612bb0c00';

  test('vetores 1 e 2 do RFC 8032 passam', () {
    expect(ed25519Verify(publicKey: h(pk1), message: h(''), signature: h(sig1)), isTrue);
    expect(ed25519Verify(publicKey: h(pk2), message: h('72'), signature: h(sig2)), isTrue);
  });

  test('mensagem adulterada, assinatura adulterada e chave errada falham', () {
    expect(ed25519Verify(publicKey: h(pk2), message: h('73'), signature: h(sig2)), isFalse);
    final bad = h(sig2)..[10] ^= 1;
    expect(ed25519Verify(publicKey: h(pk2), message: h('72'), signature: bad), isFalse);
    expect(ed25519Verify(publicKey: h(pk1), message: h('72'), signature: h(sig2)), isFalse);
    expect(ed25519Verify(publicKey: h(pk2), message: h('72'), signature: h(sig2).sublist(0, 63)), isFalse);
    expect(ed25519Verify(publicKey: List.filled(32, 0xff), message: utf8.encode('x'), signature: List.filled(64, 0xff)), isFalse);
  });
}
