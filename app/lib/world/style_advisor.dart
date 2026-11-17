/// 0.22.0 (GDD, Câmera): se o estilo Completo passar de [limitMs] por quadro em média durante [windowS] segundos seguidos,
/// o jogo sugere UMA vez trocar para o Simplificado (nunca troca sozinho). Mede o intervalo entre quadros; um intervalo
/// acima de 0,25 s (app em segundo plano, pausa) é ignorado e recomeça a janela. Dart puro.
library;

class StyleAdvisor {
  StyleAdvisor({this.limitMs = 20, this.windowS = 60, this.alreadySuggested = false});

  final double limitMs;
  final double windowS;

  /// A sugestão já saiu (guardada nos Ajustes): nunca mais sai.
  bool alreadySuggested;

  double _sumS = 0;
  int _frames = 0;

  /// A média da última janela inteira, em ms (debug).
  double lastAverageMs = 0;

  /// Soma um quadro de [dtS] segundos. `true` uma única vez: quando uma janela inteira fechou com média acima do limite.
  bool add(double dtS) {
    if (alreadySuggested) return false;
    if (dtS <= 0 || dtS > 0.25) {
      reset();
      return false;
    }
    _sumS += dtS;
    _frames++;
    if (_sumS < windowS) return false;
    lastAverageMs = _sumS / _frames * 1000;
    final slow = lastAverageMs > limitMs;
    reset();
    if (!slow) return false;
    alreadySuggested = true;
    return true;
  }

  /// Recomeça a janela (troca de estilo, pausa).
  void reset() {
    _sumS = 0;
    _frames = 0;
  }
}

/// Ajustes: o mapa no estilo Simplificado (`true`) ou Completo (padrão), e se a sugestão de trocar já saiu.
const String kSimpleGraphicsSetting = 'map_simple';
const String kSimpleSuggestedSetting = 'map_simple_suggested';

/// 0.22.2 (GDD, Câmera): "Zoom ampliado", desligado por padrão. Ligado, a pinça abre até [kWideZoomMaxM].
const String kWideZoomSetting = 'zoom_wide';
const double kWideZoomMaxM = 250;

/// Acima desta largura de tela (m) o mapa passa sozinho para o Simplificado; volta ao Completo abaixo de [kAutoSimpleBackM]
/// (a folga evita trocar de estilo a cada movimento da pinça perto do limite).
const double kAutoSimpleM = 120, kAutoSimpleBackM = 112;

/// As ruas que somem de longe (a fina antes da avenida): acima de 120 m somem as trilhas, acima de 200 m as locais, acima
/// de 400 m as secundárias. Dart puro, com teste.
Set<String> hiddenRoadClasses(double widthM) => {
      if (widthM > 120) 'pedestrian',
      if (widthM > 200) 'local',
      if (widthM > 400) 'secondary',
    };

/// O estilo automático: com [simpleWanted] (Ajustes) ou no mapa de Rotas é sempre o Simplificado; senão o zoom decide,
/// com folga. [wasAuto]: se o último quadro já estava no Simplificado automático.
bool autoSimple({required double widthM, required bool wasAuto}) => wasAuto ? widthM > kAutoSimpleBackM : widthM > kAutoSimpleM;
