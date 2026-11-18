-- Tráfego comum (0.25.1), na grade de 2 dp: carros, moto, ciclista e ônibus vistos de cima (frente para a direita)
-- e os passantes de pé (2 quadros), com as roupas de clima em camadas. Rodar: aseprite -b --script build.lua
-- As cores são chaves por papel (traffic_keys.json): o código troca cada hex pela cor da paleta do fantasma.
local S = dofile('/home/yuri/Documentos/kenoma/tools/art/traffic/_strip.lua')
local L = S.L
local DIR = L.ROOT .. 'traffic/'
local OUT = '#1A1424'

local LEG = {
  o = OUT,
  -- veículos
  b = '#B8BCC8', a = '#8E92A4', d = '#6A6E82', g = '#BFE9F0', G = '#7FB4C4', y = '#FFE8A3', r = '#E0524A', k = '#3A2F4A',
  L = '#FFE2A0',
  -- gente
  h = '#6B4A2F', H = '#4A3220', s = '#F0C9A6', S = '#D9A47C', e = '#2B2540',
  t = '#6C7FB8', T = '#4E5C8A', p = '#4A5578', P = '#363E5A', u = '#E8C14A', U = '#B8943A', n = '#A9824F',
  -- roupas de clima
  w = '#8A3B6B', W = '#5E2848', x = '#8A8FA3', c = '#5FA8D3', C = '#3F7FA8', j = '#7A5A3F', J = '#55402C',
  m = '#B8484A', M = '#8A3234', f = '#E8A04A', F = '#B8782F', q = '#D8B45A', Q = '#A8883C', z = '#EEEAF8', Z = '#C4C0D4',
  l = '#B5BEDB', i = '#8E9AC0', v = '#F3E0A4', V = '#D0B870',
}

local ART = {}

-- ---------------------------------------------------------------------------------------------- vistos de cima

-- Casca arredondada de W x H com contorno, pneus na beira e retrovisores; o miolo vem de paint(x, y).
local function shell(W, H, paint, tires, mirror)
  local g = L.grid(W + 2, H + 4)
  local function inS(x, y)
    if x < 0 or y < 0 or x >= W or y >= H then return false end
    return math.min(x, W - 1 - x) + math.min(y, H - 1 - y) >= 2
  end
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      if inS(x, y) then
        local inner = inS(x - 1, y) and inS(x + 1, y) and inS(x, y - 1) and inS(x, y + 1)
        g[2 + y][1 + x] = inner and paint(x, y) or 'o'
      end
    end
  end
  for _, t in ipairs(tires) do
    for x = t, t + (tires.len or 3) - 1 do g[2][1 + x] = 'k'; g[1 + H][1 + x] = 'k' end
  end
  for x = mirror, mirror + 1 do g[1][1 + x] = 'o'; g[2 + H][1 + x] = 'o' end
  return g
end

-- zones: { x0, x1, 'rear' | 'front' | 'roof' | 'seam' | 'bed', pillars = {...} }, o resto é corpo.
local function car(W, H, zones, tires, mirror)
  local s1, s2 = 2, H - 3
  return shell(W, H, function(x, y)
    local lamp = y <= 3 or y >= H - 4
    if x == 1 then return lamp and 'r' or 'd' end
    if x == W - 2 then return lamp and 'y' or 'd' end
    local side = y < s1 or y > s2
    for _, q in ipairs(zones) do
      local x0, x1, kind = q[1], q[2], q[3]
      if x >= x0 and x <= x1 then
        if kind == 'bed' then
          if y < 3 or y > H - 4 then return 'b' end
          return (x - x0) % 3 == 2 and 'a' or 'd'
        end
        if side then return 'b' end
        if kind == 'seam' then return 'd' end
        if kind == 'roof' then
          if y > s1 and y < s2 then return 'a' end
          if x == x0 or x == x1 then return 'a' end
          for _, m in ipairs(q.pillars or {}) do if x == m then return 'a' end end
          return 'G'
        end
        local near = kind == 'rear' and x1 or x0  -- a coluna do vidro que encosta no teto
        if x0 ~= x1 and x == near then return (y == s1 or y == s2) and 'a' or 'G' end
        return 'g'
      end
    end
    return 'b'
  end, tires, mirror)
end

local function top(name, g, glow)
  S.check(name, g)
  local layers = { { name = 'base', frames = { g }, png = DIR .. name .. '.png' } }
  if glow then layers[2] = { name = 'glow', frames = { glow }, png = DIR .. name .. '_glow.png', hidden = true } end
  S.save(DIR .. name, LEG, layers)
  ART[name] = { g = g, glow = glow }
