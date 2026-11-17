-- Kenoma 0.24.0: gera a arte da Bolsa e da Bancada (molduras em nove partes, pontos de qualidade, ícones de 16 px e o
-- equipamento do Conjurador) e a folha de contato. Fonte única: as linhas de pixels deste arquivo.
-- Rodar no Aseprite em lote: aseprite -b --script tools/art/ui/build_ui.lua
-- Regras do estilo: docs/art/estilo-ui.md.
local BASE = '/home/yuri/Documentos/kenoma/tools/art/ui/'
local OUT = BASE .. 'out/'
app.fs.makeAllDirectories(OUT .. 'icons')
app.fs.makeAllDirectories(BASE .. 'icons')
local pc = app.pixelColor
local problems = {}

local function hex(h)
  return pc.rgba(tonumber(h:sub(1, 2), 16), tonumber(h:sub(3, 4), 16), tonumber(h:sub(5, 6), 16), #h >= 8 and tonumber(h:sub(7, 8), 16) or 255)
end
local function mix(a, b, t)
  local out = ''
  for i = 1, 5, 2 do
    local x, y = tonumber(a:sub(i, i + 1), 16), tonumber(b:sub(i, i + 1), 16)
    out = out .. string.format('%02x', math.floor(x + (y - x) * t + 0.5))
  end
  return out
end

-- Paleta dos ícones: as cores de material_sprites.dart mais as três da magia.
local PAL = {
  O = '1a1424',
  a = 'f4f0e2', b = 'd8d2c0', c = 'a8a090', -- giz, barro, cera
  e = 'e2f6c8', f = 'a8dc8c', g = '6aa868', -- ectoplasma
  h = '8ad06a', i = '4e9e48', j = '2e6e3a', -- erva
  t = 'c9963a', -- barbante, palha
  k = 'f0faff', l = 'b4dcf2', m = '7aa8d4', -- gelo, neve
  n = '8a7e8e', o = '5a5064', p = '3a3244', -- meteorito
  y = 'f2d15a', Y = 'b8922e', z = 'f6e27a', -- ouro
  q = 'e6f4ff', w = '5aa0e6', x = '3a6eb8', r = 'b08a5a', -- vidro, água, rolha
  s = 'a8a4b4', u = '7c788c', v = '56526a', -- pedra
  A = 'b4c0c8', B = '7e8a94', C = '56606c', -- metal
  R = 'a8553d', Q = 'c8754f', -- ferrugem
  D = 'e6c48e', E = 'c89a62', F = '9a6a3e', G = '6a4628', -- madeira, couro
  H = 'ff8a8a', I = 'd8324a', J = '8e1c36', -- carmesim
  W = 'fdfbff', K = 'ff9ac8', L = '8ab4ff', -- prisma
  V = '9b7bff', U = 'c9b8ff', T = '5a4a9e', -- Véu
  S = '5fd3c6', Z = 'ff7a45', -- sinal, Essência
  M = '6c668a', N = '4a4560', X = '2b2540', -- vidro escuro
  P = 'fff3b0', -- luz de lua
  ['0'] = '56708e', -- vidro vazio
  ['7'] = 'ffffff', ['8'] = 'd6d2de', ['9'] = '9c98a8', -- neutro, para tingir
}
-- Paleta das molduras: os tokens de app/lib/ui/tema.dart.
local UI = {
  O = '1a1424', D = '120e1a', P = '1e1830', B = '2a2240', L = '3d3357', H = '56507a',
  V = '9b7bff', U = 'c9b8ff', S = '5fd3c6', s = 'a5efe6', t = '2e8f86', g = '2f5f66',
}

-- rows -> {w, h, px}; map troca um caractere por outro da paleta ou por um hex direto.
local function grid(rows, map, pal, name)
  pal = pal or PAL
  local w = #rows[1]
  local s = { w = w, h = #rows, px = {} }
  for y, row in ipairs(rows) do
    if #row ~= w then problems[#problems + 1] = (name or '?') .. ': linha ' .. y .. ' com ' .. #row .. ' px, esperado ' .. w end
    for x = 1, math.min(#row, w) do
      local ch = row:sub(x, x)
      if ch ~= '.' then
        local k = map and map[ch] or ch
        local h = #k >= 6 and k or pal[k]
        if not h then problems[#problems + 1] = (name or '?') .. ': sem cor para ' .. ch else s.px[(y - 1) * w + (x - 1)] = hex(h) end
      end
    end
  end
  return s
end
local function over(s, ox, oy, rows, map)
  local o = grid(rows, map)
  for i, c in pairs(o.px) do s.px[(oy + i // o.w) * s.w + ox + i % o.w] = c end
  return s
end
local function centered(s, side)
  local d = { w = side, h = side, px = {} }
  local ox, oy = (side - s.w) // 2, (side - s.h) // 2
  for i, c in pairs(s.px) do d.px[(oy + i // s.w) * side + ox + i % s.w] = c end
  return d
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
local function save(s, adir, pdir, name, scale)
  local spr = Sprite(s.w, s.h)
  spr:newCel(spr.layers[1], 1, toImage(s), Point(0, 0))
  spr:saveAs(adir .. name .. '.aseprite')
  if scale then
    local big = Sprite(s.w * scale, s.h * scale)
    big:newCel(big.layers[1], 1, toImage(s, scale), Point(0, 0))
    big:saveCopyAs(pdir .. name .. '.png')
    big:close()
  else
    spr:saveCopyAs(pdir .. name .. '.png')
  end
  spr:close()
end

-- ---------------------------------------------------------------- molduras
local frames, frameOrder = {}, {}
local function frame(name, slice, rows, map)
  frames[name] = { s = grid(rows, map, UI, name), slice = slice }
  frameOrder[#frameOrder + 1] = name
  save(frames[name].s, BASE, OUT, name)
end

frame('panel', { 4, 4, 4, 4 }, {
  '.OOOOOOOOOO.',
  'OHHHHHHHHHLO',
  'OLPPPPPPPPDO',
  'OLPPPPPPPPDO',
  'OLPPPPPPPPDO',
  'OLPPPPPPPPDO',
  'OLPPPPPPPPDO',
  'OLPPPPPPPPDO',
  'OLPPPPPPPPDO',
  'OLPPPPPPPPDO',
  'OLDDDDDDDDDO',
  '.OOOOOOOOOO.',
})
frame('sheet', { 3, 3, 3, 1 }, {
  '..OOOOOOOO..',
  '.OVVVVVVVVO.',
  'OHPPPPPPPPHO',
  'PPPPPPPPPPPP',
  'PPPPPPPPPPPP',
  'PPPPPPPPPPPP',
})
frame('tab_on', { 4, 4, 4, 2 }, {
  '..OOOOOOOO..',
  '.OVVVVVVVVO.',
  'OHPPPPPPPPLO',
  'OLPPPPPPPPDO',
  'OLPPPPPPPPDO',
  'OLPPPPPPPPDO',
  'OLPPPPPPPPDO',
  'OLPPPPPPPPDO',
  'OLPPPPPPPPDO',
  'OPPPPPPPPPPO',
})
frame('tab_off', { 4, 4, 4, 2 }, {
  '............',
  '..OOOOOOOO..',
  '.OLLLLLLLLO.',
  'OLDDDDDDDDDO',
  'ODDDDDDDDDDO',
  'ODDDDDDDDDDO',
  'ODDDDDDDDDDO',
  'ODDDDDDDDDDO',
  'OOOOOOOOOOOO',
  'HHHHHHHHHHHH',
})
frame('button', { 3, 3, 3, 3 }, {
  '.OOOOOOOOOO.',
  'OHHHHHHHHHHO',
  'OHLLLLLLLLLO',
  'OHLLLLLLLLLO',
  'OHLLLLLLLLLO',
  'OHLLLLLLLLLO',
  'OHLLLLLLLLLO',
  'OLLLLLLLLLLO',
  'OBBBBBBBBBBO',
  'OBBBBBBBBBBO',
  '.OOOOOOOOOO.',
})
frame('button_pressed', { 3, 5, 3, 2 }, {
  '............',
  '............',
  '.OOOOOOOOOO.',
  'ODDDDDDDDDDO',
  'ODBBBBBBBBBO',
  'ODBBBBBBBBBO',
  'ODBBBBBBBBBO',
  'ODBBBBBBBBBO',
  'ODBBBBBBBBBO',
  'ODBBBBBBBBBO',
  '.OOOOOOOOOO.',
})
frame('button_disabled', { 3, 3, 3, 3 }, {
  '.OOOOOOOOOO.',
  'OBBBBBBBBBBO',
  'OBBBBBBBBBBO',
  'OBBBBBBBBBBO',
  'OBBBBBBBBBBO',
  'OBBBBBBBBBBO',
  'OBBBBBBBBBBO',
  'OBBBBBBBBBBO',
  'OPPPPPPPPPPO',
  'OPPPPPPPPPPO',
  '.OOOOOOOOOO.',
})
frame('cell', { 2, 2, 2, 2 }, {
  '.OOOOOO.',
  'ODDDDDDL',
  'ODDDDDDL',
  'ODDDDDDL',
  'ODDDDDDL',
  'ODDDDDDL',
  'ODDDDDDL',
  '.LLLLLL.',
})
frame('cell_selected', { 3, 3, 3, 3 }, {
  '.VVVVVV.',
  'VOOOOOOV',
  'VOBBBBOV',
  'VOBBBBOV',
  'VOBBBBOV',
  'VOBBBBOV',
  'VOOOOOOV',
  '.VVVVVV.',
})
frame('bar_frame', { 2, 2, 2, 2 }, {
  '.OOOOOO.',
  'ODDDDDDL',
  'ODDDDDDL',
  'ODDDDDDL',
  'ODDDDDDL',
  '.LLLLLL.',
})
frame('bar_fill', { 1, 1, 1, 1 }, {
  'sss',
  'SSS',
  'SSS',
  'ttt',
})
frame('chip', { 3, 3, 3, 3 }, {
  '..OOOOOO..',
  '.OttttttO.',
  'OtDDDDDDgO',
  'OgDDDDDDgO',
  'OgDDDDDDgO',
  'OgDDDDDDgO',
  'OgDDDDDDgO',
  '.OggggggO.',
  '..OOOOOO..',
})

-- ---------------------------------------------------------------- pontos de qualidade
local DOT = { 'OlO', 'lbd', 'OdO' }
local dots = {
  dot_common = grid(DOT, { l = 'd4d2dc', b = 'a3a7b3', d = '6a707f' }),
  dot_good = grid(DOT, { l = 'a5efe6', b = '5fd3c6', d = '2e8f86' }),
  dot_perfect = grid(DOT, { l = 'fff3b0', b = 'f2d15a', d = 'b8922e' }),
}
for name, s in pairs(dots) do save(s, BASE, OUT, name) end

-- ---------------------------------------------------------------- ícones
local icons = {}
local function icon(name, s)
  if s.w > 16 or s.h > 16 then problems[#problems + 1] = name .. ': maior que 16 px' end
  local c = centered(s, 16)
  icons[#icons + 1] = { name = name, s = c }
  save(c, BASE .. 'icons/', OUT .. 'icons/', name)
end
local function draw(name, rows, map) icon(name, grid(rows, map, PAL, name)) end

-- Garrafa de vidro: level = quantas das 5 linhas do bojo estão cheias.
local function bottle(level, c1, c2, c3)
  local rows = { '..OOOO..', '..OrrO..', '..OrrO..', '..OqqO..', '.OOq0OO.', 'Oqq0000O', 'Oq00000O' }
  local full = { 'Oq11111O', 'Oq22223O', 'Oq22223O', 'Oq22233O', 'O222333O' }
  local empty = { 'Oq00000O', 'Oq00000O', 'Oq00000O', 'Oq00000O', 'O000000O' }
  for i = 1, 5 do
    if i <= 5 - level then rows[#rows + 1] = empty[i]
    elseif i == 5 - level + 1 then rows[#rows + 1] = i == 5 and 'O111111O' or 'Oq11111O'
    else rows[#rows + 1] = full[i] end
  end
  rows[#rows + 1] = '.OOOOOO.'
  return grid(rows, { ['1'] = c1, ['2'] = c2, ['3'] = c3 })
end
-- Frasco escuro, com a lua dentro.
local function flask(moon, map)
  local s = grid({
    '...OOOO...',
    '...OABO...',
    '...ONNO...',
    '..OOsMOO..',
    '.OssMNNNO.',
    'OsMMNNNNXO',
    'OsMNNNNNXO',
    'OsMNNNNNXO',
    'OMNNNNNXXO',
    'ONNNNNXXXO',
    '.ONXXXXXO.',
    '..OOOOOO..',
  })
  return moon and over(s, 3, 5, moon, map) or s
end
-- Selo: disco com aro ('4'), três tons de miolo e a runa de 6 x 6 no centro.
local function seal(c4, c1, c2, c3, glyph, gmap)
  local s = grid({
    '....OOOO....',
    '..OO4444OO..',
    '.O44111144O.',
    '.O41122224O.',
    'O4112222224O',
    'O4122222224O',
    'O4122222234O',
    'O4222222334O',
    '.O42222334O.',
    '.O44233344O.',
    '..OO4444OO..',
    '....OOOO....',
  }, { ['4'] = c4, ['1'] = c1, ['2'] = c2, ['3'] = c3 })
  return over(s, 3, 3, glyph, gmap)
end
local TRI = { '..11..', '..11..', '.1..1.', '.1..1.', '1....1', '111111' }
-- Tônico: o frasco cônico.
local function tonic(c1, c2, c3)
  return grid({
    '...OOOO...',
    '...OrrO...',
    '...OqqO...',
    '...Oq0O...',
    '..Oq000O..',
    '..Oq000O..',
    '.Oq11111O.',
    '.O222223O.',
    'O22222233O',
    'O22222333O',
    'O22223333O',
    '.OOOOOOOO.',
  }, { ['1'] = c1, ['2'] = c2, ['3'] = c3 })
end
-- Amuleto: cordão, engaste de ferro e o emblema de 6 x 6.
local function amulet(emblem)
  local s = grid({
    '....OOOO....',
    '...OtOOtO...',
    '...OtOOtO...',
    '..OOOAAOOO..',
    '.OAABBBBBCO.',
    'OABXXXXXXBCO',
    'OABXXXXXXBCO',
    'OABXXXXXXBCO',
    'OABXXXXXXBCO',
    'OABXXXXXXBCO',
    'OBBXXXXXXCCO',
    '.OBBCCCCCCO.',
    '..OOOOOOOO..',
  })
  return over(s, 3, 5, emblem)
end

-- Materiais que já existem (a cara dos sprites do mapa, ampliada).
draw('scrap', {
  '....OOOO....',
  '....OAAO....',
  '..OOOABOOO..',
  '.OAABBBBBCO.',
  'OOABBOOBBCOO',
  'OAABO..OBBCO',
  'OABBO..OBCCO',
  'OOBBBOOBCCOO',
  '.OBBBBCCCRO.',
  '..OOOBCOOO..',
  '....ORRO....',
  '....OOOO....',
})
local CHALK = {
  '.......OOO.',
  '......OaaaO',
  '.....OaabbO',
  '....OaabbO.',
  '...OaabbO..',
  '..OaabbO...',
  '.OaabbO....',
  'OaabbcO....',
  'OabccO.....',
  'OccO.......',
  '.OO........',
}
draw('chalk', CHALK)
local HERBS = {
  '.OO..O..OO.',
  'OhhOOhOOhhO',
  'OhiiOhOiijO',
  '.OhiihiijO.',
  '..OhiiijO..',
  '...OiijO...',
  '...OtttO...',
  '...OijjO...',
  '...OiOjO...',
  '...OO.OO...',
}
draw('herbs', HERBS)
draw('pure_water', {
  '..OOOO..',
  '..OrrO..',
  '..OqqO..',
  '.OOq0OO.',
  'Oqq0000O',
  'Oq00000O',
  'OqwwwwxO',
  'OwwwwwxO',
  'OwwwwxxO',
  '.OOOOOO.',
})
draw('ectoplasm', {
  '...OOOOO....',
  '..OeeeeeO...',
  '.OeefffffO..',
  'OeefffffffO.',
  'OeffffffffgO',
  'OefffffffggO',
  'OffffffffggO',
  'OffgfffgfggO',
  'OfgOgfgOgfgO',
  'OgO.OgO.OggO',
  '.O...O...OO.',
})
draw('ice_crystal', {
  '...O.......',
  '..OkO......',
  '..OkO..O...',
  '.OkklO.OkO.',
  '.OklllOOklO',
  '.OklllOkllO',
  'OkklllOkllO',
  'OkllllkllmO',
  'OkllllllmmO',
  'OllllllmmmO',
  'OllmmmmmmmO',
  '.OOOOOOOOO.',
})
draw('prism_shard', {
  '......O......',
  '.....OWO.....',
  '.....OWKO....',
  '....OWWKO....',
  '....OWKKzO...',
  '...OWWKKzO...',
  '...OWKKzzLO..',
  '..OWWKKzzLO..',
  '..OWKKKzzLLO.',
  '.OWWKKzzzLLO.',
  '.OWKKKzzzLLLO',
  'OOOOOOOOOOOOO',
})
draw('dew_prism', {
  '.....O.....',
  '....OWO....',
  '...OWWKO...',
  '..OWWKKzO..',
  '.OWWKKzzLO.',
  'OWWKKKzzLLO',
  'OOOOOOOOOOO',
  'OWKKKzzzLLO',
  '.OKKzzzLLO.',
  '..OKzzLLO..',
  '...OzzLO...',
  '....OLO....',
  '.....O.....',
})
-- Essência e Pó genéricos em tons neutros: o código tinge pela cor do tipo (multiplicar).
local DROP = {
  '....O....',
  '...O1O...',
  '...O1O...',
  '..O112O..',
  '..O122O..',
  '.O11222O.',
  '.O12222O.',
  'O1122223O',
  'O1222233O',
  'O1222233O',
  'O2222333O',
  '.O22333O.',
  '..OOOOO..',
}
draw('essence', DROP, { ['1'] = '7', ['2'] = '8', ['3'] = '9' })
draw('dust', {
  '.....OO.....',
  '....O77O....',
  '...O7788O...',
  '..O778888O..',
  '.O77888889O.',
  'O7788888999O',
  'O8888899999O',
  '.OOOOOOOOOO.',
})
draw('essence_crimson', DROP, { ['1'] = 'H', ['2'] = 'I', ['3'] = 'J' })
draw('essence_prismatic', {
  '....O....',
  '...OWO...',
  '...OWO...',
  '..OWWKO..',
  '..OWKKO..',
  '.OWWKKzO.',
  '.OWKKzzO.',
  'OWWKKzzLO',
  'OWKKzzLLO',
  'OWKKzzLLO',
  'OKKzzLLLO',
  '.OzzLLLO.',
  '..OOOOO..',
})
-- Selos que já existem: disco violeta com a runa em triângulo (docs/referencias-de-arte.md).
icon('seal_simple', seal('T', 'U', 'V', 'T', TRI, { ['1'] = 'W' }))
icon('seal_reinforced', seal('B', 'U', 'V', 'T', TRI, { ['1'] = 'W' }))
local TYPES = {
  { 'fire', 'ff5a36' }, { 'water', '4aa8ff' }, { 'plant', '6bd36a' }, { 'earth', 'c79a5b' }, { 'electric', 'ffd84a' }, { 'metal', '9fb3c8' },
  { 'light', 'fff3b0' }, { 'shadow', '6b5a8e' }, { 'spectral', 'b8c4d6' }, { 'digital', '3dffb0' }, { 'fae', 'ff8fd8' }, { 'draconic', 'd14b4b' },
}
for _, t in ipairs(TYPES) do
  local dark = mix(t[2], '1a1424', 0.45)
  icon('seal_' .. t[1], seal(dark, mix(t[2], 'ffffff', 0.45), t[2], dark, TRI, { ['1'] = 'O' }))
end
icon('tonic_focus', tonic('h', 'i', 'j'))

-- Brutos sem nome.
draw('meteorite', {
  '...OOOOOO...',
  '..OnnnoooO..',
  '.OnnooopooO.',
  'OnnoooooopoO',
  'OnooyyoooopO',
  'OnooyyooppoO',
  'OoopoooopppO',
  '.OooooppppO.',
  '..OoppppppO.',
  '...OOOOOOO..',
})
local RUNE = {
  '...OOOO...',
  '..OssssO..',
  '.OssuuuuO.',
  'OssuyuuuvO',
  'OsuuyuyuvO',
  'OsuuyyyuvO',
  'OsuuyuyuvO',
  'OsuuyuuuvO',
  'OsuuyuuvvO',
  'OsuuuuuvvO',
  'OuuuuvvvvO',
  'OOOOOOOOOO',
}
draw('rune', RUNE)
draw('wood', {
  '..OO.....OO.',
  '.OkEO...OkEO',
  '.OEFO..OEFO.',
  '..OEFOOEFO..',
  '...OEEFFO...',
  '...OkEFO....',
  '..OEEFGO....',
  '..OEFGO.....',
  '.OkFGO......',
  '.OFGO.......',
  '..OO........',
})

-- Recipientes.
icon('vessel_glass', bottle(0))
icon('vessel_dark', flask())
draw('vessel_candle', {
  '.....O....',
  '....OGO...',
  '.OOOOGOOO.',
  'OAeeeeeeCO',
  'OAAAAAABCO',
  'OABBBBBBCO',
  'OABBBBBBCO',
  'OABRBBBBCO',
  'OABBBBRCCO',
  'OBBBBCCCCO',
  '.OOOOOOOO.',
})
draw('vessel_thermal', {
  '..OOOO..',
  '..OrrO..',
  '..OrrO..',
  '..OqqO..',
  '.OOq0OO.',
  'OttFttFO',
  'OtFttFGO',
  'OFttFtGO',
  'OttFttGO',
  'OtFttFGO',
  'OFttFGGO',
  'OFFGGGGO',
  '.OOOOOO.',
})

-- Condições engarrafadas.
icon('rain_water', bottle(5, 'l', 'w', 'x'))
icon('snow', bottle(5, 'k', 'k', 'l'))
icon('snow_water', bottle(3, 'k', 'l', 'm'))
icon('moonlight_new', flask({ '.vvv.', 'v...v', 'v...v', 'v...v', '.vvv.' }))
-- Hemisfério sul: a crescente acende pela esquerda, a minguante pela direita.
icon('moonlight_waxing', flask({ '.PP..', 'PP...', 'PP...', 'PP...', '.PP..' }))
icon('moonlight_full', flask({ '.PPP.', 'PWPPP', 'PPPPP', 'PPPPy', '.PyP.' }))
icon('moonlight_waning', flask({ '..PP.', '...PP', '...PP', '...PP', '..PP.' }))
draw('rift_smoke', {
  '..OOO.....',
  '.OUVVO....',
  '..OOVVO...',
  '...OUVO...',
  '.OOOVOOOO.',
  'OATTTTTTCO',
  'OAAAAAABCO',
  'OABBBBBBCO',
  'OABRBBBBCO',
  'OABBBBRCCO',
  'OBBBBCCCCO',
  '.OOOOOOOO.',
})

-- Refinados.
icon('ref_consecrated_chalk', over(grid(CHALK), 1, 1, { '.U.', 'UVU', '.U.' }))
draw('ref_white_clay', {
  '...OOOOOO...',
  '..OaaaaabO..',
  '.OaaabbbbbO.',
  'OaabbccbbbcO',
  'OabbbccbbbcO',
  'OabbbbbbbccO',
  'ObbbbbbccccO',
  '.OOOOOOOOOO.',
})
draw('ref_quicklime', {
  '.....OO.....',
  '....OaaO....',
  '...OaabO.OO.',
  '.OOOabbOOabO',
  'OaaOabcOabcO',
  'OabDbccDbccO',
  'ObbccccbcccO',
  '.OOOOOOOOOO.',
})
draw('ref_lustral_water', {
  '.....OO.....',
  '....OqwO....',
  '....OwxO....',
  '.....OO.....',
  '.OOOOOOOOOO.',
  'OAllllllllCO',
  'OAwwwwwwxxCO',
  '.OABBBBBCCO.',
  '..OABBBCCO..',
  '...OOOOOO...',
})
local SALT = {
  '.....OOOOO..',
  '....OWWWWO..',
  '.OOOOWaabO..',
  'OWWWOaZbbO..',
  'OWaaOabbcOO.',
  'OaabOOOOOWWO',
  'OabbcO.OWabO',
  'OOOOOO.OabcO',
  '.......OOOOO',
}
draw('ref_essence_salt', SALT)
draw('ref_dried_herbs', HERBS, { h = 'D', i = 't', j = 'F', t = 'R' })
draw('ref_braided_fiber', {
  '.OOOO.',
  'OttFFO',
  'OFttFO',
  'OFFttO',
  'OttFFO',
  'OFttFO',
  'OFFttO',
  'OttFFO',
  'OFttFO',
  'OFFttO',
  '.OGGO.',
  'OtOOFO',
  'OO..OO',
})
draw('ref_green_infusion', {
  '..OOOOOO..',
  '.OqqqqqqO.',
  '..OOOOOO..',
  '.Oq0000hO.',
  'OqhhhhhhhO',
  'OqiiihiiiO',
  'OiiihhhijO',
  'OiiiihijjO',
  'OiiiiijjjO',
  '.OOOOOOOO.',
})
draw('ref_cold_iron', {
  '..OOOOOOOO..',
  '.OAAAAAAkAO.',
  '.OABBBBBBCO.',
  'OAABBBBBBCCO',
  'OABBBkBBBCCO',
  'OBBCCCCCCCCO',
  '.OOOOOOOOOO.',
})
draw('ref_living_rust', {
  '....OOO.....',
  '..OOQQROO...',
  '.OQQRRRRRO..',
  'OQRRGRRRRRO.',
  'OQRRRRRGRRGO',
  'ORRGRRRRRGGO',
  '.ORRRRGRGGO.',
  '..OOGGGGOO..',
  '....OOOO....',
})
draw('ref_tin_mirror', {
  '...OOOO...',
  '.OOAAAAOO.',
  '.OAWWAABO.',
  'OAWWAAABBO',
  'OAWAAABBWO',
  'OAAAABBWBO',
  'OAAABBBBCO',
  '.OABBBBCO.',
  '.OOBBCCOO.',
  '...OOOO...',
})
draw('ref_still_ectoplasm', {
  '...OOOO...',
  '.OOeeeeOO.',
  '.OeeefffO.',
  'OeeffffffO',
  'OefffffffO',
  'OefffffgfO',
  'OfffffffgO',
  '.OffffggO.',
  '.OOggggOO.',
  '...OOOO...',
})

-- Componentes.
local INK = {
  '...OOOO...',
  '...OVVO...',
  '..OOOOOO..',
  '.OaabbbbO.',
  'OaabbbbbcO',
  'OabbVVbbcO',
  'OabbVVbbcO',
  'ObbbbbbccO',
  'ObbccccccO',
  '.OOOOOOOO.',
}
draw('comp_sigil_ink', INK)
draw('comp_seal_core', {
  '..OOOOOO..',
  '.OaaaaabO.',
  'OaabbbbbcO',
  'OabOOOObcO',
  'OabOefObcO',
  'OabOffObcO',
  'OabOOOObcO',
  'ObbbbbbccO',
  '.ObcccccO.',
  '..OOOOOO..',
})
draw('comp_ether_filament', {
  '.OOOOOOOO.',
  'OEEEEEEFFO',
  '.OOOOOOOO.',
  '..OkkllO..',
  '..OklkmO..',
  '..OkllmO..',
  '..OlklmO..',
  '..OllmmO..',
  '.OOOOOOOO.',
  'OEEEEEFFGO',
  '.OOOOOOOO.',
})
draw('comp_veil_weave', {
  '.OOOOOOOOOO.',
  'OQQQQQQQQQRO',
  'OQRRRRRRRRRO',
  'OQRVRVRVRVRO',
  'OQRRRRRRRRGO',
  'OOOOOOOOOOOO',
  'OQRRRRRRRGGO',
  'ORRVRVRVRGGO',
  'ORRRRGGGGGGO',
  '.OOOOOOOOOO.',
})
draw('comp_cold_setting', {
  '.OO......OO.',
  'OAAO....OABO',
  'OABO....OBCO',
  'OABBO..OBBCO',
  '.OABBOOBBCO.',
  '.OABBBBBBCO.',
  '..OABBBBCO..',
  '...OBBCCO...',
  '....OBCO....',
  '....OBCO....',
  '.....OO.....',
})
draw('comp_sun_lens', {
  '...OOOO.....',
  '.OOyyyyOO...',
  '.OyqqqlyO...',
  'OyqWqlllYO..',
  'OyqqlllwYO..',
  'OyqllllwYO..',
  'OyllllwwYO..',
  '.OYlwwwYO...',
  '.OOYYYYOOO..',
  '...OOOOOFFO.',
  '........OFGO',
  '.........OO.',
})
draw('comp_focus_extract', {
  '..OOOO..',
  '..OGGO..',
  '..OGGO..',
  '.OOOOOO.',
  '.OBBBBO.',
  '.OOOOOO.',
  'Oqq0000O',
  'Oq00000O',
  'OqjjjjjO',
  'OjjjjjXO',
  'OjjjjXXO',
  '.OOOOOO.',
})
draw('comp_white_wax', {
  '...OOOOOO...',
  '..OaaaaaaO..',
  '..OabbbbcO..',
  '..OabVVbcO..',
  '..OabbbbcO..',
  '.OOabbbbcOO.',
  'OaaabbbbcccO',
  'OabbbbbbbbcO',
  '.OOOOOOOOOO.',
})
draw('comp_hidden_ink', INK, { a = 'M', b = 'N', c = 'X', V = 'U' })
draw('comp_waning_salt', SALT, { W = 'U', a = 'M', b = 'N', c = 'X', Z = 'P' })

-- Peças de uso.
icon('seal_sigil', seal('c', 'U', 'V', 'T', { '1....1', '.1111.', '.1..1.', '.1..1.', '.1111.', '1....1' }, { ['1'] = 'W' }))
icon('seal_umbral', seal('M', 'N', 'X', 'X', { '.1111.', '1....1', '1....1', '1....1', '1....1', '.1111.' }, { ['1'] = 'U' }))
icon('seal_moonlit', seal('y', 'ffc7eb', 'ff8fd8', 'c2639f', { '..PP..', '.PPPP.', 'PPPPPP', 'PPPPPP', '.PPPP.', '..PP..' }))
icon('seal_haunt', seal('7c8aa0', 'W', 'b8c4d6', '7c8aa0', { '......', '.O..O.', '.O..O.', '......', '..OO..', '......' }))
icon('tonic_vigil', tonic('l', 'w', 'x'))
icon('tonic_waxing', over(tonic('P', 'y', 'Y'), 4, 8, { 'OO.', 'O..', 'OO.' }, { O = 'W' }))
icon('tonic_rift', tonic('U', 'V', 'T'))

-- Amuletos de estação.
icon('amulet_summer_downpour', amulet({ 'XXqXXX', 'XXwwXX', 'XqwwwX', 'XwwwxX', 'XwwxxX', 'XXxxXX' }))
icon('amulet_summer_thunder', amulet({ 'XXXyyX', 'XXyyXX', 'XyyyyX', 'XXXyyX', 'XXyyXX', 'XXyXXX' }))
icon('amulet_autumn_harvest', amulet({ 'XXXyXX', 'XyXYXy', 'XXyYyX', 'XyXYXy', 'XXyYyX', 'XXXtXX' }))
icon('amulet_autumn_leaf', amulet({ 'XXXXQX', 'XXQQRX', 'XQQRRX', 'XQRRXX', 'XRRXXX', 'GXXXXX' }))
icon('amulet_winter_snow', amulet({ 'kXkXkX', 'XkkkXX', 'kkkkkX', 'XkkkXX', 'kXkXkX', 'XXXXXX' }))
icon('amulet_winter_mist', amulet({ 'XXXXXX', 'XsssXX', 'XXXsss', 'uuuXXX', 'XXuuuX', 'XXXXXX' }))
icon('amulet_spring_sprout', amulet({ 'XXXXhX', 'hhXhiX', 'XihiXX', 'XXiXXX', 'XXiXXX', 'XGGGGX' }))
icon('amulet_spring_bloom', amulet({ 'XKXXKX', 'KKKKKK', 'XKyyKX', 'XKyyKX', 'KKKKKK', 'XKXXKX' }))

-- Equipáveis.
local BAG = {
  '...OOOOOO...',
  '..OFOOOOFO..',
  '.OFO....OFO.',
  '.OFOOOOOOFO.',
  'OEEEEEEEEEFO',
  'OEFFFFFFFFGO',
  'OEFFFFFFFFGO',
  'OOFFFyyFFGOO',
  'OEOOFyyFOOGO',
  'OEFFOOOOFGGO',
  'OFFFFFFGGGGO',
  '.OOOOOOOOOO.',
}
draw('bag_satchel', BAG)
draw('bag_deep', BAG, { E = 's', F = 'M', G = 'N', y = 'V' })
draw('belt_bandolier', {
  '.OOO.OOO.OOO.',
  '.OrO.OrO.OrO.',
  'OOqOOOqOOOqOO',
  'OFqFFFqFFFqGO',
  'OFFFFFFFFFGGO',
  'OOwOOOwOOOwOO',
  '.OxO.OxO.OxO.',
  '.OOO.OOO.OOO.',
})
draw('grimoire_field', {
  '.OOOOOOOOO.',
  'OQRRRRRRRaO',
  'OQRRRRRRRaO',
  'OQRRVVRRRaO',
  'OQRVRRVRRaO',
  'OQRVRRVRRaO',
  'OQRRVVRRRaO',
  'OQRRRRRRRaO',
  'OQRRRRRRRaO',
  'OGGGGGGGGaO',
  'OaaaaaaaabO',
  '.OOOOOOOOO.',
})
draw('jewel_meteor', {
  '....OOOO....',
  '...OnooyO...',
  '...OoopoO...',
  '..OOOOOOOO..',
  '.OAAOOOOBBO.',
  'OAAO....OBCO',
  'OABO....OBCO',
  'OABO....OBCO',
  'OABBO..OBCCO',
  '.OBBBOOBCCO.',
  '..OBBCCCCO..',
  '...OOOOOO...',
})
draw('jewel_rune', {
  '....OOOO....',
  '...OtOOtO...',
  '...OtOOtO...',
  '.OOOOOOOOOO.',
  'OEEFFFFFFGGO',
  '.OOOOOOOOOO.',
  '...OssuvO...',
  '..OsuyuuvO..',
  '..OsuyyuvO..',
  '..OsuyuuvO..',
  '..OuuyuvvO..',
  '...OuvvvO...',
  '....OOOO....',
})

-- ---------------------------------------------------------------- equipamento no Conjurador (16 x 16)
local function blank16() local r = {} for i = 1, 16 do r[i] = '................' end return r end
local function gearRows(lines) local r = blank16() for y, row in pairs(lines) do r[y + 1] = row end return r end
local gear = {
  gear_bag = grid(gearRows({
    [7] = '......G.........',
    [8] = '.......G........',
    [9] = '........G.......',
    [10] = '.........GG.OO..',
    [11] = '...........OEFO.',
    [12] = '...........OFGO.',
    [13] = '............OO..',
  })),
  gear_bottle = grid(gearRows({
    [11] = '......r.........',
    [12] = '......q.........',
    [13] = '......w.........',
  })),
  gear_amulet_glow = grid(gearRows({
    [6] = '........a.......',
    [7] = '.......aba......',
    [8] = '......abCba.....',
    [9] = '.......aba......',
    [10] = '........a.......',
  }), { a = '9b7bff3c', b = '9b7bff8c', C = 'c9b8ffff' }),
}
for name, s in pairs(gear) do save(s, BASE, OUT, name) end
-- O Conjurador do mapa (downscaleRows(playerSprite, 16, keep: 'C')), só para a folha de contato.
local player = grid({
  '.......OO.......',
  '......mnnw......',
  '.....mmnnww.....',
  '.....mmwwww.....',
  '.....mwCCww.....',
  '.....nnCCww.....',
  '.....nnDDwn.....',
  '.....nnnnnn.....',
  '.....ggnnww.....',
  '....kWggnwww....',
  '....CCggnwww....',
  '....CCngnwww....',
  '...Oggnnnnwww...',
  '...nnnnnnnwww...',
  '..OnnnwwnwwwwO..',
  '................',
}, { O = '1a1424', n = '3a3450', w = '2b2540', m = '56507a', D = '2e8f86', C = '5fd3c6', W = 'cff7f1', k = '22304a', g = '2f5f66' })

-- ---------------------------------------------------------------- folha de contato
local SW, SH = 244, 78 + 24 * math.ceil(#icons / 10) + 2
local sheet = { w = SW, h = SH, px = {} }
local function rect(x, y, w, h, c) for yy = y, y + h - 1 do for xx = x, x + w - 1 do sheet.px[yy * SW + xx] = c end end end
local function blit(s, ox, oy)
  for i, c in pairs(s.px) do
    local x, y = ox + i % s.w, oy + i // s.w
    if x >= 0 and x < SW and y >= 0 and y < SH then
      local a = pc.rgbaA(c)
      if a < 255 then
        local d = sheet.px[y * SW + x]
        local t = a / 255
        c = pc.rgba(math.floor(pc.rgbaR(d) + (pc.rgbaR(c) - pc.rgbaR(d)) * t + 0.5), math.floor(pc.rgbaG(d) + (pc.rgbaG(c) - pc.rgbaG(d)) * t + 0.5),
          math.floor(pc.rgbaB(d) + (pc.rgbaB(c) - pc.rgbaB(d)) * t + 0.5), 255)
      end
      sheet.px[y * SW + x] = c
    end
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
rect(0, 0, SW, SH, hex(UI.P))
-- Fileira 1: painel, abas sobre o painel (2 px de sobreposição), botões, faixa, barra e pontos.
blit(nine('panel', 60, 40), 4, 4)
blit(nine('panel', 62, 30), 68, 14)
blit(nine('tab_on', 22, 10), 70, 6)
blit(nine('tab_off', 22, 10), 92, 6)
blit(nine('tab_off', 14, 10), 114, 6)
blit(nine('button', 40, 11), 134, 4)
blit(nine('button_pressed', 40, 11), 134, 18)
blit(nine('button_disabled', 40, 11), 134, 32)
blit(nine('chip', 60, 9), 180, 4)
blit(nine('bar_frame', 60, 6), 180, 17)
blit(nine('bar_fill', 34, 4), 181, 18)
blit(dots.dot_common, 180, 28)
blit(dots.dot_good, 188, 28) blit(dots.dot_good, 192, 28)
blit(dots.dot_perfect, 200, 28) blit(dots.dot_perfect, 204, 28) blit(dots.dot_perfect, 208, 28)
-- As molduras cruas, sem esticar.
local rx = 180
for _, name in ipairs(frameOrder) do
  if rx + frames[name].s.w <= SW then blit(frames[name].s, rx, 35) rx = rx + frames[name].s.w + 1 end
end
-- Fileira 2: a folha de baixo e o equipamento sobre o Conjurador, num chão de grama do mapa.
blit(nine('sheet', 100, 20), 4, 52)
rect(110, 50, 130, 24, hex('429658'))
blit(player, 112, 54)
blit(player, 130, 54) blit(gear.gear_bag, 130, 54)
blit(player, 148, 54) blit(gear.gear_bag, 148, 54) blit(gear.gear_bottle, 148, 54)
blit(player, 166, 54) blit(gear.gear_bag, 166, 54)
for n = 0, 2 do blit(gear.gear_bottle, 166 + 2 * n, 54) end
blit(gear.gear_amulet_glow, 166, 54)
blit(gear.gear_bag, 186, 54) blit(gear.gear_bottle, 202, 54) blit(gear.gear_amulet_glow, 218, 54)
-- Ícones: grade de 10, cada um na célula da bolsa; o primeiro de cada fileira na célula selecionada.
local dotNames = { 'dot_common', 'dot_good', 'dot_perfect' }
for i, ic in ipairs(icons) do
  local cx, cy = 2 + 24 * ((i - 1) % 10), 78 + 24 * ((i - 1) // 10)
  blit(nine((i - 1) % 10 == 0 and 'cell_selected' or 'cell', 22, 22), cx, cy)
  blit(ic.s, cx + 3, cy + 3)
  local q = (i - 1) % 3 + 1
  for n = 1, q do blit(dots[dotNames[q]], cx + 22 - 1 - 4 * n, cy + 22 - 5) end
end
save(sheet, BASE, OUT, 'contact_sheet', 4)

for i, ic in ipairs(icons) do io.write(i .. ':' .. ic.name .. ' ') end
print('')
print(#icons .. ' icones, ' .. #frameOrder .. ' molduras, folha ' .. SW * 4 .. 'x' .. SH * 4)
for _, p in ipairs(problems) do print('PROBLEMA ' .. p) end
