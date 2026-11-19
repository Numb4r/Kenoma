-- Seed Mote (Fagulha da família Frond, arte final): um lobo solto da fronde de Charnia, com o fio da nervura aceso
-- (o traço da família) e o toco do talo, caindo como semente alada. Quadros de 12x12 desenhados inteiros (pairando:
-- desce 1 px e volta; a luz sobe pela nervura até o pico, a ponta do lobo vira; um esporo solta).
-- A luz é a do tipo (tools/art/ui/types/palette.lua, Planta: B = d, D = m, E = l).
-- lit: aceso -> apagado (o aceso vai no glow, o apagado fica no corpo); loose: esporo solto, só no glow.
-- Quem carrega: tools/art/sparks/build.lua.
return {
  leg = { A = '#1A1424', a = '#2B3324', b = '#3D4A30', c = '#566440', d = '#748354', e = '#96A070', o = '#9A8262',
    r = '#22381F', u = '#2F4A2C', B = '#2B7A40', D = '#4DBD62', E = '#A2E8A0', T = '#2B7A40', S = '#4DBD62', s = '#A2E8A0' },
  lit = { B = 'r', D = 'u', E = 'u' },
  loose = 'TSs',
  frames = {
    { '............', '............', '......AAA...', '....AAedcA..', '...AeEdcbA..', '..AedDEcbA..', '..AdcbDEbAs.',
      '.AedcbBDcA..', '.AdcbaAoA...', '..AAAA.A....', '.......S....', '............' },
    { '............', '............', '.........s..', '......AAA...', '....AAedcA..', '...AeEdcbA..', '..AedEEcbA..',
      '..AdcbDEbA..', '.AedcbDDcA..', '.AdcbaAoA...', '..AAAA.A....', '............' },
    { '............', '............', '............', '.....AAA....', '....AedcA...', '...AeEEcbA..', '..AedEEdbA..',
      '..AdcbEEbA..', '.AedcbDEcA..', '.AdcbaAoA.S.', '..AAAA.A....', '............' },
    { '............', '............', '......AAA...', '....AAedcA..', '...AeEdcbA..', '..AedDEcbA..', '..AdcbDEbA..',
      '.AedcbDDcA..', '.AdcbaAoA...', '..AAAA.A....', '....T.......', '............' },
  },
}
