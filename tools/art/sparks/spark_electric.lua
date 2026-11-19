-- Arc Mote (Fagulha da família Hum, arte final): um ocelo de LED arrancado da asa do Humoth, com o veio pendurado
-- soltando faísca. Quadros de 12x12 desenhados inteiros (pairando: desce 1 px e volta, o veio balança).
-- lit: aceso -> apagado (o aceso vai no glow, o apagado fica no corpo); loose: faísca solta, só no glow.
-- Quem carrega: tools/art/sparks/build.lua.
return {
  leg = { A = '#1A1424', E = '#7672B8', F = '#4D4A8A', G = '#34305E', P = '#28244A', h = '#17444C', i = '#245A62', j = '#6B5A44',
    H = '#5FD3C6', I = '#D9FFF6', J = '#FFD23A', Y = '#FFEE9A', S = '#FFD23A', s = '#FFEE9A' },
  lit = { H = 'h', I = 'i', J = 'j', Y = 'j' },
  loose = 'Ss',
  frames = {
    { '............', '.....AA.....', '....AEEA....', '...AEFFFA...', '..AEFHHGPA..', '..AFHIIHGA..', '..AFHIIHPA..',
      '..AGGHHPA...', '...AGJPA.S..', '....AJA.....', '.....S......', '............' },
    { '............', '............', '.....AA.....', '....AEEA....', '...AEFFFA...', '..AEFHHGPA..', '..AFHIIHGA..',
      '..AFHIIHPA..', '..AGGHHPA...', '...AGJPA....', '...AJAA..s..', '............' },
    { '............', '............', '.....AA.....', '....AEEA....', '...AEFFFA...', '..AEFIIGPA..', '..AFIIIIGA..',
      '..AFIIIIPA..', '..AGGIIPA...', '...AGYPA....', '.S..AYA..s..', '............' },
    { '............', '.....AA.....', '....AEEA....', '...AEFFFA...', '..AEFHHGPA..', '..AFHIIHGA..', '..AFHIIHPA..',
      '..AGGHHPA...', '...AGJPA....', '....AAJA....', '.......S....', '............' },
  },
}
