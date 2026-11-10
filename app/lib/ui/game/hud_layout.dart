/// As zonas fixas do HUD do mapa (docs/GDD.md, "Interface" e "Câmera"): onde cada peça mora, em dp, para um tamanho de
/// tela e o que está ligado. Dart puro: os widgets e o rastreador do Flame desenham dentro destes retângulos, e o teste de
/// layout confere que nenhum cobre outro.
///
/// - **Topo:** a barra (hora, lua, clima, selo de modo).
/// - **Abaixo da barra:** marcações à esquerda, avisos no meio, bússola à direita (só fora do norte).
/// - **Embaixo:** retrato à esquerda, celular no centro, rastreador à direita com o atalho do Radar acima.
/// - **Atalhos temporários:** a faixa logo acima do celular (Patrulha ativa, viagem em andamento).
/// - **Simulador:** o joystick à esquerda, acima da faixa.
/// - **Céu:** a faixa logo abaixo dos avisos, entre a coluna das marcações e a da bússola: a lua e a segunda lua da Lua
///   Dupla, à direita, e o Sol Negro, à esquerda ([HudLayout.sky]). Ficam fora de todas as zonas, então nada do HUD as
///   cobre. O arco-íris não está aqui: ele é do mapa (`rainbow_painter.dart`) e fica por baixo do HUD, como os Ecos.
library;

import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

/// Medidas fixas do HUD, em dp.
abstract final class HudSize {
  static const double margin = 8;
  static const double bar = 48;
  static const double compass = 52;
  static const double side = 56; // largura das colunas da esquerda (retrato, marcações)
  static const double portraitH = 76; // retrato, nível e barra de XP
  static const double phone = 56;
  static const double strip = 48;
  static const double tracker = 48; // largura do rastreador e lado de cada entrada
  static const double trackerEntry = tracker + 14; // a entrada e a distância embaixo
  static const double radar = 48;
  static const double joystick = 120;
  static const double markH = 52;
  static const double markGap = 4;
  static const double noticeH = 72;
  static const double moon = 28;
  static const double moon2 = 20;
  static const double blackSun = 32;
}

class HudLayout {
  const HudLayout({
    required this.bar,
    required this.notice,
    required this.marks,
    required this.marksFit,
    required this.portrait,
    required this.phone,
    required this.tracker,
    this.compass,
    this.strip,
    this.radar,
    this.joystick,
    this.sky = const {},
  });

  final Rect bar;

  /// Avisos curtos (o toast e o estado do GPS quando não está seguindo).
  final Rect notice;

  /// A coluna das marcações, já do tamanho das que cabem; [marksFit] é quantas cabem.
  final Rect marks;
  final int marksFit;
  final Rect portrait;
  final Rect phone;

  /// O rastreador inteiro, com espaço para todas as entradas (`tracker_max`): cheio ou vazio, nada mais entra aqui.
  final Rect tracker;
  final Rect? compass;
  final Rect? strip;
  final Rect? radar;
  final Rect? joystick;

  /// Os elementos do céu desenhados na tela (`moon`, `moon2`, `black_sun`): a camada do clima desenha dentro deles.
  final Map<String, Rect> sky;

  /// Os retângulos presentes, por nome (o teste confere a sobreposição entre todos).
  Map<String, Rect> get all => {
        'bar': bar,
        'notice': notice,
        if (marksFit > 0 && marks.height > 0) 'marks': marks,
        'portrait': portrait,
        'phone': phone,
        'tracker': tracker,
        'compass': ?compass,
        'strip': ?strip,
        'radar': ?radar,
        'joystick': ?joystick,
      };
}

/// O HUD para a tela [screen] com as faixas seguras [top] e [bottom] (barra de status e de navegação do sistema).
/// [trackerMax]: quantas entradas o rastreador pode ter. [marks]: quantas marcações ativas. [shortcuts]: se há atalho
/// temporário. [compass], [radar], [simulator]: se a bússola, o atalho do Radar e o joystick aparecem.
HudLayout hudLayout(
  Size screen, {
  double top = 0,
  double bottom = 0,
  int trackerMax = 4,
  int marks = 0,
  bool shortcuts = false,
  bool compass = false,
  bool radar = false,
  bool simulator = false,
}) {
  const m = HudSize.margin;
  final w = screen.width;
  final bar = Rect.fromLTWH(m, top + m, w - 2 * m, HudSize.bar);
  final y0 = bar.bottom + m;
  final bottomY = screen.height - bottom - m;
  final sideRight = m + HudSize.side + m; // onde acaba a coluna da esquerda, com a folga
  final notice = Rect.fromLTRB(sideRight, y0, w - sideRight, y0 + HudSize.noticeH);
  final phone = Rect.fromLTWH(w / 2 - HudSize.phone / 2, bottomY - HudSize.phone, HudSize.phone, HudSize.phone);
  final portrait = Rect.fromLTWH(m, bottomY - HudSize.portraitH, HudSize.side, HudSize.portraitH);
  final tracker = Rect.fromLTWH(w - m - HudSize.tracker, bottomY - trackerMax * HudSize.trackerEntry, HudSize.tracker, trackerMax * HudSize.trackerEntry);
  final stripRect = Rect.fromLTRB(sideRight, phone.top - m - HudSize.strip, w - sideRight, phone.top - m);
  final joystick = simulator ? Rect.fromLTWH(m, stripRect.top - m - HudSize.joystick, HudSize.joystick, HudSize.joystick) : null;
  final marksBottom = (joystick?.top ?? math.min(portrait.top, stripRect.top)) - m;
  final fit = math.max(0, ((marksBottom - y0 + HudSize.markGap) / (HudSize.markH + HudSize.markGap)).floor());
  final shown = math.min(marks, fit);
  return HudLayout(
    bar: bar,
    notice: notice,
    marks: Rect.fromLTWH(m, y0, HudSize.side, math.max(0, shown * (HudSize.markH + HudSize.markGap) - HudSize.markGap)),
    marksFit: fit,
    portrait: portrait,
    phone: phone,
    tracker: tracker,
    compass: compass ? Rect.fromLTWH(w - m - HudSize.compass, y0, HudSize.compass, HudSize.compass) : null,
    strip: shortcuts ? stripRect : null,
    radar: radar ? Rect.fromLTWH(w - m - HudSize.radar, tracker.top - m - HudSize.radar, HudSize.radar, HudSize.radar) : null,
    joystick: joystick,
    sky: {
      'moon': Rect.fromLTWH(notice.right - HudSize.moon, notice.bottom + m, HudSize.moon, HudSize.moon),
      'moon2': Rect.fromLTWH(notice.right - HudSize.moon - m - HudSize.moon2, notice.bottom + m + HudSize.moon - HudSize.moon2, HudSize.moon2, HudSize.moon2),
      'black_sun': Rect.fromLTWH(notice.left, notice.bottom + m, HudSize.blackSun, HudSize.blackSun),
    },
  );
}
