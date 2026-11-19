-- Chill Mote (Fagulha da família Wisp, arte final): um toco de vela com a chama fria, solto de qualquer olho de vela
-- (o traço da família). Quadros de 12x12 desenhados inteiros (pairando: desce 1 px e volta; a chama inclina, cresce
-- até o pico e a cera derrete do lado da luz; um grão de frio sobe e some).
-- A luz é a do tipo (tools/art/ui/types/palette.lua, Espectral: B = d, D = m, E = l). A cera é matéria (corpo).
-- lit: aceso -> apagado (o aceso vai no glow, o apagado fica no corpo); loose: frio solto, só no glow.
-- Quem carrega: tools/art/sparks/build.lua.
return {
  leg = { A = '#1A1424', k = '#2B2836', ['1'] = '#8C8676', ['2'] = '#B5AD98', ['3'] = '#D9D2BE',
    x = '#34435E', y = '#4C6182', z = '#6A82A4', B = '#8A9DBA', D = '#D3E2F4', E = '#F2F7FF',
    T = '#8A9DBA', S = '#D3E2F4', s = '#F2F7FF' },
  lit = { B = 'x', D = 'y', E = 'z' },
  loose = 'TSs',
  frames = {
    { '............', '......B.....', '.....BD.....', '.....DEB....', '....BDED....', '.....BDB.S..', '....AAkAA...',
      '...A32321A..', '..A3231212A.', '..AAAAAAAAA.', '............', '............' },
    { '............', '............', '.......B....', '......BD....', '.....DEDB.s.', '....BDED....', '.....BDB....',
      '....AAkAA...', '...A32321A..', '..A3231212A.', '..AAAAAAAAA.', '............' },
    { '............', '......B.....', '......D...T.', '.....DED....', '....BEEDB...', '....DEED....', '.....DED....',
      '....AAkAA...', '...A33321A..', '..A3331212A.', '..AAAAAAAAA.', '............' },
    { '............', '.....B......', '.....DB.....', '....BDED....', '....BDED....', '.....BDB....', '....AAkAA...',
      '...A32321A..', '..A3231212A.', '..AAAAAAAAA.', '.S..........', '............' },
  },
}
