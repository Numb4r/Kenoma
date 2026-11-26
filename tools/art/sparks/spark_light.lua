-- Glint Mote (Fagulha da família Glare, arte final): um caco de vidro de vitrine, de corte reto e borda verde, com o
-- reflexo que pisca, maior que o caco (o traço da família: a estrela de quatro pontas). Quadros de 12x12 (pairando:
-- desce 1 px e volta; a estrela cresce até o pico e os braços passam do caco; no pico soltam as cores do prisma).
-- A luz é a do tipo (tools/art/ui/types/palette.lua, Luz: H = d, J = m, Y = l); o espectro (E rosa, F verde, D azul)
-- vai por cima, só solto: o Glare multicolor da arte final.
-- lit: aceso -> apagado (o aceso vai no glow, o apagado fica no corpo); loose: brilho solto, só no glow.
-- Quem carrega: tools/art/sparks/build.lua.
local REST = { '....AAA.....', '..AA1H2AA...', '.A112J23gA..', '.A2HJYJH3A..', '.A233J34GA..', '..A34H45A...', '...A455A....', '....AAA.....' }
local LIT = { '....AAA.....', '..AA1J2AA...', '.A112Y23gA..', '.A2JYYYJ3A..', '.A233Y34GA..', '..A34J45A...', '...A455A....', '....AAA.....' }
local PEAK = { '....AAA.....', '..AA1Y2AA...', '.A11JY2JgA..', '.A2YYYYY3A..', '.A2J3YJ4GA..', '..A34Y45A...', '...A455A....', '....AAA.....' }
-- o caco em top (linha de cima do contorno) e o brilho solto { linha, coluna, cor } por cima do vazio
local function frame(body, top, loose)
  local rows = {}
  for y = 0, 11 do rows[y + 1] = body[y - top + 1] or '............' end
  for _, q in ipairs(loose) do
    local r = rows[q[1] + 1]
    assert(r:sub(q[2] + 1, q[2] + 1) == '.', 'spark_light: brilho solto em cima do caco')
    rows[q[1] + 1] = r:sub(1, q[2]) .. q[3] .. r:sub(q[2] + 2)
  end
  return rows
end
return {
  leg = { A = '#1A1424', ['1'] = '#DCE6E8', ['2'] = '#A9BCC2', ['3'] = '#7C939C', ['4'] = '#586E7A', ['5'] = '#3C4E5C',
    g = '#6FA08E', G = '#4A7A6C', y = '#6A6650', j = '#5A5540', h = '#4A4230',
    Y = '#FFFBE6', J = '#FFF0B8', H = '#CDB468', S = '#FFF0B8', s = '#FFFBE6', E = '#F0A0A0', F = '#A8E0A0', D = '#8AB8F0' },
  lit = { Y = 'y', J = 'j', H = 'h' },
  loose = 'SsEFD',
  frames = {
    frame(REST, 1, { { 5, 0, 'S' }, { 5, 10, 'S' }, { 10, 5, 'S' } }),
    frame(LIT, 2, { { 1, 5, 'S' }, { 6, 0, 's' }, { 6, 10, 's' }, { 10, 5, 'S' }, { 2, 9, 'E' } }),
    frame(PEAK, 2, { { 0, 5, 'S' }, { 1, 5, 's' }, { 6, 0, 's' }, { 6, 10, 's' }, { 6, 11, 'S' }, { 10, 5, 's' }, { 11, 5, 'S' },
      { 2, 9, 'E' }, { 10, 2, 'F' }, { 10, 9, 'D' } }),
    frame(LIT, 1, { { 0, 5, 'S' }, { 5, 0, 's' }, { 5, 10, 's' }, { 9, 5, 'S' }, { 9, 9, 'D' } }),
  },
}
