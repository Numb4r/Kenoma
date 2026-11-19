-- Humoth oficial (0.25.0), conceito A "Letreiro". Rodar pelo Aseprite: aseprite -b --script build.lua
-- Mapa: quadros de 28x28, tres camadas por animacao (corpo, leds, glow). Retrato: 96x96, 4 quadros,
-- a partir de humoth_portrait_src.aseprite (o conceito aprovado), com as asas flexionando por faixas de coluna.
-- Um caractere por pixel; a metade esquerda e desenhada e a direita e espelho.
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/humoth/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/ do worktree, com a barra no fim)')
local L = dofile(ART .. 'npc/_lib.lua')
local DIR = ART .. 'creatures/humoth/'
local W, H = 28, 28

local LEG = {
  A = '#1A1424',                                              -- contorno
  B = '#8F86C9', T = '#C4BDF0',                               -- antena
  C = '#2A2140', D = '#4A3D6B', R = '#6A5C94',                -- pelo
  G = '#34305E', F = '#4D4A8A', E = '#7672B8',                -- asa da frente
  P = '#28244A', Q = '#3D3A70',                               -- asa de tras (so no retrato)
  h = '#17444C', i = '#245A62', j = '#6B5A44',                -- ocelo e veio apagados (camada corpo)
  H = '#5FD3C6', I = '#D9FFF6',                               -- ocelo aceso (camada leds)
  J = '#FFD23A', Y = '#FFEE9A', S = '#FFD23A', s = '#FFEE9A', -- veio e faisca (camada glow): Eletrico de ui/types/palette.lua
  v = '#3A2E5A', V = '#9B7BFF',                               -- costura do Veu: apagada (corpo) e acesa (glow)
}
-- Costura do Veu: uma so, de 1 px, em diagonal no abdomen (parte do tronco: acompanha o corpo em toda animacao).
local SEAM = { { 11, 15 }, { 12, 16 }, { 13, 17 }, { 14, 18 }, { 15, 19 }, { 16, 20 } }
-- Cores do corpo que as variantes trocam (as apagadas e as emissivas ficam iguais em todas).
local BODY_KEYS = { 'P', 'Q', 'G', 'F', 'E', 'C', 'D', 'R', 'B', 'T' }

local BODY = { -- linhas 3..25, colunas 0..13
  '...BB.........',
  '....BBBB......',
  '......BBBB....',
  '.........BB...',
  '...........BCD',
  '...........CCD',
  '...........DCD',
  '...........DCC',
  '...........CCD',
  '...........DCC',
  '...........CCD',
  '...........DCC',
  '...........CCD',
  '...........DCC',
  '...........CCD',
  '...........DCC',
  '...........CCD',
  '...........DCC',
  '...........CCD',
  '...........DCC',
  '...........CCD',
  '............CD',
  '.............C',
}
local WING = { -- linhas 9..22; 0 aberta (delta), 1 meio batimento, 2 erguida (vista de cima: estreita)
  [0] = {
    '.........EFGGG',
    '........EFFGGG',
    '.......EFFGGGG',
    '......EFFGGGGG',
    '.....EFHHGGGGG',
    '....EFHIIHGGGG',
    '...EFFHIIHGGGG',
    '..EFFGGHHGGGGG',
    '.EFFGJGGJGGGGG',
    '.EFGJGGGJGGGGG',
    '.EFJGGGJGGGGGG',
    '.EJGG..JFFGGGG',
    '..GG....FFFGGG',
    '.........FFGGG',
  },
  [1] = {
    '.........EFGGG',
    '........EFGGGG',
    '........EFGGGG',
    '.......EFFGGGG',
    '.......EFHGGGG',
    '......EFHIHGGG',
    '......EFHIHGGG',
    '.....EFGGHGGGG',
    '.....EFGJGJGGG',
    '....EFGJGGJGGG',
    '....EFJGGJGGGG',
    '....EJGG.JFGGG',
    '.....GG...FGGG',
    '..............',
  },
  [2] = {
    '..........EGGG',
    '.........EFGGG',
    '.........EFGGG',
    '........EFGGGG',
    '........EFHGGG',
    '........EHIGGG',
    '.......EFHIGGG',
    '.......EFGHGGG',
    '.......EFJGGGG',
    '.......EFJGGGG',
    '.......EJGJGGG',
    '.......EJ.FGGG',
    '........G.FGGG',
    '..............',
  },
}