end

local function lamps(g) return S.pick(g, 'yr') end

do
  local g = car(21, 11, { { 3, 4, 'rear' }, { 5, 11, 'roof', pillars = { 8 } }, { 12, 14, 'front' }, { 15, 15, 'seam' } }, { 3, 14 }, 13)
  top('hatch', g, lamps(g))
  g = car(24, 11, { { 5, 5, 'seam' }, { 6, 7, 'rear' }, { 8, 14, 'roof', pillars = { 11 } }, { 15, 17, 'front' }, { 18, 18, 'seam' } }, { 4, 17 }, 16)
  top('sedan', g, lamps(g))
  g = car(26, 12, { { 3, 11, 'bed' }, { 13, 13, 'rear' }, { 14, 18, 'roof', pillars = { 16 } }, { 19, 20, 'front' }, { 21, 21, 'seam' } }, { 4, 19 }, 19)
  top('pickup', g, lamps(g))
  g = car(24, 12, { { 3, 4, 'rear' }, { 5, 14, 'roof', pillars = { 8, 11 } }, { 15, 17, 'front' }, { 18, 18, 'seam' } }, { 4, 17 }, 16)
  L.rect(g, 7, 5, 14, 5, 'd'); L.rect(g, 7, 10, 14, 10, 'd')  -- longarinas do bagageiro
  L.rect(g, 11, 7, 13, 8, 'G')                                -- teto solar
  top('suv', g, lamps(g))
end

do
  local g = L.grid(20, 11)
  L.put(g, 2, 2, L.frame({
    '.......ttttsd...',
    '.....ttttoood...',
    '..ddbthhhtbbd...',
    'kkkrbthhhgaadykk',
    '..ddbthhhtbbd...',
    '.....ttttoood...',
    '.......ttttsd...',
  }, 16, 7, 'moto') and {
    '.......ttttsd...',
    '.....ttttoood...',
    '..ddbthhhtbbd...',
    'kkkrbthhhgaadykk',
    '..ddbthhhtbbd...',
    '.....ttttoood...',
    '.......ttttsd...',
  })
  L.outline(g, 'o')
  top('moto', g, lamps(g))

  g = L.grid(17, 9)
  L.put(g, 2, 2, {
    '....tttttsd..',
    '....thhhtod..',
    'kkkbthhhtbdkk',
    '....thhhtod..',
    '....tttttsd..',
  })
  L.outline(g, 'o')
  top('cyclist', g, nil)
end

-- Ônibus comum: 53 x 15 (2,2 carros). Janelas na beira do teto, portas do lado direito (embaixo, na mão brasileira),
-- ar-condicionado atrás, dois alçapões, para-brisa e letreiro na frente.
do
  local W, H = 53, 15
  local g = shell(W, H, function(x, y)
    local lamp = y <= 3 or y >= 11
    if x == 1 then return lamp and 'r' or 'd' end
    if x == 51 then
      if lamp then return 'y' end
      return (y >= 5 and y <= 9) and 'a' or 'd'
    end
    if x >= 48 then
      if y == 1 or y == 13 then return 'b' end
      if x == 48 then return (y == 2 or y == 12) and 'a' or 'G' end
      return 'g'
    end
    if y == 1 or y == 13 then
      if x < 3 or x > 46 then return 'b' end
      if y == 13 and ((x >= 18 and x <= 21) or (x >= 38 and x <= 41)) then return 'a' end
      return (x - 3) % 4 < 3 and 'g' or 'd'
    end
    if y == 2 or y == 12 or x == 47 then return 'a' end
    if x >= 5 and x <= 11 and y >= 4 and y <= 10 then
      if x == 5 or x == 11 or y == 4 or y == 10 then return 'd' end
      return (y % 2 == 0 and x >= 7 and x <= 9) and 'd' or 'a'
    end
    for _, hx in ipairs({ 18, 30 }) do
      if x >= hx and x <= hx + 4 and y >= 5 and y <= 9 then
        return (x == hx or x == hx + 4 or y == 5 or y == 9) and 'a' or 'd'
      end
    end
    if x == 14 or x == 26 or x == 38 then return 'a' end
    return 'b'
  end, { 7, 39, len = 4 }, 49)
  -- Aceso: as janelas dos lados (não o para-brisa), o letreiro, os faróis e as lanternas.
  local glow = S.pick(g, 'yr')
  for x = 3, 46 do
    for _, y in ipairs({ 1, 13 }) do if g[2 + y][1 + x] == 'g' then glow[2 + y][1 + x] = 'L' end end
  end
  for y = 5, 9 do glow[2 + y][1 + 51] = 'L' end
  top('bus_city', g, glow)
