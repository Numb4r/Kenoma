/// Os atalhos para os apps de corrida. Só atalho, sem conta nem recompensa. Dart puro.
library;

const String kUberPackage = 'com.ubercab';
const String k99Package = 'com.taxis99';

/// O deep link padrão da Uber (https://developer.uber.com/docs/deep-linking): abre o app com o embarque em "minha
/// localização" e o destino preenchido. Sem `client_id`: a página não o marca como obrigatório, e o jogo não tem conta lá.
String uberDeepLink({required double lat, required double lon, required String nickname}) {
  final q = <String>[
    'action=setPickup',
    'pickup=my_location',
    'dropoff%5Blatitude%5D=${lat.toStringAsFixed(6)}',
    'dropoff%5Blongitude%5D=${lon.toStringAsFixed(6)}',
    'dropoff%5Bnickname%5D=${Uri.encodeComponent(nickname)}',
  ];
  return 'uber://?${q.join('&')}';
}

/// O deep link da 99, para preencher depois de testar no aparelho. Com `null` o app abre pelo pacote e o endereço vai para
/// a área de transferência.
String? taxi99DeepLink({required double lat, required double lon, required String nickname}) => null;
