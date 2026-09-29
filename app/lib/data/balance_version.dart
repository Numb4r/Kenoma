import 'package:crypto/crypto.dart';

/// Versão do balanceamento: os 8 primeiros caracteres hexadecimais do SHA-256 dos bytes do
/// `balance.json` carregado. Qualquer mudança no arquivo muda a versão, então cada linha do registro
/// de sessões diz com que balanceamento foi jogada.
String balanceVersionOf(List<int> balanceJsonBytes) => sha256.convert(balanceJsonBytes).toString().substring(0, 8);