end

-- ---------------------------------------------------------------------------------------------- passantes de pé

-- Adulto: miolo de 9 x 18 (11 x 20 com o contorno). Cabeça 6 linhas, tronco 6, pernas 6. Luz da esquerda.
local HEAD_A = { '..hhhhh..', '.hhhhhhh.', '.hhhhhHH.', '.hssssSH.', '.ssesesS.', '..sssSS..' }
local HEAD_C = { '.hhhh.', 'hhhhhH', 'hssssH', 'sesseS', '.sssS.' }

-- f: armL, armR (linha da mão), legL, legR (linha do sapato), hx, hy (deslocamento da cabeça), cane (linha da ponta).
local function adult(g, ox, oy, f)
  for y = 6, 11 do L.put(g, ox, oy + y, { '.ttttttT.' }) end
  for y = 7, f.armL - 1 do g[oy + y][ox] = 't' end
  g[oy + f.armL][ox] = 's'
  for y = 7, f.armR - 1 do g[oy + y][ox + 8] = 'T' end
  g[oy + f.armR][ox + 8] = 'S'
  L.put(g, ox, oy + 12, { '.pppppPP.' })
  for y = 13, f.legL - 1 do L.put(g, ox, oy + y, { '.ppp.....' }) end
  L.put(g, ox, oy + f.legL, { '.kkk.....' })
  for y = 13, f.legR - 1 do L.put(g, ox, oy + y, { '.....pPP.' }) end
  L.put(g, ox, oy + f.legR, { '.....kkk.' })
  L.put(g, ox + (f.hx or 0), oy + (f.hy or 0), HEAD_A)
  if f.cane then for y = 9, f.cane do g[oy + y][ox + 9] = 'n' end end
  return { ox = ox, oy = oy, X = ox + (f.hx or 0), Y = oy + (f.hy or 0) }
end

-- Criança: miolo de 6 x 12 (8 x 14 com o contorno). raised: a mão esquerda erguida, na mão do adulto.
local function child(g, cx, cy, f)
  L.put(g, cx, cy, HEAD_C)
  for y = 5, 7 do L.put(g, cx, cy + y, { 'uuuuuU' }) end
  g[cy + 7][cx + 5] = 'S'
  if f.raised then g[cy + 5][cx - 1] = 's' else g[cy + 7][cx] = 's' end
  L.put(g, cx, cy + 8, { '.pppP.' })
  for y = 9, f.legL - 1 do L.put(g, cx, cy + y, { '.pp...' }) end
  L.put(g, cx, cy + f.legL, { '.kk...' })
  for y = 9, f.legR - 1 do L.put(g, cx, cy + y, { '....pP' }) end
  L.put(g, cx, cy + f.legR, { '....kk' })
  return { cx = cx, cy = cy }
end

local function setIf(g, x, y, from, to) if L.get(g, x, y) == from then g[y][x] = to end end

