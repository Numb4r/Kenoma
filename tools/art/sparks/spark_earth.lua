-- Grit Mote (Fagulha da família Clod, arte final): uma placa de cascalho que se soltou da carapaça (seixos de brita,
-- ocre e caco de tijolo, com rejunte), com a junta ainda acesa na borda quebrada (o traço da família). Quadros de
-- 12x12 (pairando: sobe 1 px e volta; a luz da junta avança pela placa, abre uma trinca no pico e solta poeira).
-- A luz é só a do tipo (tools/art/ui/types/palette.lua, Terra: H = d, J = m, Y = l).
-- lit: aceso -> apagado (o aceso vai no glow, o apagado fica no corpo); loose: poeira solta, só no glow.
-- Quem carrega: tools/art/sparks/build.lua.
local REST = { '....AAAA....', '...A1123A...', '..A1a23p4A..', '..AJ2134qA..', '..AJY2b345A.', '..AHJY34t5A.', '...AHJJ45A..', '....AAAAA...' }
local LIT = { '....AAAA....', '...A1123A...', '..A1a23p4A..', '..AY2134qA..', '..AJYJb345A.', '..AJYY34t5A.', '...AJYJ45A..', '....AAAAA...' }
local PEAK = { '....AAAA....', '...A11J3A...', '..A1aJ3p4A..', '..AY2J34qA..', '..AYYJb345A.', '..AJYYJ4t5A.', '...AYYJ45A..', '....AAAAA...' }
-- a placa em top (linha de cima do contorno) e a poeira solta { linha, coluna, cor } por cima do vazio
local function frame(body, top, loose)
  local rows = {}
  for y = 0, 11 do rows[y + 1] = body[y - top + 1] or '............' end
  for _, q in ipairs(loose) do
    local r = rows[q[1] + 1]
    assert(r:sub(q[2] + 1, q[2] + 1) == '.', 'spark_earth: poeira em cima da placa')
    rows[q[1] + 1] = r:sub(1, q[2]) .. q[3] .. r:sub(q[2] + 2)
  end
  return rows
end
return {
  leg = { A = '#1A1424', ['1'] = '#B9B1A0', ['2'] = '#918A7B', ['3'] = '#6C675D', ['4'] = '#4B4843', ['5'] = '#32302F',
    a = '#B39062', b = '#8B6C45', p = '#9C614B', q = '#74412F', t = '#4D2B23',
    j = '#4F3F2B', y = '#5F4D33', h = '#3F2E22', J = '#C0915A', Y = '#E6C594', H = '#7E5A32', S = '#C0915A', s = '#E6C594' },
  lit = { J = 'j', Y = 'y', H = 'h' },
  loose = 'Ss',
  frames = {
    frame(REST, 2, { { 5, 11, 'S' }, { 9, 10, 's' }, { 10, 2, 'S' }, { 10, 6, 'S' } }),
    frame(LIT, 1, { { 3, 11, 's' }, { 9, 9, 'S' }, { 10, 3, 'S' }, { 9, 5, 's' } }),
    frame(PEAK, 1, { { 2, 10, 'S' }, { 1, 10, 's' }, { 9, 8, 's' }, { 10, 4, 'S' }, { 9, 2, 'S' }, { 10, 7, 's' } }),
    frame(LIT, 2, { { 4, 11, 'S' }, { 10, 9, 's' }, { 10, 3, 'S' }, { 11, 6, 'S' } }),
  },
}
