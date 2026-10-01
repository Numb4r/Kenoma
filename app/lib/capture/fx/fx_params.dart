/// Tempos e tamanhos dos efeitos visuais da sintonia. Só visual: não mexem no sinal nem no
/// `balance.json`. Os instantes de cada efeito saem do que o sinal já expõe (avisos, picos, maré,
/// fator de tolerância).
library;

/// Fogo: a brasa acende no aviso (`warning_lead_s` antes do pico), a chama queima o trecho por
/// [fireBurnS] e a onda reaparece das cinzas ao longo de [fireRegrowS].
const double fireBurnS = 0.25;
const double fireRegrowS = 0.4;
const int fireAshCount = 7;

/// Meia largura do trecho queimado, em fração da largura da onda, entre intensidade 0 e 1.
const (double, double) fireBurnHalfWidth = (0.04, 0.09);

/// Altura da chama em unidades da amplitude da onda, entre intensidade 0 e 1.
const (double, double) fireFlameHeight = (0.45, 1.1);

/// Água: a espuma assenta em [waterFoamS] depois do aviso de virada.
const double waterFoamS = 0.5;
const int waterFoamCount = 10;

/// Planta: a folha cresce por [plantLeafGrowS] depois de nascer e há no máximo [plantMaxLeaves].
const double plantLeafGrowS = 0.4;
const int plantMaxLeaves = 24;
const int plantMaxBranches = 6;

/// Dial: transição de cor, espessura e brilho ao alinhar.
const double dialBlendS = 0.15;
const double dialAlignedThickness = 1.8;
const double dialParticlesPerS = 28;
const double dialParticleLifeS = 0.55;
const int dialParticleCap = 24;