-- As peças no adulto (o: ox, oy do corpo; X, Y da cabeça).
local PA = {
  umbrella = function(g, o)
    L.put(g, o.X - 2, o.Y - 8, {
      '....wwwww....',
      '..wwwwWwwww..',
      '.wwWwwWwwWww.',
      'wwwWwwWwwWwww',
      'wwWwwwWwwwWww',
      'WW.WWW.WWW.WW',
      '......x......',
      '......x......',
    })
  end,
  raincoat = function(g, o)
    S.swap(g, o.ox, o.oy + 6, o.ox + 8, o.oy + 11, { t = 'c', T = 'C' })
    L.put(g, o.ox, o.oy + 12, { '.cccccCC.', '.cccccCC.', '.cccccCC.' })
    L.put(g, o.X, o.Y - 1, { '...ccc...', '..ccccc..', '.ccccccC.', '.ccccccC.', '.c.....C.' })
  end,
  coat = function(g, o)
    S.swap(g, o.ox, o.oy + 6, o.ox + 8, o.oy + 11, { t = 'j', T = 'J' })
    L.put(g, o.ox, o.oy + 12, { '.jjjjjJJ.', '.jjjjjJJ.' })
    for y = 7, 13 do setIf(g, o.ox + 4, o.oy + y, 'j', 'J') end
    setIf(g, o.ox + 3, o.oy + 6, 'j', 'J'); setIf(g, o.ox + 5, o.oy + 6, 'j', 'J')
  end,
  beanie = function(g, o) L.put(g, o.X, o.Y - 1, { '...mmm...', '..mmmmm..', '.mmmmmmM.', '.MmMmMmM.' }) end,
  scarf = function(g, o)
    L.put(g, o.X, o.Y + 6, { '.ffffffF.' })
    g[o.Y + 7][o.X + 5] = 'f'; g[o.Y + 8][o.X + 5] = 'F'
  end,
  light = function(g, o)
    S.swap(g, o.ox + 1, o.oy + 6, o.ox + 7, o.oy + 11, { t = 'l', T = 'i' })
    S.swap(g, o.ox, o.oy + 7, o.ox + 8, o.oy + 7, { t = 'l', T = 'i' })
    S.swap(g, o.ox, o.oy + 8, o.ox + 8, o.oy + 11, { t = 's', T = 'S' })
    S.swap(g, o.ox, o.oy + 15, o.ox + 8, o.oy + 16, { p = 's', P = 'S' })
  end,
  cap = function(g, o) L.put(g, o.X, o.Y, { '..qqqqq..', '.qqqqqqQ.', '.QQQQQQQ.' }) end,
  hat = function(g, o) L.put(g, o.X - 1, o.Y - 1, { '....qqq....', '...qqqqq...', '...QQQQQ...', 'qqqqqqqqqQQ' }) end,
  mask = function(g, o) L.put(g, o.X, o.Y + 5, { '..zzzZZ..' }) end,
}

-- As peças na criança (o guarda-chuva é só do adulto).
local PC = {
  raincoat = function(g, o)
    S.swap(g, o.cx, o.cy + 5, o.cx + 5, o.cy + 7, { u = 'c', U = 'C' })
    L.put(g, o.cx, o.cy + 8, { '.cccC.', '.cccC.' })
    L.put(g, o.cx, o.cy - 1, { '..cc..', '.cccc.', 'cccccC', 'c....C' })
  end,
  coat = function(g, o)
    S.swap(g, o.cx, o.cy + 5, o.cx + 5, o.cy + 7, { u = 'j', U = 'J' })
    L.put(g, o.cx, o.cy + 8, { '.jjjJ.' })
    for y = 6, 8 do setIf(g, o.cx + 3, o.cy + y, 'j', 'J') end
  end,
  beanie = function(g, o) L.put(g, o.cx, o.cy - 1, { '..mm..', '.mmmm.', 'mMmMmM' }) end,
  scarf = function(g, o)
    L.put(g, o.cx, o.cy + 5, { 'ffffFF' })
    g[o.cy + 6][o.cx + 4] = 'f'
  end,
  light = function(g, o)
    S.swap(g, o.cx, o.cy + 5, o.cx + 5, o.cy + 7, { u = 'v', U = 'V' })
    setIf(g, o.cx, o.cy + 6, 'v', 's'); setIf(g, o.cx + 5, o.cy + 6, 'V', 'S')
    S.swap(g, o.cx, o.cy + 10, o.cx + 5, o.cy + 10, { p = 's', P = 'S' })
  end,
  cap = function(g, o) L.put(g, o.cx, o.cy, { '.qqqq.', 'QQQQQQ' }) end,
  hat = function(g, o) L.put(g, o.cx - 1, o.cy - 1, { '...qq...', '..QQQQ..', 'qqqqqqQQ' }) end,
  mask = function(g, o) L.put(g, o.cx, o.cy + 4, { '.zzzZ.' }) end,
}

local PIECES = { 'umbrella', 'raincoat', 'coat', 'beanie', 'scarf', 'light', 'cap', 'hat', 'mask' }

