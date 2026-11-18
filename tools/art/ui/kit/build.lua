-- Kenoma 0.26.0: o kit do HUD do mapa e do celular no estilo da Bolsa (molduras em nove partes e peças fixas) e a folha.
-- Fonte única: as linhas de pixels deste arquivo. Mesmo formato de tools/art/ui/build_ui.lua, que este não edita.
-- Rodar no Aseprite em lote: aseprite -b --script tools/art/ui/kit/build.lua
-- Regras: docs/art/estilo-ui.md e tools/art/ui/kit/estilo-ui-adendo.md.
local BASE = '/home/yuri/Documentos/kenoma/tools/art/ui/kit/'
local OUT = BASE .. 'out/'
app.fs.makeAllDirectories(OUT)
local pc = app.pixelColor
local problems = {}

local function hex(h)
  return pc.rgba(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), 255)
end
-- Os tokens de app/lib/ui/tema.dart, mais os tons da Essência (1, 3) e os neutros de tingir (7, 8, 9).
local UI = {
  O = '1a1424', D = '120e1a', P = '1e1830', B = '2a2240', L = '3d3357', H = '56507a',
  V = '9b7bff', U = 'c9b8ff', S = '5fd3c6', t = '2e8f86', Z = 'ff7a45', W = 'ece6ff',
  ['1'] = 'ffb08a', ['2'] = 'ff7a45', ['3'] = 'c2542a', ['7'] = 'ffffff', ['8'] = 'd6d2de', ['9'] = '9c98a8',
}