local function hash(x, y, k)
  local v = (x * 73856093) ~ (y * 19349663) ~ (k * 83492791)
  v = v ~ (v >> 13)
  return (v * 1274126177) & 0x7fffffff
end

local function compose(lp, rp)
  local g = L.grid(W, H)
  local function half(rows, y0, mirror, tag)
    for j, row in ipairs(rows) do
      if #row ~= 14 then error(tag .. ' linha ' .. j .. ': ' .. #row .. ' colunas') end
      for i = 1, 14 do
        local c = row:sub(i, i)
        if c ~= '.' then g[y0 + j - 1][mirror and (27 - (i - 1)) or (i - 1)] = c end
      end
    end
  end
  half(WING[lp], 9, false, 'asa' .. lp); half(WING[rp], 9, true, 'asa' .. rp)
  half(BODY, 3, false, 'corpo'); half(BODY, 3, true, 'corpo')
  for _, p in ipairs(SEAM) do g[p[2]][p[1]] = 'V' end
  return g
end

-- Inclina para a direita (antenas +2, ombros +1, ponta do abdomen -1) e sobe ou desce o corpo inteiro.
local function move(g, lean, dy)
  local o = L.grid(W, H)
  for y = 0, H - 1 do
    local dx = 0
    if lean then dx = (y <= 6 and 2) or (y <= 12 and 1) or (y >= 22 and -1) or 0 end
    for x = 0, W - 1 do
      if g[y][x] ~= '.' then L.set(o, x + dx, y + dy, g[y][x]) end
    end
  end
  return o
end

local function veins(g, mode)
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      if g[y][x] == 'J' and (mode == 'all' or (x + y) % 2 == 0) then g[y][x] = 'Y' end
    end
  end
end

-- Desfaz de fora para dentro: o que passa do limiar some; parte vira faisca no lugar.
local function erode(g, sg, t, prev)
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      if g[y][x] ~= '.' then
        local d = math.sqrt(((x - 13.5) / 13) ^ 2 + ((y - 14) / 11.5) ^ 2) + (hash(x, y, 7) % 100) / 100 * 0.24 - 0.12
        if d > t then
          g[y][x] = '.'
          local m = d <= prev and 3 or 7
          if hash(x, y, 3) % m == 0 then sg[y][x] = hash(x, y, 4) % 3 == 0 and 's' or 'S' end
        end
      end
    end
  end
end

local function split(g, sg)
  local b, l, w = L.grid(g.w, g.h), L.grid(g.w, g.h), L.grid(g.w, g.h)
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      local c = g[y][x]
      if c == 'H' then b[y][x] = 'h'; l[y][x] = 'H'
      elseif c == 'I' then b[y][x] = 'i'; l[y][x] = 'I'
      elseif c == 'J' or c == 'Y' then b[y][x] = 'j'; w[y][x] = c
      elseif c == 'V' then b[y][x] = 'v'; w[y][x] = 'V'
      else b[y][x] = c end
      local s = sg and sg[y][x]
      if s and s ~= '.' then w[y][x] = s end
    end
  end
  return b, l, w
end

local function frame(o)
  local sg = L.grid(W, H)
  local g = L.grid(W, H)
  if not o.nobody then
    g = compose(o.l or 0, o.r or o.l or 0)
    if o.veins then veins(g, o.veins) end
    if o.dark then
      for y = 0, H - 1 do for x = 0, W - 1 do
        if g[y][x] ~= '.' and not ('HIJYV'):find(g[y][x], 1, true) then g[y][x] = 'C' end
      end end
    end
    if o.erode then erode(g, sg, o.erode[1], o.erode[2]) end
    g = move(g, o.lean, o.dy or 0)
    L.outline(g, 'A')
  end
  for _, p in ipairs(o.sparks or {}) do L.set(sg, p[1], p[2], p[3] or 'S') end
  local b, l, w = split(g, sg)
  return { b = b, l = l, w = w, dy = o.dy or 0, body = not o.nobody }
end