-- mk(f) desenha o quadro f (1 ou 2) numa grade nova e devolve a grade e as origens das peças.
local function model(name, mk)
  local base, info = {}, {}
  for f = 1, 2 do
    base[f], info[f] = mk(f)
    L.outline(base[f], 'o')
    S.check(name .. ' q' .. f, base[f])
  end
  local layers = { { name = 'body', frames = base, png = DIR .. name .. '.png' } }
  ART[name] = { base = base, comp = {} }
  for _, pn in ipairs(PIECES) do
    local fr, comp = {}, {}
    for f = 1, 2 do
      local c = S.copy(base[f])
      PA[pn](c, info[f].a)
      if info[f].c and PC[pn] then PC[pn](c, info[f].c) end
      L.outline(c, 'o')
      S.check(name .. ' ' .. pn .. ' q' .. f, c)
      comp[f], fr[f] = c, S.diff(c, base[f])
    end
    ART[name].comp[pn] = comp
    layers[#layers + 1] = { name = pn, frames = fr, png = DIR .. name .. '_' .. pn .. '.png', hidden = true }
  end
  S.save(DIR .. name, LEG, layers, 3)
end

model('ped_adult', function(f)
  local g = L.grid(17, 30)
  local a = adult(g, 4, 10, f == 1 and { armL = 10, armR = 9, legL = 17, legR = 16 } or { armL = 9, armR = 10, legL = 16, legR = 17 })
  return g, { a = a }
end)

-- A dupla: o adulto dá a mão direita (linha 11) para a criança, que anda no passo contrário.
model('ped_pair', function(f)
  local g = L.grid(23, 30)
  local a = adult(g, 4, 10, f == 1 and { armL = 10, armR = 11, legL = 17, legR = 16 } or { armL = 9, armR = 11, legL = 16, legR = 17 })
  local c = child(g, 14, 16, f == 1 and { raised = true, legL = 10, legR = 11 } or { raised = true, legL = 11, legR = 10 })
  return g, { a = a, c = c }
end)

-- O idoso: cabeça um pixel para a frente e para baixo (curvado), bengala na mão direita, que sai do chão no quadro 2.
model('ped_elder', function(f)
  local g = L.grid(17, 30)
  local a = adult(g, 5, 10, f == 1 and { armL = 10, armR = 10, legL = 17, legR = 16, hx = -1, hy = 1, cane = 17 }
    or { armL = 9, armR = 10, legL = 16, legR = 17, hx = -1, hy = 1, cane = 16 })
  return g, { a = a }
end)

-- ---------------------------------------------------------------------------------------------- folha de conferência

local function variant(over)
  local t = {}
  for k, v in pairs(LEG) do t[k] = v end
  if over.b then over.a = S.mix(over.b, OUT, 0.3); over.d = S.mix(over.b, OUT, 0.5) end
  for k, v in pairs(over) do t[k] = v end
  return t
end

do
  local items = {}
  local function put(a, x, y, leg) items[#items + 1] = { g = a.g, glow = a.glow, x = x, y = y, leg = leg or LEG } end
  local function ped(g, x, y, leg) items[#items + 1] = { g = g, x = x, y = y, leg = leg or LEG } end
  put(ART.hatch, 3, 2); put(ART.sedan, 30, 2); put(ART.pickup, 60, 2); put(ART.suv, 92, 2); put(ART.moto, 122, 4); put(ART.cyclist, 146, 5)
  put(ART.bus_city, 3, 21)
  -- As chaves trocadas, como o código faz: brasa, violeta, claro.
  put(ART.hatch, 62, 23, variant { b = '#FF7A45' })
  put(ART.sedan, 89, 23, variant { b = '#9B7BFF' })
  put(ART.suv, 119, 23, variant { b = '#E8E4F4' })
  put(ART.moto, 149, 25, variant { b = '#5FD3C6', h = '#FF7A45', t = '#3A2A2A' })
  local alt = variant { s = '#A8714C', S = '#7A4E34', h = '#2A2236', H = '#1F1A2A', t = '#5FD3C6', T = '#3F9A92', u = '#FF7A45', U = '#C2552B', p = '#55506A', P = '#3C3850' }
  local x = 3
  for _, n in ipairs({ 'ped_adult', 'ped_pair', 'ped_elder' }) do
    for f = 1, 2 do ped(ART[n].base[f], x, 45); x = x + ART[n].base[f].w + 1 end
  end
  ped(ART.ped_adult.base[1], x + 4, 45, alt); ped(ART.ped_pair.base[2], x + 22, 45, alt)
  for i, pn in ipairs(PIECES) do
    local bx, by = 1 + ((i - 1) % 3) * 58, 77 + ((i - 1) // 3) * 30
    ped(ART.ped_adult.comp[pn][1], bx, by); ped(ART.ped_pair.comp[pn][2], bx + 17, by, i % 2 == 0 and alt or nil); ped(ART.ped_elder.comp[pn][1], bx + 40, by)
  end
  S.folha(DIR .. 'traffic_folha.png', 176, 168, {
    { 0, 167, 0, 175, '#343949', '#2B2F3D', '#40465A' },
    { 43, 76, 0, 175, '#A3A7B3', '#8E92A0', '#B6BAC4' },
  }, items, 4)
end
print('problemas: ' .. S.problems)