local function grid(rows, name, pal)
  pal = pal or UI
  local w = #rows[1]
  local s = { w = w, h = #rows, px = {} }
  for y, row in ipairs(rows) do
    if #row ~= w then problems[#problems + 1] = name .. ': linha ' .. y .. ' com ' .. #row .. ' px, esperado ' .. w end
    for x = 1, math.min(#row, w) do
      local ch = row:sub(x, x)
      if ch ~= '.' then
        if not pal[ch] then problems[#problems + 1] = name .. ': sem cor para ' .. ch else s.px[(y - 1) * w + (x - 1)] = hex(pal[ch]) end
      end
    end
  end
  return s
end
local function toImage(s, scale)
  scale = scale or 1
  local img = Image(s.w * scale, s.h * scale)
  img:clear()
  for i, c in pairs(s.px) do
    local x, y = i % s.w, i // s.w
    for dy = 0, scale - 1 do for dx = 0, scale - 1 do img:drawPixel(x * scale + dx, y * scale + dy, c) end end
  end
  return img
end
local function save(s, name, scale)
  local spr = Sprite(s.w, s.h)
  spr:newCel(spr.layers[1], 1, toImage(s), Point(0, 0))
  spr:saveAs(BASE .. name .. '.aseprite')
  if scale then
    local big = Sprite(s.w * scale, s.h * scale)
    big:newCel(big.layers[1], 1, toImage(s, scale), Point(0, 0))
    big:saveCopyAs(OUT .. name .. '.png')
    big:close()
  else
    spr:saveCopyAs(OUT .. name .. '.png')
  end
  spr:close()
end
local function rep(row, n) local r = {} for i = 1, n do r[i] = row end return r end
local function cat(...) local r = {} for _, t in ipairs({ ... }) do for _, row in ipairs(t) do r[#r + 1] = row end end return r end

-- ---------------------------------------------------------------- molduras em nove partes
-- slice = {esquerda, topo, direita, baixo}. A conferência: até 12 x 12, miolo de 2 x 2 ou mais, e nada que não seja
-- liso na direção em que estica (as linhas do meio iguais entre si, as colunas do meio iguais entre si).
-- fixedH: a moldura só estica na horizontal (a altura de uso é a da imagem), então as linhas não se conferem.
local frames, frameOrder = {}, {}
local function frame(name, slice, rows, fixedH)
  local s = grid(rows, name)
  frames[name] = { s = s, slice = slice }
  frameOrder[#frameOrder + 1] = name
  local l, t, r, b = slice[1], slice[2], slice[3], slice[4]
  if s.w > 12 or s.h > 12 then problems[#problems + 1] = name .. ': maior que 12 x 12' end
  if s.w - l - r < 2 or s.h - t - b < 2 then problems[#problems + 1] = name .. ': miolo menor que 2 x 2' end
  for y = t, s.h - b - 1 do
    for x = 0, s.w - 1 do
      if not fixedH and s.px[y * s.w + x] ~= s.px[t * s.w + x] then problems[#problems + 1] = name .. ': linha ' .. y .. ' estica e não é lisa' break end
    end
  end
  for x = l, s.w - r - 1 do
    for y = 0, s.h - 1 do
      if s.px[y * s.w + x] ~= s.px[y * s.w + l] then problems[#problems + 1] = name .. ': coluna ' .. x .. ' estica e não é lisa' break end
    end
  end
  save(s, name)
end

-- HUD: a barra do topo. Placa escura (o mapa por baixo é claro), realce em cima.
frame('hud_bar', { 2, 2, 2, 2 }, cat({ '.OOOOOO.', 'OHHHHHHO' }, rep('OLDDDDDO', 5), { '.OOOOOO.' }))
-- Atalho temporário: botão de canto chanfrado em 2 px. Normal e apertado somam 5 px de borda vertical, como o `button`.
frame('shortcut_chip', { 2, 2, 2, 3 }, cat({ '..OOOOOOOO..', '.OHHHHHHHHO.' }, rep('OHLLLLLLLLLO', 6), { 'OBBBBBBBBBBO', '.OBBBBBBBBO.', '..OOOOOOOO..' }))
frame('shortcut_chip_pressed', { 2, 4, 2, 1 }, cat({ '............', '............', '..OOOOOOOO..', '.ODDDDDDDDO.' }, rep('ODBBBBBBBBBO', 6), { '.OOOOOOOOOO.' }))
-- Aviso: faixas diagonais de 2 px de Essência nas duas pontas, miolo liso. Altura fixa de 8 px.
frame('warn_tag', { 5, 2, 5, 2 }, {
  '.OOOOOOOOOO.',
  'OOOZZBBZZOOO',
  'OOZZOBBZOOZO',
  'OZZOOBBOOZZO',
  'OZOOZBBOZZOO',
  'OOOZZBBZZOOO',
  'OOZZOBBZOOZO',
  '.OOOOOOOOOO.',
}, true)
-- Celular: o aparelho (corpo em relevo, tela rebaixada), o lugar do ícone e o mesmo com o aro de novidade.
frame('phone_body', { 4, 4, 4, 4 }, cat(
  { '..OOOOOOOO..', '.OHHHHHHHHO.', 'OHBBBBBBBBBO', 'OHBOOOOOOBPO' }, rep('OLBODDDDOBPO', 4),
  { 'OLBOOOOOOBPO', 'OLBBBBBBBBPO', '.OPPPPPPPPO.', '..OOOOOOOO..' }))
frame('app_tile', { 3, 3, 3, 3 }, cat({ '.OOOOOOOO.', 'ODDDDDDDDL' }, rep('ODPPPPPPPL', 7), { '.LLLLLLLL.' }))
frame('app_tile_new', { 3, 3, 3, 3 }, cat({ '.ZZZZZZZZ.', 'ZOOOOOOOOZ', 'ZODDDDDDOZ' }, rep('ZODPPPPPOZ', 5), { 'ZOOOOOOOOZ', '.ZZZZZZZZ.' }))
-- Componentes. Diálogo: o `panel` com a faixa de título de 6 px (18 dp) dentro da borda de cima.
frame('dialog', { 2, 8, 2, 2 }, cat(
  { '.OOOOOOOOOO.', 'OHHHHHHHHHHO' }, rep('OHBBBBBBBBBO', 5), { 'OOOOOOOOOOOO', 'OLPPPPPPPPDO', 'OLPPPPPPPPDO', 'OLDDDDDDDDDO', '.OOOOOOOOOO.' }))
frame('card', { 2, 2, 2, 2 }, cat({ '..OOOOOOOO..', '.OHHHHHHHHO.' }, rep('OLBBBBBBBBPO', 8), { '.OPPPPPPPPO.', '..OOOOOOOO..' }))
frame('card_selected', { 2, 2, 2, 2 }, cat({ '..VVVVVVVV..', '.VOOOOOOOOV.' }, rep('VOBBBBBBBBOV', 8), { '.VOOOOOOOOV.', '..VVVVVVVV..' }))
frame('chip_cond', { 2, 2, 2, 2 }, { '.OOOOOO.', 'OLLLLLLO', 'OLDDDDBO', 'OLDDDDBO', 'OLDDDDBO', 'OBBBBBBO', '.OOOOOO.' })
do
  local f = assert(io.open(OUT .. 'slices.json', 'w'))
  f:write('{\n')
  for i, name in ipairs(frameOrder) do
    f:write('  "' .. name .. '": [' .. table.concat(frames[name].slice, ', ') .. ']' .. (i < #frameOrder and ',' or '') .. '\n')
  end
  f:write('}\n')
  f:close()
end

-- ---------------------------------------------------------------- peças fixas
local pieces = {}
local function piece(name, rows)
  pieces[name] = type(rows[1]) == 'string' and grid(rows, name) or rows
  save(pieces[name], name)
end

-- Retrato, 20 x 27: janela de 16 x 16 em (2, 2), placa do nível 16 x 4 em (2, 19), trilho do XP 18 x 2 em (1, 24).
piece('hud_portrait', cat(
  { '.OOOOOOOOOOOOOOOOOO.', 'OHHHHHHHHHHHHHHHHHHO' }, rep('OLDDDDDDDDDDDDDDDDBO', 16),
  { 'OOOOOOOOOOOOOOOOOOOO' }, rep('OLPPPPPPPPPPPPPPPPBO', 4),
  { 'OOOOOOOOOOOOOOOOOOOO', 'ODDDDDDDDDDDDDDDDDDO', 'ODDDDDDDDDDDDDDDDDDO', '.OOOOOOOOOOOOOOOOOO.' }))
-- Enchimento do XP, 1 x 2: o código repete na horizontal, em pixels inteiros. Violeta: o progresso é do jogador.
piece('xp_fill', { 'U', 'V' })

-- Botão do celular, 18 x 19, normal e apertado no mesmo quadro (a face desce 2 px e a lateral some).
local PHONE = { '.OOOOOO.', 'OPPPPPPO', 'ODDDDDDO', 'ODHDDDDO', 'ODDHDDDO', 'ODDDDDDO', 'ODDDDDDO', 'ODDDDDDO', 'OPPPPPPO', 'OPPHHPPO', 'OPPPPPPO', '.OOOOOO.' }
local function phoneButton(pressed)
  local edge, face = pressed and 'D' or 'H', pressed and 'B' or 'L'
  local plain = 'O' .. edge .. face:rep(15) .. 'O'
  local rows = pressed and { ('.'):rep(18), ('.'):rep(18), '.OOOOOOOOOOOOOOOO.', 'O' .. ('D'):rep(16) .. 'O' } or { '.OOOOOOOOOOOOOOOO.', 'O' .. ('H'):rep(16) .. 'O' }
  rows[#rows + 1] = plain
  for _, p in ipairs(PHONE) do rows[#rows + 1] = 'O' .. edge .. face:rep(3) .. p:gsub('%.', face) .. face:rep(4) .. 'O' end
  rows[#rows + 1] = plain
  if not pressed then rows[#rows + 1] = 'O' .. ('B'):rep(16) .. 'O' rows[#rows + 1] = 'O' .. ('B'):rep(16) .. 'O' end
  rows[#rows + 1] = '.OOOOOOOOOOOOOOOO.'
  return rows
end
piece('phone_button', phoneButton(false))
piece('phone_button_pressed', phoneButton(true))

-- Bolinha de novidade, 4 x 4, no desenho dos pontos de qualidade (contorno só nos cantos).
piece('badge_dot', { 'O12O', '1222', '2223', 'O23O' })
-- Ponto do chip de condição, 3 x 3, neutro: o código tinge multiplicando.
piece('cond_dot', { 'O7O', '789', 'O9O' })
-- Marca do Radar na borda, 10 x 10, para cima. Cor lisa, sem luz: o código gira em 90° e a luz giraria junto.
piece('edge_mark', {
  '....OO....',
  '...OSSO...',
  '..OSSSSO..',
  '.OSSSSSSO.',
  'OSSSSSSSSO',
  'OOOSSSSOOO',
  '..OSSSSO..',
  '..OSSSSO..',
  '..OSSSSO..',
  '..OOOOOO..',
})
-- Agulha da bússola, 6 x 12, para cima: o norte claro, o sul apagado. O código gira em torno do centro do quadro.
piece('compass_needle', {
  '..OO..', '.OWWO.', '.OWWO.', 'OWWWWO', 'OWWWWO', 'OWWWWO',
  'OHHHHO', 'OHHHHO', 'OHHHHO', '.OHHO.', '.OHHO.', '..OO..',
})
-- Interruptor, 14 x 8: desligado com o botão à esquerda e o trilho vazio; ligado com o botão à direita e o trilho violeta.
piece('switch_off', cat({ '.OOOOOOOOOOOO.', 'OHHHHHODDDDDDO' }, rep('OHLLLLODDDDDDO', 4), { 'OBBBBBODDDDDDO', '.OOOOOOOOOOOO.' }))
piece('switch_on', cat({ '.OOOOOOOOOOOO.', 'OUUUUUUOHHHHHO' }, rep('OVVVVVVOHLLLLO', 4), { 'OVVVVVVOBBBBBO', '.OOOOOOOOOOOO.' }))
-- Fundo da tela inicial, 8 x 8, repete: dois pontos de 1 px um tom acima do fundo.
piece('phone_wall', { 'DDDDDDDD', 'DPDDDDDD', 'DDDDDDDD', 'DDDDDDDD', 'DDDDDDDD', 'DDDDDPDD', 'DDDDDDDD', 'DDDDDDDD' })

-- Disco de 18 px (o recuo de cada linha) em camadas de 1 px de fora para dentro: 1 contorno, 2 e 3 anel, 4 contorno, 5 miolo.
local OFF = { 6, 4, 3, 2, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 2, 3, 4, 6 }
local layer = {}
do
  local function inside(x, y) return y >= 0 and y < 18 and x >= OFF[y + 1] and x < 18 - OFF[y + 1] end
  local function near(x, y, test)
    return test(x - 1, y) or test(x + 1, y) or test(x, y - 1) or test(x, y + 1)
  end
  for n = 1, 4 do
    local add = {}
    for y = 0, 17 do for x = 0, 17 do
      if inside(x, y) and not layer[y * 18 + x] then
        local hit = n == 1 and near(x, y, function(a, b) return not inside(a, b) end) or n > 1 and near(x, y, function(a, b) return layer[b * 18 + a] == n - 1 end)
        if hit then add[#add + 1] = y * 18 + x end
      end
    end end
    for _, i in ipairs(add) do layer[i] = n end
  end
  for y = 0, 17 do for x = 0, 17 do if inside(x, y) and not layer[y * 18 + x] then layer[y * 18 + x] = 5 end end end
end
local function disc(color)
  local s = { w = 18, h = 18, px = {} }
  for i, n in pairs(layer) do s.px[i] = hex(UI[color(n, i % 18, i // 18)]) end
  return s
end
-- Anel de recarga do Radar: tira de 9 quadros de 18 x 18, de 0/8 a 8/8, enchendo do alto no sentido horário.
-- O cheio também muda o miolo (apagado -> face de botão): o estado não é só cor.
local RADAR_FRAMES = 9
do
  local strip = { w = 18 * RADAR_FRAMES, h = 18, px = {} }
  for k = 0, RADAR_FRAMES - 1 do
    local f = disc(function(n, x, y)
      if n == 1 or n == 4 then return 'O' end
      if n == 5 then return k == RADAR_FRAMES - 1 and 'L' or 'B' end
      local a = math.atan(x - 8.5, 8.5 - y)
      if a < 0 then a = a + 2 * math.pi end
      if a >= k / (RADAR_FRAMES - 1) * 2 * math.pi then return 'D' end
      return n == 2 and 'S' or 't'
    end)
    for i, c in pairs(f.px) do strip.px[(i // 18) * strip.w + k * 18 + i % 18] = c end
  end
  piece('radar_ring', strip)
end
-- Mostrador da bússola, 18 x 18, não gira: aro em relevo e quatro riscos. Seguindo a direção: aro de 2 px no ciano do sinal.
local function dial(follow)
  local s = disc(function(n, x, y)
    if n == 1 then return 'O' end
    if n == 2 then return follow and 'S' or (x + y < 17 and 'H' or 'B') end
    if n == 3 and follow then return 't' end
    return 'D'
  end)
  for _, p in ipairs({ { 8, 3 }, { 9, 3 }, { 8, 14 }, { 9, 14 }, { 3, 8 }, { 3, 9 }, { 14, 8 }, { 14, 9 } }) do s.px[p[2] * 18 + p[1]] = hex(UI.L) end
  return s
end
piece('compass_dial', dial(false))
piece('compass_dial_follow', dial(true))

-- ---------------------------------------------------------------- folha (out/folha.png, a 3x)
-- O Conjurador do mapa, copiado de build_ui.lua só para a folha.
local player = grid({
  '.......OO.......', '......mnnw......', '.....mmnnww.....', '.....mmwwww.....', '.....mwCCww.....', '.....nnCCww.....',
  '.....nnDDwn.....', '.....nnnnnn.....', '.....ggnnww.....', '....kWggnwww....', '....CCggnwww....', '....CCngnwww....',
  '...Oggnnnnwww...', '...nnnnnnnwww...', '..OnnnwwnwwwwO..', '................',
}, 'player', { O = '1a1424', n = '3a3450', w = '2b2540', m = '56507a', D = '2e8f86', C = '5fd3c6', W = 'cff7f1', k = '22304a', g = '2f5f66' })

local SW, SH = 200, 190
local sheet = { w = SW, h = SH, px = {} }
local function rect(x, y, w, h, c) for yy = y, y + h - 1 do for xx = x, x + w - 1 do sheet.px[yy * SW + xx] = c end end end
local function blit(s, ox, oy)
  for i, c in pairs(s.px) do
    local x, y = ox + i % s.w, oy + i // s.w
    if x >= 0 and x < SW and y >= 0 and y < SH then sheet.px[y * SW + x] = c end
  end
end
-- A moldura `name` esticada para w x h, como o centerSlice do Flutter.
local function nine(name, w, h)
  local f = frames[name]
  local s, l, t, r, b = f.s, f.slice[1], f.slice[2], f.slice[3], f.slice[4]
  local d = { w = w, h = h, px = {} }
  local function src(v, n, sn, a, z)
    if v < a then return v end
    if v >= n - z then return sn - (n - v) end
    return a + (v - a) * (sn - a - z) // (n - a - z)
  end
  for y = 0, h - 1 do for x = 0, w - 1 do d.px[y * w + x] = s.px[src(y, h, s.h, t, b) * s.w + src(x, w, s.w, l, r)] end end
  return d
end
local function tile(s, x, y, w, h)
  for yy = 0, h - 1 do for xx = 0, w - 1 do sheet.px[(y + yy) * SW + x + xx] = s.px[(yy % s.h) * s.w + xx % s.w] end end
end
local P = pieces
rect(0, 0, SW, 78, hex('429658')) -- o HUD e o aviso, sobre a grama do mapa
rect(0, 78, SW, SH - 78, hex(UI.P)) -- o celular e os componentes, sobre o painel
-- Barra do topo em dois tamanhos, a primeira com o aviso dentro.
blit(nine('hud_bar', 120, 16), 4, 4)
blit(nine('warn_tag', 30, 8), 90, 8)
blit(nine('hud_bar', 60, 16), 128, 4)
-- Retrato (com o Conjurador e o XP em 11 de 18), botão do celular, bússola, marca, bolinha e atalhos.
blit(P.hud_portrait, 4, 24) blit(player, 6, 26) tile(P.xp_fill, 5, 48, 11, 2)
blit(P.phone_button, 28, 24) blit(P.phone_button_pressed, 50, 24)
blit(P.compass_dial, 72, 24) blit(P.compass_needle, 78, 27)
blit(P.compass_dial_follow, 94, 24) blit(P.compass_needle, 100, 27)
blit(P.compass_needle, 116, 27)
blit(P.edge_mark, 126, 24)
blit(P.badge_dot, 140, 24)
blit(nine('shortcut_chip', 48, 11), 148, 24)
blit(nine('shortcut_chip', 23, 11), 148, 38) blit(nine('shortcut_chip_pressed', 23, 11), 173, 38)
blit(P.radar_ring, 4, 56)
blit(nine('warn_tag', 28, 8), 170, 56) blit(nine('warn_tag', 16, 8), 170, 66)
-- Celular: o aparelho com o fundo e os lugares de ícone em dois tamanhos; o aparelho pequeno e o ladrilho cru.
blit(nine('phone_body', 64, 80), 4, 82)
tile(P.phone_wall, 8, 86, 56, 72)
blit(nine('app_tile', 24, 24), 11, 90) blit(nine('app_tile_new', 24, 24), 37, 90) blit(P.badge_dot, 58, 89)
blit(nine('app_tile', 16, 16), 11, 120) blit(nine('app_tile_new', 16, 16), 31, 120)
blit(nine('phone_body', 30, 30), 72, 82)
tile(P.phone_wall, 72, 116, 24, 24)
-- Componentes.
blit(P.switch_off, 108, 82) blit(P.switch_on, 126, 82)
blit(nine('chip_cond', 30, 7), 144, 82) blit(P.cond_dot, 146, 84)
blit(nine('chip_cond', 16, 7), 178, 82) blit(P.cond_dot, 180, 84)
blit(nine('dialog', 88, 44), 108, 94)
blit(nine('dialog', 40, 26), 108, 142)
blit(nine('card', 22, 26), 150, 142) blit(nine('card_selected', 22, 26), 174, 142)
blit(nine('card', 44, 16), 108, 171) blit(nine('card_selected', 44, 16), 154, 171)
save(sheet, 'folha', 3)

local n = 0
for _ in pairs(pieces) do n = n + 1 end
print(#frameOrder .. ' molduras, ' .. n .. ' pecas, folha ' .. SW * 3 .. 'x' .. SH * 3)
for _, p in ipairs(problems) do print('PROBLEMA ' .. p) end