-- Ajudas de faisca.
local function mir(list)
  local o = {}
  for _, p in ipairs(list) do o[#o + 1] = p; o[#o + 1] = { 27 - p[1], p[2], p[3] } end
  return o
end
local function plus(x, y)
  return { { x, y, 's' }, { x - 1, y }, { x + 1, y }, { x, y - 1 }, { x, y + 1 } }
end
local function cat(...)
  local o = {}
  for _, t in ipairs({ ... }) do for _, p in ipairs(t) do o[#o + 1] = p end end
  return o
end
local function ring(n, r, phase)
  local o = {}
  for k = 0, n - 1 do
    local a = math.rad(phase + k * 360 / n)
    o[#o + 1] = { 13.5 + r * math.cos(a), 14 + r * 0.9 * math.sin(a), k % 2 == 0 and 's' or 'S' }
  end
  return o
end
local function outlineSparks()
  local g = compose(2, 2)
  L.outline(g, 'A')
  local o = {}
  for y = 0, H - 1 do for x = 0, W - 1 do
    if g[y][x] == 'A' and hash(x, y, 1) % 2 == 0 then o[#o + 1] = { x, y, hash(x, y, 2) % 4 == 0 and 's' or 'S' }
    elseif g[y][x] ~= '.' and g[y][x] ~= 'A' and hash(x, y, 2) % 9 == 0 then o[#o + 1] = { x, y } end
  end end
  return o
end
local function cloud(m, scale)
  local g = compose(0, 0)
  local o = {}
  for y = 0, H - 1 do for x = 0, W - 1 do
    if g[y][x] ~= '.' and hash(x, y, 5) % m == 0 then
      o[#o + 1] = { 13.5 + (x - 13.5) * scale, 14 + (y - 14) * scale, hash(x, y, 6) % 3 == 0 and 's' or 'S' }
    end
  end end
  return o
end

local ANIMS = {
  { name = 'idle', fps = 8, frames = {
    frame { l = 0, dy = 0 }, frame { l = 1, dy = -1 }, frame { l = 2, dy = -1 }, frame { l = 1, dy = 0 },
  } },
  { name = 'drift', fps = 8, frames = {
    frame { l = 0, r = 1, lean = true, dy = 0 }, frame { l = 1, r = 2, lean = true, dy = -1 },
    frame { l = 2, r = 2, lean = true, dy = -1 }, frame { l = 1, r = 1, lean = true, dy = 0 },
  } },
  { name = 'alert', fps = 6, frames = {
    frame { l = 0 },
    frame { l = 0, veins = 'alt', sparks = mir { { 1, 22 }, { 6, 22 } } },
    frame { l = 0, veins = 'all', sparks = mir(cat(plus(1, 23), plus(6, 23), { { 9, 24 }, { 0, 14 }, { 4, 10 } })) },
  } },
  { name = 'flee', fps = 12, frames = {
    frame { l = 2, dy = 1, veins = 'all' },
    frame { l = 0, r = 1, lean = true, dy = 0, veins = 'alt', sparks = { { 10, 27 }, { 8, 26, 's' } } },
    frame { l = 1, r = 2, lean = true, dy = -1, sparks = { { 11, 26, 's' }, { 9, 27 }, { 7, 25 }, { 5, 27 } } },
    frame { l = 0, r = 1, lean = true, dy = -2, veins = 'alt',
      sparks = cat(plus(10, 25), { { 7, 27 }, { 5, 25 }, { 3, 27 }, { 13, 27 } }) },
    frame { l = 1, r = 2, lean = true, dy = -2,
      sparks = { { 11, 24, 's' }, { 9, 26 }, { 6, 26, 's' }, { 4, 24 }, { 2, 26 }, { 8, 23 } } },
    frame { l = 2, r = 2, lean = true, dy = -2, sparks = { { 10, 25 }, { 7, 24 }, { 4, 26 }, { 1, 25, 's' }, { 12, 26 } } },
  } },
  { name = 'spawn', fps = 10, frames = {
    frame { nobody = true, sparks = ring(6, 12, 20) },
    frame { nobody = true, sparks = cat(ring(8, 8, 0), ring(4, 12, 65), plus(14, 14)) },
    frame { nobody = true, sparks = cat(outlineSparks(), plus(13, 14), plus(14, 14)) },
    frame { l = 2, dark = true, veins = 'all', sparks = ring(6, 10, 40) },
    frame { l = 1, veins = 'alt', sparks = ring(4, 12, 10) },
    frame { l = 0, sparks = { { 3, 7 }, { 24, 24 } } },
  } },
  { name = 'tuned', fps = 10, frames = {
    frame { l = 0, veins = 'all', sparks = mir { { 1, 22 }, { 0, 15 } } },
    frame { l = 0, veins = 'all', erode = { 0.80, 9 } },
    frame { l = 0, veins = 'all', erode = { 0.55, 0.80 } },
    frame { l = 0, veins = 'all', erode = { 0.30, 0.55 } },
    frame { nobody = true, sparks = cloud(5, 1) },
    frame { nobody = true, sparks = cat(cloud(10, 0.5), plus(14, 14)) },
  } },
}

-- Saida.
local function rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end
local function image(g, legend)
  local img = Image(g.w, g.h, ColorMode.RGB)
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = g[y][x]
    if c ~= '.' then
      if not legend[c] then error('sem cor: ' .. c) end
      local r, gg, b = rgb(legend[c])
      img:putPixel(x, y, app.pixelColor.rgba(r, gg, b, 255))
    end
  end end
  return img
end
local function savePng(img, path)
  local s = Sprite(img.width, img.height, ColorMode.RGB)
  s:newCel(s.layers[1], 1, img, Point(0, 0))
  s:saveCopyAs(path)
  s:close()
end
-- frames: { b=, l=, w=, ms= }; tags: { name=, from=, to= }.
local function saveSprite(path, w, h, frames, tags)
  local spr = Sprite(w, h, ColorMode.RGB)
  local lb = spr.layers[1]; lb.name = 'corpo'
  local ll = spr:newLayer(); ll.name = 'leds'
  local lg = spr:newLayer(); lg.name = 'glow'
  for n, f in ipairs(frames) do
    if n > 1 then spr:newEmptyFrame() end
    spr.frames[n].duration = f.ms / 1000
    spr:newCel(lb, n, image(f.b, LEG), Point(0, 0))
    spr:newCel(ll, n, image(f.l, LEG), Point(0, 0))
    spr:newCel(lg, n, image(f.w, LEG), Point(0, 0))
  end
  for _, t in ipairs(tags) do
    local tag = spr:newTag(t.from, t.to); tag.name = t.name
  end
  spr:saveAs(path)
  spr:close()
end
local function strips(base, frames)
  local b, l, w = {}, {}, {}
  for n, f in ipairs(frames) do b[n] = f.b; l[n] = f.l; w[n] = f.w end
  savePng(image(L.sheet(b), LEG), base .. '.png')
  savePng(image(L.sheet(l), LEG), base .. '_leds.png')
  savePng(image(L.sheet(w), LEG), base .. '_glow.png')
end

do
  local all, tags, n = {}, {}, 0
  for _, a in ipairs(ANIMS) do
    tags[#tags + 1] = { name = a.name, from = n + 1, to = n + #a.frames }
    for _, f in ipairs(a.frames) do n = n + 1; f.ms = 1000 / a.fps; all[n] = f end
    strips(DIR .. 'humoth_' .. a.name, a.frames)
  end
  saveSprite(DIR .. 'humoth.aseprite', W, H, all, tags)
end

-- Variantes: troca de cor do corpo (ordem de BODY_KEYS) e acessorio sobre o quadro 0 do idle.
local VARIANTS = {
  { key = 'urban', -- cinza de concreto, mais escuro que a base; duas bracadeiras claras no abdomen
    ramp = { '#22242D', '#31343F', '#2A2D38', '#3C404E', '#666B7C', '#202228', '#393C48', '#565A6A', '#8E92A0', '#B6BAC4' },
    legend = { W = '#B6BAC4', w = '#8E92A0' },
    put = { { 11, 18, { 'WWWWWw' } }, { 11, 21, { 'WWWWWw' } } } },
  { key = 'green', -- musgo de valor medio; gola de duas folhas claras
    ramp = { '#2A4530', '#3E6444', '#35553A', '#4C7650', '#7AA870', '#2A3D2C', '#466246', '#668A60', '#A8C890', '#D4EAC0' },
    legend = { L = '#8AB874', l = '#5FB26A', d = '#2F7446' }, outline = true,
    put = { { 8, 8, { '.LL..', 'LLlll', '..ddd' } }, { 15, 8, { '..LL.', 'lllLL', 'ddd..' } } } },
  { key = 'water', -- azul-petroleo escuro; colar de contas claro em V com uma gota pendurada
    ramp = { '#0C2231', '#123044', '#0F2B3E', '#143A52', '#2A6484', '#0E2230', '#1A3E52', '#2A5A72', '#5A9AB8', '#9CD0E8' },
    legend = { U = '#E8F8FF', u = '#9FD4F0', v = '#5A9AB8' },
    put = { { 10, 9, { 'u......u', '.u....u.', '..uUUu..', '...Uu...', '...uv...' } } } },
  { key = 'residential', -- bege de cimentado, claro; cachecol telha escuro com a ponta solta
    ramp = { '#614838', '#84644F', '#75584A', '#96745F', '#C8A888', '#5A4236', '#80624E', '#A4846A', '#DCC4A4', '#F2E4CC' },
    legend = { O = '#A03C2C', o = '#6E261E' }, outline = true,
    put = { { 10, 9, { 'OOOOOOoo', '......Oo', '......Oo', '......oo' } } } },
  { key = 'lit', -- creme de vitrine, a mais clara; gravata-borboleta escura
    ramp = { '#8E887C', '#B2AC9E', '#A6A094', '#C4BEB0', '#F0ECE0', '#807A70', '#AAA498', '#D0CABC', '#FBF8EE', '#FFFFFF' },
    legend = { N = '#2B2F3D', M = '#40465A' },
    put = { { 10, 8, { 'NN....NN', 'NNNMMNNN', 'NN....NN' } } } },
  { key = 'sacred', -- lilas de pedra, claro; aureola dourada palida em volta da cabeca
    ramp = { '#69648A', '#8A84A6', '#7C7698', '#9A94B4', '#C8C2DC', '#5C5674', '#8882A2', '#AAA4C0', '#DED8F0', '#F4F0FF' },
    legend = { G = '#F2E6B0', g = '#C8B878' }, outline = true,
    put = { { 10, 5, { '.GGGGGG.', 'G......G', 'G......G', '.gggggg.' } } } },
  { key = 'crimson', -- vinho quase preto, a mais escura; crescente da Lua Carmim no torax
    ramp = { '#260C16', '#3A1220', '#300F1C', '#4A1626', '#8A2A3C', '#22101A', '#4A1A28', '#6E2636', '#B8404E', '#E87080' },
    legend = { R = '#FF5A6A', r = '#C03048' },
    put = { { 12, 11, { '.RR.', 'Rr..', 'R...', 'Rr..', '.RR.' } } } },
}
do
  local spr = Sprite(W, H, ColorMode.RGB)
  local out = { '{' }
  for n, v in ipairs(VARIANTS) do
    local g = L.grid(W, H)
    for _, p in ipairs(v.put) do L.put(g, p[1], p[2], p[3]) end
    if v.outline then L.outline(g, 'A') end
    v.legend.A = LEG.A
    v.acc = g
    v.map = {}
    local pairsOut = {}
    for k, ch in ipairs(BODY_KEYS) do
      v.map[LEG[ch]:lower()] = v.ramp[k]:lower()
      pairsOut[#pairsOut + 1] = string.format('"%s": "%s"', LEG[ch]:lower(), v.ramp[k]:lower())
    end
    local img = image(g, v.legend)
    savePng(img, DIR .. 'humoth_acc_' .. v.key .. '.png')
    if n > 1 then spr:newEmptyFrame() end
    spr:newCel(spr.layers[1], n, img, Point(0, 0))
    local tag = spr:newTag(n, n); tag.name = v.key
    out[#out + 1] = string.format('  "%s": { "map": { %s }, "accessory": "humoth_acc_%s.png" }%s',
      v.key, table.concat(pairsOut, ', '), v.key, n < #VARIANTS and ',' or '')
  end
  out[#out + 1] = '}'
  spr:saveAs(DIR .. 'humoth_acc.aseprite'); spr:close()
  local f = assert(io.open(DIR .. 'humoth_variants.json', 'w'))
  f:write(table.concat(out, '\n') .. '\n'); f:close()
end

-- Retrato: o conceito de 96 px, com corpo, miolo da asa e ponta da asa subindo em passos diferentes.
local PFPS = 6
local PBODY = { 0, -1, -1, 0 }
local PIN = { 0, -1, -2, -1 }
local PTIP = { 1, -1, -3, -1 }
do
  local src = Sprite { fromFile = DIR .. 'humoth_portrait_src.aseprite' }
  local simg = Image(src.spec); simg:drawSprite(src, 1)
  local rev = {}
  for _, ch in ipairs({ 'A', 'B', 'T', 'C', 'D', 'R', 'G', 'F', 'E', 'P', 'Q', 'h', 'H', 'I', 'J', 'Y' }) do rev[LEG[ch]] = ch end
  rev['#FFD84A'] = 'J'; rev['#FFF3A8'] = 'Y' -- o conceito de origem ainda tem os amarelos antigos: saem na cor da paleta
  local S = 96
  local base = L.grid(S, S)
  for y = 0, S - 1 do for x = 0, S - 1 do
    local p = simg:getPixel(x, y)
    if app.pixelColor.rgbaA(p) > 0 then
      local hex = string.format('#%02X%02X%02X', app.pixelColor.rgbaR(p), app.pixelColor.rgbaG(p), app.pixelColor.rgbaB(p))
      base[y][x] = rev[hex] or error('cor fora da legenda: ' .. hex)
    end
  end end
  src:close()
  -- A costura do Veu, no mesmo lugar do mapa: 1 px em diagonal no abdomen (dentro da faixa que sobe com o corpo).
  for n = 0, 17 do
    local x, y = 39 + n, 50 + n
    if ('CDR'):find(base[y][x], 1, true) then base[y][x] = 'V' end
  end
  -- Faiscas soltas: grupos de amarelo que nao encostam no corpo.
  local comp, ncomp, spark = {}, 0, {}
  local function yellow(x, y) local c = L.get(base, x, y); return c == 'J' or c == 'Y' end
  for y = 0, S - 1 do for x = 0, S - 1 do
    if yellow(x, y) and not comp[y * S + x] then
      ncomp = ncomp + 1
      local stack, touches = { { x, y } }, false
      comp[y * S + x] = ncomp
      while #stack > 0 do
        local q = table.remove(stack)
        for dy = -1, 1 do for dx = -1, 1 do
          local nx, ny = q[1] + dx, q[2] + dy
          local c = L.get(base, nx, ny)
          if yellow(nx, ny) then
            if not comp[ny * S + nx] then comp[ny * S + nx] = ncomp; stack[#stack + 1] = { nx, ny } end
          elseif c ~= '.' then touches = true end
        end end
      end
      spark[ncomp] = not touches
    end
  end end
  local frames = {}
  for f = 1, 4 do
    local g, sg = L.grid(S, S), L.grid(S, S)
    for y = 0, S - 1 do for x = 0, S - 1 do
      local c = base[y][x]
      local k = comp[y * S + x]
      if c ~= '.' and k and spark[k] then
        if (k + f) % 4 ~= 0 then sg[y][x] = (c == 'Y' or (k + f) % 4 == 2) and 's' or 'S' end
      elseif c ~= '.' then
        local d = math.abs(x - 47.5)
        local off = (y < 22 or d < 12.5) and PBODY[f] or (d < 33 and PIN[f] or PTIP[f])
        if c == 'J' or c == 'Y' then c = ((x + 2 * y + f * 3) % 12 < 2) and 'Y' or 'J' end
        if c == 'H' or c == 'I' then
          local dot = L.get(base, x - 1, y) == 'h' and L.get(base, x + 1, y) == 'h'
          if dot then c = (c == 'I' or ((y // 2) + f) % 3 == 0) and 'I' or 'H' else c = 'H' end
        end
        L.set(g, x, y + off, c)
      end
    end end
    local b, l, w = split(g, sg)
    frames[f] = { b = b, l = l, w = w, ms = 1000 / PFPS }
  end
  strips(DIR .. 'humoth_portrait', frames)
  saveSprite(DIR .. 'humoth_portrait.aseprite', S, S, frames, { { name = 'hover', from = 1, to = 4 } })
end

-- humoth.json
do
  local an, dy, vis = {}, {}, {}
  for _, a in ipairs(ANIMS) do
    local d, v = {}, {}
    for n, f in ipairs(a.frames) do d[n] = tostring(f.dy); v[n] = f.body and '1' or '0' end
    an[#an + 1] = string.format('    "%s": { "frames": %d, "fps": %d }', a.name, #a.frames, a.fps)
    dy[#dy + 1] = string.format('    "%s": [%s]', a.name, table.concat(d, ', '))
    vis[#vis + 1] = string.format('    "%s": [%s]', a.name, table.concat(v, ', '))
  end
  local f = assert(io.open(DIR .. 'humoth.json', 'w'))
  f:write('{\n  "frame": 28,\n  "anims": {\n' .. table.concat(an, ',\n') .. '\n  },\n  "body_dy": {\n'
    .. table.concat(dy, ',\n') .. '\n  },\n  "body_visible": {\n' .. table.concat(vis, ',\n')
    .. '\n  },\n  "portrait": { "frame": 96, "frames": 4, "fps": ' .. PFPS .. ' }\n}\n')
  f:close()
end

-- Folha de conferencia: 6 fileiras de animacao (corpo com o tom da noite, leds e glow por cima), depois as
-- variantes (base, urban, green, water, residential, lit, sacred, crimson) em cor, em cinza e com o tom da noite.
do
  local PITCH, M, K = 30, 4, 4
  local CW, CH = M * 2 + PITCH * 8 - 2, M * 2 + PITCH * 9 - 2
  local NIGHT, NA = { 0x14, 0x10, 0x33 }, 0.58
  local function night(c)
    return { c[1] * (1 - NA) + NIGHT[1] * NA, c[2] * (1 - NA) + NIGHT[2] * NA, c[3] * (1 - NA) + NIGHT[3] * NA }
  end
  local cv = {}
  for y = 0, CH - 1 do
    cv[y] = {}
    for x = 0, CW - 1 do
      local hx = '#343949'
      if hash(x, y, 11) % 23 == 0 then hx = '#2B2F3D' elseif hash(x, y, 12) % 31 == 0 then hx = '#40465A' end
      cv[y][x] = night({ rgb(hx) })
    end
  end
  local function cell(col, row, f, v, tint)
    local ox, oy = M + col * PITCH, M + row * PITCH
    for y = 0, H - 1 do for x = 0, W - 1 do
      local c = f.b[y][x]
      local px
      if c ~= '.' then
        local hex = LEG[c]
        if v and v.map[hex:lower()] then hex = v.map[hex:lower()] end
        px = { rgb(hex) }
      end
      if v and f.body then
        local a = L.get(v.acc, x, y - f.dy)
        if a ~= '.' then px = { rgb(v.legend[a]) } end
      end
      if px and tint then px = night(px) end
      if f.l[y][x] ~= '.' then px = { rgb(LEG[f.l[y][x]]) } end
      if f.w[y][x] ~= '.' then px = { rgb(LEG[f.w[y][x]]) } end
      if px then cv[oy + y][ox + x] = px end
    end end
  end
  for r, a in ipairs(ANIMS) do
    for n, f in ipairs(a.frames) do cell(n - 1, r - 1, f, nil, true) end
  end
  local idle0 = ANIMS[1].frames[1]
  for r = 6, 8 do
    cell(0, r, idle0, nil, r == 8)
    for n, v in ipairs(VARIANTS) do cell(n, r, idle0, v, r == 8) end
  end
  for y = M + 7 * PITCH - 1, M + 8 * PITCH - 2 do
    for x = 0, CW - 1 do
      local c = cv[y][x]
      local lum = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
      cv[y][x] = { lum, lum, lum }
    end
  end
  local img = Image(CW * K, CH * K, ColorMode.RGB)
  for y = 0, CH - 1 do for x = 0, CW - 1 do
    local c = cv[y][x]
    local p = app.pixelColor.rgba(math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5), 255)
    for j = 0, K - 1 do for i = 0, K - 1 do img:putPixel(x * K + i, y * K + j, p) end end
  end end
  local s = Sprite(img.width, img.height, ColorMode.RGB)
  s:newCel(s.layers[1], 1, img, Point(0, 0))
  s:saveAs(DIR .. 'humoth_folha.aseprite')
  s:saveCopyAs(DIR .. 'humoth_folha.png')
  s:close()
end
print('ok humoth')
