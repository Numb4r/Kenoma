/// Permissão de localização: o fluxo de pedir com uma explicação curta antes do diálogo do sistema.
/// Dart puro: o geolocator entra só pela [LocationGateway], que o teste troca por uma de mentira.
library;

enum LocationPermissionState { granted, denied, deniedForever }

/// O que o app precisa do sistema para saber a localização.
abstract class LocationGateway {
  /// Se o serviço de localização (GPS) do aparelho está ligado.
  Future<bool> serviceEnabled();

  Future<LocationPermissionState> check();

  /// Abre o diálogo do sistema.
  Future<LocationPermissionState> request();

  Future<void> openAppSettings();
  Future<void> openLocationSettings();
}

enum LocationAccess {
  /// Pode usar a localização.
  granted,

  /// O GPS do aparelho está desligado.
  serviceOff,

  /// O jogador não quis conceder (ou fechou a explicação). Dá para pedir de novo.
  denied,

  /// Negada para sempre: só nos ajustes do aparelho.
  deniedForever,
}

/// Mensagem curta que a tela mostra para cada caso, em português.
String locationAccessMessage(LocationAccess a) => switch (a) {
      LocationAccess.granted => '',
      LocationAccess.serviceOff => 'O GPS do aparelho está desligado. Ligue a localização para ver onde você está no mapa.',
      LocationAccess.denied => 'Sem a localização o marcador não anda. Toque em tentar de novo para conceder.',
      LocationAccess.deniedForever => 'A localização está bloqueada para o Kenoma. Libere nos ajustes do aparelho.',
    };

/// A explicação mostrada antes do diálogo do sistema.
const String kLocationRationale =
    'O Kenoma usa a sua localização, só com o app aberto, para mostrar onde você está no mapa e o que há ao seu redor.';

class LocationAccessFlow {
  LocationAccessFlow(this.gateway);

  final LocationGateway gateway;

  /// Garante o acesso. Pede a permissão só se ainda não tem e só depois de [explain] devolver `true`
  /// (o "Continuar" da explicação). [explain] não é chamado se não há o que pedir.
  Future<LocationAccess> ensure({required Future<bool> Function() explain}) async {
    if (!await gateway.serviceEnabled()) return LocationAccess.serviceOff;
    var state = await gateway.check();
    if (state == LocationPermissionState.denied) {
      if (!await explain()) return LocationAccess.denied;
      state = await gateway.request();
    }
    return switch (state) {
      LocationPermissionState.granted => LocationAccess.granted,
      LocationPermissionState.denied => LocationAccess.denied,
      LocationPermissionState.deniedForever => LocationAccess.deniedForever,
    };
  }
}
