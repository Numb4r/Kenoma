-- Scale Mote (Fagulha da família Wyrm, arte final): uma escama solta de teú, escura, com a junta ainda acesa em volta
-- e uma trinca no meio. Quadros de 12x12 desenhados inteiros, pairando: repouso, desce 1 px, pico (a junta acende
-- inteira, a trinca abre e solta uma fagulha), volta.
-- A luz é a do tipo (tools/art/ui/types/palette.lua, Dracônico: R = d, J = m, H = l).
-- lit: aceso -> apagado (o aceso vai no glow, o apagado fica no corpo); loose: fagulha solta, só no glow.
-- Quem carrega: tools/art/sparks/build.lua.
return {
  leg = { A = '#1A1424', ['1'] = '#6A6670', ['2'] = '#4A4752', ['3'] = '#33313B', ['4'] = '#25232C',
    j = '#4E2438', h = '#643046', r = '#3A1A2C',
    R = '#8E2852', J = '#DE4F84', H = '#F797B6', N = '#8E2852', S = '#DE4F84', s = '#F797B6' },
  lit = { R = 'r', J = 'j', H = 'h' },
  loose = 'NSs',
  frames = {
    { '............', '....AAAA....', '...AJJJJA.S.', '..AJ1212JA..', '..AJ2H21RA..', '..AR32H3RA..', '..AR43H4RA..',
      '.s.AR34RA...', '....ARRA....', '.....AA.....', '............', '............' },
    { '............', '..........s.', '....AAAA....', '...AJJJJA...', '..AJ1212JA..', '..AJ2H21JA..', '..AJ32H3RA..',
      '..AR43H4RA..', '.S.AR34RA...', '....ARRA....', '.....AA.....', '............' },
    { '............', '............', '....AAAA....', '...AHJJHA.s.', '..AJ1H12JA..', '..AJ2H21JA..', '..AJ32H3JA..',
      '..AJ4HH4JA..', '.N.AJ3HJA...', '....AJJA....', '.....AA.S...', '............' },
    { '............', '....AAAA....', '...AJJJJA...', '..AJ1212JA..', '..AJ2H21JA..', '..AJ32H3RA..', '..AR43H4RA..',
      '...AR34RA.N.', '....ARRA....', '.....AA.....', '.........s..', '............' },
  },
}
