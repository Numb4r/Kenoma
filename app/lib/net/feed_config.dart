/// Configuração do feed assinado (épocas e eventos). Ver docs/assinatura.md.
library;

/// URL base do GitHub Pages do repositório Numb4r/Kenoma. Editável: o feed é `<base>epochs.json` e `<base>events.json`,
/// cada um com `<arquivo>.sig` ao lado (assinatura Ed25519 de 64 bytes em hex, 128 caracteres).
const String kFeedBaseUrl = 'https://numb4r.github.io/Kenoma/';

/// Chave pública Ed25519 (32 bytes em hex) de `~/.kenoma-signing/publicacao_ed25519.pem`.
/// Pública por natureza: a privada nunca entra no repositório. Para trocar a chave, veja "Rotação" em docs/assinatura.md.
const String kFeedPublicKeyHex = '56b32fe7af4341199ea6b922385739edb5def059905d238545e60ba6631dcf25';

/// Tempo máximo de cada pedido de rede do feed.
const Duration kFeedTimeout = Duration(seconds: 8);
