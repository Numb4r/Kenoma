-- Dusk Mote (Fagulha da família Shade, arte final): uma lasca de marquise e, presa nela, uma sombra que não é a dela:
-- um pedaço de asa com um olho. Quadros de 12x12 desenhados inteiros. O traço da família em 12 px: a lasca paira
-- (desce 1 px e volta) e a sombra NÃO vai junto: fica onde está, a lasca afunda nela, e é o olho que se mexe (olha
-- para o lado, arregala no pico, quando a borda acende).
-- A luz é a do tipo (tools/art/ui/types/palette.lua, Sombra: R = d, P = m, E = l).
-- lit: aceso -> apagado (o aceso vai no glow, o apagado fica no corpo); loose: poeira solta, só no glow.
-- Quem carrega: tools/art/sparks/build.lua.
return {
  leg = { A = '#1A1424', ['1'] = '#45454E', ['2'] = '#63636B', ['3'] = '#87868A', ['4'] = '#ACA9A4', r = '#7A4630',
    e = '#231E33', f = '#2F2942', x = '#3A2A44', y = '#4C3A56', z = '#5E4A68',
    R = '#68426E', P = '#A677AB', E = '#D2ABD6', K = '#68426E', S = '#A677AB', s = '#D2ABD6' },
  lit = { R = 'x', P = 'y', E = 'z' },
  loose = 'KSs',
  frames = {
    { '............', '............', '.....AAAAA..', '..S.A4343rA.', '....A12312A.', '...AeRfefAA.', '..AfREPfefA.',
      '..AeRfRefeA.', '.AeRfeAfReA.', '.AfRfA.AeRA.', '.AAAA.K.AA..', '............' },
    { '............', '............', '..s.........', '.....AAAAA..', '....A4343rA.', '...AA12312A.', '..AfRfEPefA.',
      '..AeRfRefeA.', '.AeRfeAfReA.', '.AfRfA.AeRA.', '.AAAA...AA..', '............' },
    { '............', '............', '............', '.s...AAAAA..', '....A4343rA.', '...AA12312A.', '..AfPEEfefA.',
      '..AePfPefeA.', '.AePfeAfPeA.', '.AfPfA.AePA.', '.AAAA.S.AA..', '............' },
    { '............', '............', '.....AAAAA..', '....A4343rA.', '....A12312A.', '...AeRfefAA.', '..AfRfEPefA.',
      '..AeRfRefeA.', '.AeRfeAfReA.', '.AfRfA.AeRA.', '.AAAA.s.AA..', '............' },
  },
}
