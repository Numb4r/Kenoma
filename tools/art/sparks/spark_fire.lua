-- Ember Mote (Fagulha da família Soot, arte final): um tufo de pelo de fuligem arrancado do peito do Sootling, com a
-- brasa dentro (o traço da família) e um resto de bituca espetado. Quadros de 12x12 desenhados inteiros (pairando:
-- desce 1 px e volta; a brasa cresce até o pico e as rachaduras abrem no pelo; uma faísca sobe).
-- A luz é a do tipo (tools/art/ui/types/palette.lua, Fogo: R = d, E = m, Y = l), sem o laranja da Essência.
-- lit: aceso -> apagado (o aceso vai no glow, o apagado fica no corpo); loose: faísca solta, só no glow.
-- Quem carrega: tools/art/sparks/build.lua.
return {
  leg = { A = '#1A1424', a = '#2A2529', b = '#3B3539', c = '#514B4E', d = '#6E6866', h = '#A39C90', H = '#CFC8BA',
    r = '#4A1F1A', u = '#6E2E1E', R = '#A82E1C', E = '#F0502E', Y = '#FF9C7A', T = '#A82E1C', S = '#F0502E', s = '#FF9C7A' },
  lit = { R = 'r', E = 'r', Y = 'u' },
  loose = 'TSs',
  frames = {
    { '............', '...AA.A.....', '..AdcAbA....', '.AdcbEbaA...', '.AcbEYEbA...', '.AbEYYYEaA..', '.AbaEYEbaA..',
      '..AabRbHhA..', '...AaabhA...', '....AAAA....', '..........s.', '............' },
    { '............', '......s.....', '...AA.A.....', '..AdcAbA....', '.AdcbEbaA...', '.AcEYYEbA...', '.AbEYYYEaA..',
      '.AbaEYEEaA..', '..AabRbHhA..', '...AaabhA...', '....AAAA....', '............' },
    { '............', '.........S..', '...AA.A.....', '..AdcAbA....', '.AdEbYbaA...', '.AcEYYYEA...', '.AREYYYYEA..',
      '.AbaYYEEaA..', '..AaRERHhA..', '...AaabhA...', '....AAAA....', '............' },
    { '............', '...AA.A.....', '..AdcAbA....', '.AdcbEbaA...', '.AcEYYEbA...', '.AbEYYYEaA..', '.AbaEYEEaA..',
      '..AabRbHhA..', '...AaabhA...', '....AAAA....', '.T..........', '............' },
  },
}
