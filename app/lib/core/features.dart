/// Liga o que a "Rua viva" (Parte B, 0.14.0) mostra: névoa, Radar, clima no HUD e na chuva, Familiar companheiro e o bônus
/// de coleta dele. A 0.13.1 sai com isto desligado (`--dart-define=STREET_LIFE=false`); a 0.14.0 e os testes usam o padrão.
/// Não é flag de depuração: o menu de debug continua em todas as builds. A névoa continua sendo gravada com a flag
/// desligada, para a área andada já aparecer revelada quando ela ligar.
bool streetLifeEnabled = const bool.fromEnvironment(
  'STREET_LIFE',
  defaultValue: true,
);
