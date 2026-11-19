-- Kit da arte final da família Hum (Elétrico): Coilkin (Espírito), Entidade Maior e Arquétipo. O formato é o do
-- Humoth (tools/art/creatures/humoth/build.lua): seis animações em três tiras (corpo, _leds, _glow), <especie>.json,
-- <especie>_variants.json com os acessórios, retrato de 4 quadros e a folha. As formas são as dos conceitos aprovados
-- (tools/art/creatures/conceitos/hum/build.lua), agora com pose: cada espécie dá draw(g, sg, k, o), que desenha o
-- corpo em g (emissivos ACESOS, sem contorno) e a faísca solta em sg; k é a escala (1 no mapa) e o é o quadro
-- (ph fase do laço, pose 'alert' | 'crouch', hot 0..2, lean, portrait, bust).
-- Rodar: KENOMA_ART='<worktree>/tools/art/'; dofile(KENOMA_ART .. 'creatures/<especie>/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/ do worktree, com a barra no fim)')
local C = dofile(ART .. 'creatures/conceitos/_conceito.lua')
local L = C.L
local K = { L = L, C = C, sweep = 0 }
local floor, ceil, sqrt, abs = math.floor, math.ceil, math.sqrt, math.abs

K.LEG = {
  A = '#1A1424',                                              -- contorno
  B = '#8F86C9', T = '#C4BDF0',                               -- antena
  C = '#2A2140', D = '#4A3D6B', R = '#6A5C94',                -- pelo
  G = '#34305E', F = '#4D4A8A', E = '#7672B8',                -- asa (pó índigo, as cores do Humoth)
  P = '#28244A', Q = '#3D3A70',                               -- asa na sombra
  ['1'] = '#A9A7BC', ['2'] = '#7E7C92', ['3'] = '#5C5A70', ['4'] = '#45435A', -- asa de cinza (Arquétipo)
  K = '#6B3A22', M = '#DDA060', c = '#A8663A',                -- cobre desencapado
  n = '#2B2836', N = '#55525F',                               -- cabo de borracha
  u = '#33363F', U = '#4A4E5A', V = '#6E7380', W = '#9EA3AE', -- aço galvanizado
  o = '#6E3A2C', O = '#9A5A44',                               -- porcelana do isolador
  w = '#4E3C2E', x = '#75604A',                               -- madeira de poste e cruzeta
  z = '#0D0914', ['0'] = '#130D1E',                           -- o vão (mais escuro que o contorno) e a faixa de fundo dele
  h = '#17444C', i = '#245A62', j = '#6B5A44',                -- LED e veio apagados (corpo)
  y = '#3F3A74', ['8'] = '#5E4C3E',                           -- costura do Véu apagada: na asa e no segundo material
  H = '#5FD3C6', I = '#D9FFF6',                               -- olho de LED aceso (leds)
  J = '#FFD23A', Y = '#FFEE9A',                               -- veio aceso (glow): a luz do tipo, ui/types/palette.lua
  S = '#FFD23A', s = '#FFEE9A',                               -- faísca solta (só no glow)
  X = '#9B7BFF', ['9'] = '#9B7BFF', Z = '#9B7BFF',            -- costura do Véu acesa (X, 9) e o violeta do vão (Z)
}
K.LEG.q = K.LEG.K; K.LEG.k = K.LEG.c; K.LEG.m = K.LEG.M       -- o mesmo cobre em fio fino, sem contorno
K.LEG.b = K.LEG.B                                             -- barba de antena, sem contorno
-- aceso = { apagado, camada }: 'l' leds (pisca), 'w' glow.
K.LIT = { H = { 'h', 'l' }, I = { 'i', 'l' }, J = { 'j', 'w' }, Y = { 'j', 'w' }, X = { 'y', 'w' }, ['9'] = { '8', 'w' },
  Z = { 'z', 'w' } }
local NOPULL = 'AqkmbJYSs'                                    -- contorno seletivo: fio fino, barba e veio não puxam

function K.hash(x, y, k)
  local v = (x * 73856093) ~ (y * 19349663) ~ (k * 83492791)
  v = v ~ (v >> 13)
  return (v * 1274126177) & 0x7fffffff
end
local hash = K.hash

-- Asa de esfinge: o = { x, y (raiz), ang (graus, y para baixo), len, wid, side (+1 ou -1: lado da borda de fuga),
-- pal = { borda, meio, base, faixa }, torn = período do rasgo em px, clip = function(u, v) }.
local function wingGeo(o)
  local a = math.rad(o.ang)
  local dx, dy = math.cos(a), math.sin(a)
  return dx, dy, -dy * o.side, dx * o.side
end
local function wingEdges(o, u, raw)
  local s = math.sin(math.pi * u ^ 0.75)
  local tr = s > 0 and s ^ 0.7 or 0
  if o.torn and not raw and floor(u * o.len / o.torn) % 2 == 1 then tr = tr * 0.72 end
  return 0.16 * (1 - u) ^ 0.5 + 0.03, tr
end
function K.wpt(o, u, t)
  local dx, dy, px, py = wingGeo(o)
  local le, tr = wingEdges(o, u, true)
  local v = (-le + t * (tr + le)) * o.wid
  return o.x + dx * u * o.len + px * v, o.y + dy * u * o.len + py * v
end
function K.wing(g, o)
  local dx, dy, px, py = wingGeo(o)
  local r = o.len + o.wid + 2
  for y = floor(o.y - r), ceil(o.y + r) do
    for x = floor(o.x - r), ceil(o.x + r) do
      local rx, ry = x - o.x, y - o.y
      local u = (rx * dx + ry * dy) / o.len
      if u >= 0 and u <= 1 then
        local v = (rx * px + ry * py) / o.wid
        local le, tr = wingEdges(o, u)
        if v >= -le and v <= tr and (not o.clip or o.clip(u, v, x, y)) then
          local t = (v + le) / (tr + le)
          local band = floor(u * o.len / (o.band or 2)) % 2
          local ch = o.pal[3]
          if t < 0.16 then ch = o.pal[1]
          elseif t < 0.42 then ch = (o.rich and band == 1) and o.pal[3] or o.pal[2]
          elseif t > 0.88 and band == 0 then ch = o.pal[2]
          elseif band == 1 and (t > 0.58 or o.rich) then ch = o.pal[4] end
          L.set(g, x, y, ch)
        end
      end
    end
  end
end
-- Linhas sobre a asa, só por cima da membrana: list = { { u0, t0, u1, t1 } }.
function K.veins(g, o, list, th, ch)
  local mask = table.concat(o.pal)
  for _, q in ipairs(list) do
    local x0, y0 = K.wpt(o, q[1], q[2]); local x1, y1 = K.wpt(o, q[3], q[4])
    for d = 0, (th or 1) - 1 do L.line(g, x0 + d, y0, x1 + d, y1, ch or 'J', mask) end
  end
end

-- Olho de LED. Pequeno: o bloco 4x4 do Humoth. Médio: disco cheio. Grande: matriz de LED com aro, uma fileira
-- mais clara que varre com K.sweep. pupil = { dx, dy, r }: LEDs apagados dentro do olho.
function K.eye(g, cx, cy, r, pupil, mask)
  if r < 2.2 then
    L.put(g, floor(cx - 1), floor(cy - 1), { '.HH.', 'HIIH', 'HIIH', '.HH.' })
    return
  end
  for y = floor(cy - r - 1), ceil(cy + r + 1) do
    for x = floor(cx - r - 1), ceil(cx + r + 1) do
      local d = sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
      if r < 3.4 then
        if d <= r then L.set(g, x, y, d < r * 0.55 and 'I' or 'H', mask) end
      elseif d <= r + 1 and d > r then L.set(g, x, y, 'A', mask)
      elseif d <= r then
        local ch = 'h'
        if (x + y) % 2 == 0 then ch = (d < r * 0.4 or (y + K.sweep * 3) % 12 < 2) and 'I' or 'H' end
        if pupil and sqrt((x - cx - pupil[1]) ^ 2 + (y - cy - pupil[2]) ^ 2) <= pupil[3] then ch = (x + y) % 2 == 0 and 'i' or 'h' end
        L.set(g, x, y, ch, mask)
      end
    end
  end
end
-- Olho das etapas altas: no retrato é sempre matriz, com a pupila apontando para um lado próprio (seed).
function K.E(g, x, y, rmap, k, seed, mask)
  if k == 1 then return K.eye(g, x, y, rmap, nil, mask) end
  local r = math.max(rmap * k, 3.6)
  local a = (hash(seed, 7, 3) % 8) * math.pi / 4
  K.eye(g, x, y, r, { math.cos(a) * r * 0.32, math.sin(a) * r * 0.32, r * 0.4 }, mask)
end

-- Pelo em escamas (C, D, com R do lado da luz) e bobina de cobre (voltas inclinadas).
function K.fur(g, cx, y0, y1, hw, p)
  for y = floor(y0), floor(y1) do
    local w = hw(y)
    for x = ceil(cx - w), floor(cx + w) do
      local row = floor((y + abs(x - cx) * 0.7) / p)
      local ch = row % 2 == 0 and 'C' or 'D'
      if ch == 'D' and x < cx - w * 0.25 and row % 4 == 1 then ch = 'R' end
      L.set(g, x, y, ch)
    end
  end
end
function K.coil(g, cx, y0, y1, hw, p)
  for y = floor(y0), floor(y1) do
    local w = hw(y)
    for x = ceil(cx - w), floor(cx + w) do
      local ch = floor((y + (x - cx) * 0.5) / p) % 2 == 0 and 'c' or 'K'
      if ch == 'c' and x < cx - w * 0.2 and x >= cx - w * 0.2 - p then ch = 'M' end
      L.set(g, x, y, ch)
    end
  end
end
-- Fio ou antena: linha quebrada de espessura th, a com um b a cada três passos.
function K.wire(g, pts, a, b, th, mask)
  local n = 0
  th = math.max(1, floor((th or 1) + 0.5))
  for i = 1, #pts - 1 do
    local x0, y0, x1, y1 = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
    local m = math.max(abs(x1 - x0), abs(y1 - y0))
    for s = 0, floor(m) do
      local t = m == 0 and 0 or s / m
      n = n + 1
      for d = 0, th - 1 do L.set(g, x0 + (x1 - x0) * t + d, y0 + (y1 - y0) * t, (n // th) % 3 == 0 and b or a, mask) end
    end
  end
end
-- Antena de pluma: no retrato ganha barbas dos dois lados.
function K.feather(g, pts, k, mask)
  if k > 1 then
    for i = 1, #pts - 1 do
      local x0, y0, x1, y1 = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
      local len = sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
      local ux, uy = (x1 - x0) / len, (y1 - y0) / len
      for s = 2, len, 3 do
        for _, sd in ipairs({ -1, 1 }) do
          local bx, by = x0 + ux * s, y0 + uy * s
          L.line(g, bx, by, bx + (-uy * sd * 0.8 + ux * 0.6) * 3.5, by + (ux * sd * 0.8 + uy * 0.6) * 3.5, 'b', '.b')
        end
      end
    end
  end
  K.wire(g, pts, 'B', 'T', k, mask)
end
-- Faísca solta (na grade sg) e LED avulso.
function K.plus(sg, x, y, k)
  k = math.max(1, floor(k + 0.5))
  L.rect(sg, floor(x), floor(y), floor(x) + k - 1, floor(y) + k - 1, 's')
  for _, d in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
    L.rect(sg, floor(x) + d[1] * k, floor(y) + d[2] * k, floor(x) + d[1] * k + k - 1, floor(y) + d[2] * k + k - 1, 'S', '.')
  end
end
function K.dot(sg, x, y, k, ch)
  k = math.max(1, floor(k + 0.5))
  L.rect(sg, floor(x), floor(y), floor(x) + k - 1, floor(y) + k - 1, ch or 'S', '.')
end
function K.led(g, x, y, k, ch)
  k = math.max(1, floor(k + 0.5))
  L.rect(g, floor(x + 0.5), floor(y + 0.5), floor(x + 0.5) + k - 1, floor(y + 0.5) + k - 1, ch or 'H')
end

local function rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end
local function lum(hex)
  local r, g, b = rgb(hex)
  return 0.299 * r + 0.587 * g + 0.114 * b
end

-- Acessórios das variantes: os mesmos do Humoth (a mesma peça diz a mesma variante em toda família).
local ACC = {
  urban = { legend = { W = '#B6BAC4', w = '#8E92A0' }, rows = { 'WWWWWw', '......', '......', 'WWWWWw' } },
  green = { legend = { L = '#8AB874', l = '#5FB26A', d = '#2F7446' }, outline = true,
    rows = { '.LL......LL.', 'LLlll..lllLL', '..ddd..ddd..' } },
  water = { legend = { U = '#E8F8FF', u = '#9FD4F0', v = '#5A9AB8' },
    rows = { 'u......u', '.u....u.', '..uUUu..', '...Uu...', '...uv...' } },
  residential = { legend = { O = '#A03C2C', o = '#6E261E' }, outline = true,
    rows = { 'OOOOOOoo', '......Oo', '......Oo', '......oo' } },
  lit = { legend = { N = '#2B2F3D', M = '#40465A' }, rows = { 'NN....NN', 'NNNMMNNN', 'NN....NN' } },
  sacred = { legend = { G = '#F2E6B0', g = '#C8B878' }, outline = true,
    rows = { '.GGGGGG.', 'G......G', 'G......G', '.gggggg.' } },
  crimson = { legend = { R = '#FF5A6A', r = '#C03048' }, rows = { '.RR.', 'Rr..', 'R...', 'Rr..', '.RR.' } },
}
-- Pontas da escada de valor (a cor mais escura e a mais clara do corpo) de cada variante.
local RAMP = {
  { 'urban', '#202228', '#666B7C' }, { 'green', '#2A3D2C', '#7AA870' }, { 'water', '#0C2231', '#2A6484' },
  { 'residential', '#5A4236', '#C8A888' }, { 'lit', '#807A70', '#F0ECE0' }, { 'sacred', '#5C5674', '#C8C2DC' },
  { 'crimson', '#22101A', '#8A2A3C' },
}

-- spec = { name, stage ('espirito' | 'entidade' | 'arquetipo'), W, PW (retrato), LEG, BODY_KEYS, DARK, draw,
--   nloop (quadros de idle e drift), dy (body_dy do laço), fps = { idle=, ... }, fleeDy, ownLean (a espécie inclina
--   sozinha no draw), lean = function(y), acc = { variante = { x, y } }, portrait = function(o) -> g, sg, ox, oy,
--   over = { anim = function(Hh, quadros) -> quadros } }
function K.run(spec)
  local W, LEG, name = spec.W, spec.LEG, spec.name
  local H, PW = W, spec.PW
  local DIR = ART .. 'creatures/' .. name .. '/'
  local CC, SC = (W - 1) / 2, W / 28
  local EM = K.LIT
  local SOLID = ''
  for ch in pairs(LEG) do
    if not NOPULL:find(ch, 1, true) then SOLID = SOLID .. ch end
  end
  local leanFn = spec.lean or function(y)
    return (y < W * 0.25 and 2) or (y < W * 0.46 and 1) or (y >= W * 0.8 and -1) or 0
  end

  local function heat(g, lv)
    if lv == 0 then return end
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      if g[y][x] == 'J' and (lv == 2 or (x + y) % 2 == 0) then g[y][x] = 'Y' end
    end end
  end
  local function move(g, lean, dy)
    if not lean and dy == 0 then return g end
    local o = L.grid(g.w, g.h)
    for y = 0, g.h - 1 do
      local dx = lean and leanFn(y) or 0
      for x = 0, g.w - 1 do
        if g[y][x] ~= '.' then L.set(o, x + dx, y + dy, g[y][x]) end
      end
    end
    return o
  end
  local function erode(g, sg, t, prev)
    for y = 0, H - 1 do for x = 0, W - 1 do
      if g[y][x] ~= '.' then
        local d = sqrt(((x - CC) / (W * 0.46)) ^ 2 + ((y - CC) / (W * 0.41)) ^ 2) + (hash(x, y, 7) % 100) / 100 * 0.24 - 0.12
        if d > t then
          g[y][x] = '.'
          local m = d <= prev and 3 or 7
          if hash(x, y, 3) % m == 0 then sg[y][x] = hash(x, y, 4) % 3 == 0 and 's' or 'S' end
        end
      end
    end end
  end
  local function split(g, sg)
    local b, l, w = L.grid(g.w, g.h), L.grid(g.w, g.h), L.grid(g.w, g.h)
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      local c = g[y][x]
      local e = EM[c]
      if e then
        b[y][x] = e[1]
        if e[2] == 'l' then l[y][x] = c else w[y][x] = c end
      else b[y][x] = c end
      local s = sg and sg[y][x]
      if s and s ~= '.' then w[y][x] = s end
    end end
    return b, l, w
  end
  local function pose(o)
    local g, sg = L.grid(W, H), L.grid(W, H)
    spec.draw(g, sg, 1, o)
    return g, sg
  end
  local function frame(o)
    local sg, g = L.grid(W, H), L.grid(W, H)
    if not o.nobody then
      g, sg = pose(o)
      heat(g, o.hot or 0)
      if o.dark then
        for y = 0, H - 1 do for x = 0, W - 1 do
          if g[y][x] ~= '.' and not EM[g[y][x]] then g[y][x] = spec.DARK end
        end end
      end
      if o.erode then erode(g, sg, o.erode[1], o.erode[2]) end
      local lean = o.lean and not spec.ownLean
      g = move(g, lean, o.dy or 0); sg = move(sg, lean, o.dy or 0)
      L.outline(g, 'A', SOLID)
    end
    for _, p in ipairs(o.sparks or {}) do
      local x, y = floor(p[1] + 0.5), floor(p[2] + 0.5)
      if L.get(g, x, y) == '.' then L.set(sg, x, y, p[3] or 'S') end
    end
    local b, l, w = split(g, sg)
    return { b = b, l = l, w = w, dy = o.dy or 0, body = not o.nobody, plain = not o.nobody and not o.erode }
  end

  -- Ajudas de faísca (coordenadas do Humoth, ampliadas para W).
  local Hh = {}
  function Hh.sc(list)
    local o = {}
    for i, p in ipairs(list) do o[i] = { p[1] * SC, p[2] * SC, p[3] } end
    return o
  end
  function Hh.plus(x, y) return { { x, y, 's' }, { x - 1, y }, { x + 1, y }, { x, y - 1 }, { x, y + 1 } } end
  function Hh.cat(...)
    local o = {}
    for _, t in ipairs({ ... }) do for _, p in ipairs(t) do o[#o + 1] = p end end
    return o
  end
  function Hh.ring(n, r, phase)
    local o = {}
    for k = 0, n - 1 do
      local a = math.rad(phase + k * 360 / n)
      o[#o + 1] = { CC + r * SC * math.cos(a), CC + r * SC * 0.9 * math.sin(a), k % 2 == 0 and 's' or 'S' }
    end
    return o
  end
  local sc, plus, cat, ring = Hh.sc, Hh.plus, Hh.cat, Hh.ring
  local function outlineSparks()
    local g = pose({ pose = 'crouch' })
    L.outline(g, 'A', SOLID)
    local o = {}
    for y = 0, H - 1 do for x = 0, W - 1 do
      if g[y][x] == 'A' and hash(x, y, 1) % 2 == 0 then o[#o + 1] = { x, y, hash(x, y, 2) % 4 == 0 and 's' or 'S' }
      elseif g[y][x] ~= '.' and g[y][x] ~= 'A' and hash(x, y, 2) % 9 == 0 then o[#o + 1] = { x, y } end
    end end
    return o
  end
  local function cloud(m, scale)
    local g = pose({ ph = 0 })
    local o = {}
    for y = 0, H - 1 do for x = 0, W - 1 do
      if g[y][x] ~= '.' and hash(x, y, 5) % m == 0 then
        o[#o + 1] = { CC + (x - CC) * scale, CC + (y - CC) * scale, hash(x, y, 6) % 3 == 0 and 's' or 'S' }
      end
    end end
    return o
  end

  local c0 = floor(CC + 0.5)
  local NL = spec.nloop or 4
  local DY = spec.dy or (NL == 4 and { 0, -1, -1, 0 } or { 0, 0, -1, -1, -1, 0 })
  local FD = spec.fleeDy or { 1, 0, -1, -2, -2, -2 }
  local idle, drift = {}, {}
  for i = 1, NL do
    idle[i] = { ph = i - 1, dy = DY[i] }
    drift[i] = { ph = i - 1, dy = DY[i], lean = true }
  end
  local OS = {
    idle = idle, drift = drift,
    alert = { { pose = 'alert' }, { pose = 'alert', hot = 1, sparks = ring(4, 12.5, 45) },
      { pose = 'alert', hot = 2, sparks = cat(ring(6, 12.5, 15), plus(2 * SC, 23 * SC), plus(W - 1 - 2 * SC, 23 * SC)) } },
    flee = {
      { pose = 'crouch', dy = FD[1], hot = 2 },
      { ph = 0, lean = true, dy = FD[2], hot = 1, sparks = sc { { 10, 27 }, { 8, 26, 's' } } },
      { ph = 1, lean = true, dy = FD[3], sparks = sc { { 11, 26, 's' }, { 9, 27 }, { 7, 25 }, { 5, 27 } } },
      { ph = 2, lean = true, dy = FD[4], hot = 1, sparks = cat(plus(10 * SC, 25 * SC), sc { { 7, 27 }, { 5, 25 }, { 3, 27 }, { 13, 27 } }) },
      { ph = 3, lean = true, dy = FD[5], sparks = sc { { 11, 24, 's' }, { 9, 26 }, { 6, 26, 's' }, { 4, 24 }, { 2, 26 }, { 8, 23 } } },
      { ph = 4 % NL, lean = true, dy = FD[6], sparks = sc { { 10, 25 }, { 7, 24 }, { 4, 26 }, { 1, 25, 's' }, { 12, 26 } } },
    },
    spawn = {
      { nobody = true, sparks = ring(6, 12, 20) },
      { nobody = true, sparks = cat(ring(8, 8, 0), ring(4, 12, 65), plus(c0, c0)) },
      { nobody = true, sparks = cat(outlineSparks(), plus(c0 - 1, c0), plus(c0, c0)) },
      { pose = 'crouch', dark = true, hot = 2, sparks = ring(6, 12.5, 40) },
      { ph = 1, hot = 1, sparks = ring(4, 12.5, 10) },
      { ph = 0, sparks = sc { { 3, 7 }, { 24, 24 } } },
    },
    tuned = {
      { ph = 0, hot = 2, sparks = ring(4, 12.5, 30) },
      { ph = 0, hot = 2, erode = { 0.80, 9 } },
      { ph = 0, hot = 2, erode = { 0.55, 0.80 } },
      { ph = 0, hot = 2, erode = { 0.30, 0.55 } },
      { nobody = true, sparks = cloud(5, 1) },
      { nobody = true, sparks = cat(cloud(10, 0.5), plus(c0, c0)) },
    },
  }
  local FPS = { idle = 8, drift = 8, alert = 6, flee = 12, spawn = 10, tuned = 10 }
  local ANIMS = {}
  for _, n in ipairs({ 'idle', 'drift', 'alert', 'flee', 'spawn', 'tuned' }) do
    local os = OS[n]
    if spec.over and spec.over[n] then os = spec.over[n](Hh, os) end
    local fr = {}
    for i, o in ipairs(os) do fr[i] = frame(o) end
    ANIMS[#ANIMS + 1] = { name = n, fps = (spec.fps and spec.fps[n]) or FPS[n], frames = fr }
  end

  -- Conferência: borda (corpo) em todo quadro e peças soltas nos quadros inteiros.
  local warn = 0
  local function edge(b)
    for i = 0, b.w - 1 do
      if b[0][i] ~= '.' or b[b.h - 1][i] ~= '.' or b[i][0] ~= '.' or b[i][b.w - 1] ~= '.' then return true end
    end
  end
  local function pieces(b)
    local seen, comps = {}, 0
    for y = 0, b.h - 1 do for x = 0, b.w - 1 do
      if b[y][x] ~= '.' and not seen[y * b.w + x] then
        comps = comps + 1
        local st = { { x, y } }
        seen[y * b.w + x] = true
        while #st > 0 do
          local q = table.remove(st)
          for dy = -1, 1 do for dx = -1, 1 do
            local nx, ny = q[1] + dx, q[2] + dy
            if L.get(b, nx, ny) ~= '.' and not seen[ny * b.w + nx] then seen[ny * b.w + nx] = true; st[#st + 1] = { nx, ny } end
          end end
        end
      end
    end end
    return comps
  end
  for _, a in ipairs(ANIMS) do
    for n, f in ipairs(a.frames) do
      if edge(f.b) then warn = warn + 1; print('BORDA ' .. a.name .. ' ' .. n) end
      if f.plain and pieces(f.b) ~= 1 then warn = warn + 1; print('SOLTA ' .. a.name .. ' ' .. n .. ': ' .. pieces(f.b) .. ' peças') end
    end
  end
  do -- quadro 0 do idle: 2 px livres em cima e 1 embaixo
    local b = ANIMS[1].frames[1].b
    for x = 0, W - 1 do
      if b[1][x] ~= '.' or b[H - 1][x] ~= '.' then warn = warn + 1; print('MARGEM idle 1: corpo na linha 1 ou na última'); break end
    end
  end

  -- Saída.
  local function image(g, legend)
    local img = Image(g.w, g.h, ColorMode.RGB)
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      local c = g[y][x]
      if c ~= '.' then
        if not legend[c] then error(name .. ': sem cor: ' .. c) end
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
      strips(DIR .. name .. '_' .. a.name, a.frames)
    end
    saveSprite(DIR .. name .. '.aseprite', W, H, all, tags)
  end

  -- Variantes: o valor de cada cor do corpo escolhe o ponto entre as duas pontas da variante; 30% do matiz da
  -- base fica (o cobre continua diferente do aço).
  local VARIANTS = {}
  do
    local lo, hi = math.huge, -math.huge
    for _, ch in ipairs(spec.BODY_KEYS) do
      local v = lum(LEG[ch]); lo = math.min(lo, v); hi = math.max(hi, v)
    end
    local spr = Sprite(W, H, ColorMode.RGB)
    local out = { '{' }
    for n, r in ipairs(RAMP) do
      local key = r[1]
      local a = ACC[key]
      local v = { key = key, legend = {}, map = {} }
      for k, hex in pairs(a.legend) do v.legend[k] = hex end
      v.legend.A = LEG.A
      local g = L.grid(W, H)
      local at = spec.acc[key]
      L.put(g, at[1], at[2], a.rows)
      if a.outline then L.outline(g, 'A') end
      v.acc = g
      local pairsOut = {}
      for _, ch in ipairs(spec.BODY_KEYS) do
        local base = LEG[ch]
        local t = hi > lo and (lum(base) - lo) / (hi - lo) or 0.5
        local r0, g0, b0 = rgb(r[2]); local r1, g1, b1 = rgb(r[3])
        local tr, tg, tb = r0 + (r1 - r0) * t, g0 + (g1 - g0) * t, b0 + (b1 - b0) * t
        local br, bg, bb = rgb(base)
        local kk = (0.299 * tr + 0.587 * tg + 0.114 * tb) / math.max(1, lum(base))
        local function mix(tc, bc) return math.max(0, math.min(255, floor(tc * 0.7 + math.min(255, bc * kk) * 0.3 + 0.5))) end
        local hex = string.format('#%02x%02x%02x', mix(tr, br), mix(tg, bg), mix(tb, bb))
        v.map[base:lower()] = hex
        pairsOut[#pairsOut + 1] = string.format('"%s": "%s"', base:lower(), hex)
      end
      local img = image(g, v.legend)
      savePng(img, DIR .. name .. '_acc_' .. key .. '.png')
      if n > 1 then spr:newEmptyFrame() end
      spr:newCel(spr.layers[1], n, img, Point(0, 0))
      local tag = spr:newTag(n, n); tag.name = key
      out[#out + 1] = string.format('  "%s": { "map": { %s }, "accessory": "%s_acc_%s.png" }%s',
        key, table.concat(pairsOut, ', '), name, key, n < #RAMP and ',' or '')
      VARIANTS[n] = v
    end
    out[#out + 1] = '}'
    spr:saveAs(DIR .. name .. '_acc.aseprite'); spr:close()
    local f = assert(io.open(DIR .. name .. '_variants.json', 'w'))
    f:write(table.concat(out, '\n') .. '\n'); f:close()
  end

  -- Retrato PW x PW, 4 quadros: a espécie devolve a grade grande e onde ela cai no quadro.
  local PFPS = 6
  do
    local pf = { { ph = 0, hot = 0, dy = 0 }, { ph = 1, hot = 1, dy = -1 }, { ph = 2, hot = 2, dy = -2 }, { ph = 3, hot = 1, dy = -1 } }
    local frames = {}
    for f = 1, 4 do
      local o = pf[f]
      o.portrait = f
      K.sweep = f - 1
      local big, bsg, ox, oy = spec.portrait(o)
      heat(big, o.hot)
      L.outline(big, 'A', SOLID)
      local g, sg = L.grid(PW, PW), L.grid(PW, PW)
      for y = 0, big.h - 1 do for x = 0, big.w - 1 do
        if big[y][x] ~= '.' then L.set(g, x + ox, y + oy + o.dy, big[y][x]) end
        if bsg[y][x] ~= '.' then L.set(sg, x + ox, y + oy + o.dy, bsg[y][x]) end
      end end
      local b, l, w = split(g, sg)
      if edge(b) then warn = warn + 1; print('BORDA retrato ' .. f) end
      frames[f] = { b = b, l = l, w = w, ms = 1000 / PFPS }
    end
    K.sweep = 0
    strips(DIR .. name .. '_portrait', frames)
    saveSprite(DIR .. name .. '_portrait.aseprite', PW, PW, frames, { { name = 'hover', from = 1, to = 4 } })
  end

  -- <nome>.json
  do
    local an, dy, vis = {}, {}, {}
    for _, a in ipairs(ANIMS) do
      local d, v = {}, {}
      for n, f in ipairs(a.frames) do d[n] = tostring(f.dy); v[n] = f.body and '1' or '0' end
      an[#an + 1] = string.format('    "%s": { "frames": %d, "fps": %d }', a.name, #a.frames, a.fps)
      dy[#dy + 1] = string.format('    "%s": [%s]', a.name, table.concat(d, ', '))
      vis[#vis + 1] = string.format('    "%s": [%s]', a.name, table.concat(v, ', '))
    end
    local f = assert(io.open(DIR .. name .. '.json', 'w'))
    f:write('{\n  "frame": ' .. W .. ',\n  "anims": {\n' .. table.concat(an, ',\n') .. '\n  },\n  "body_dy": {\n'
      .. table.concat(dy, ',\n') .. '\n  },\n  "body_visible": {\n' .. table.concat(vis, ',\n')
      .. '\n  },\n  "portrait": { "frame": ' .. PW .. ', "frames": 4, "fps": ' .. PFPS .. ' }\n}\n')
    f:close()
  end

  -- Folha de conferência, como a do Humoth.
  do
    local cols = 8
    for _, a in ipairs(ANIMS) do cols = math.max(cols, #a.frames) end
    local PITCH, M, Z = W + 2, 4, 4
    local CW, CH = M * 2 + PITCH * cols - 2, M * 2 + PITCH * 9 - 2
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
        local lm = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
        cv[y][x] = { lm, lm, lm }
      end
    end
    local img = Image(CW * Z, CH * Z, ColorMode.RGB)
    for y = 0, CH - 1 do for x = 0, CW - 1 do
      local c = cv[y][x]
      local p = app.pixelColor.rgba(floor(c[1] + 0.5), floor(c[2] + 0.5), floor(c[3] + 0.5), 255)
      for j = 0, Z - 1 do for i = 0, Z - 1 do img:putPixel(x * Z + i, y * Z + j, p) end end
    end end
    local s = Sprite(img.width, img.height, ColorMode.RGB)
    s:newCel(s.layers[1], 1, img, Point(0, 0))
    s:saveAs(DIR .. name .. '_folha.aseprite')
    s:saveCopyAs(DIR .. name .. '_folha.png')
    s:close()
  end

  -- Régua: o quadro 0 do idle e do retrato, como o regua.py mede (corpo; leds + glow juntos).
  local P = C.PISO[spec.stage]
  local function regua(kind, anim, side)
    local function crop(path)
      local g, o = C.png(path), L.grid(side, side)
      for y = 0, side - 1 do for x = 0, side - 1 do o[y][x] = g[y][x] end end
      return o
    end
    local base = DIR .. name .. '_' .. anim
    local em, gl, ecol, ne = crop(base .. '_leds.png'), crop(base .. '_glow.png'), {}, 0
    for y = 0, side - 1 do for x = 0, side - 1 do
      for _, c in ipairs({ em[y][x], gl[y][x] }) do
        if c ~= '.' and not ecol[c] then ecol[c] = true; ne = ne + 1 end
      end
      if em[y][x] == '.' then em[y][x] = gl[y][x] end
    end end
    local m = C.measure(crop(base .. '.png'), em)
    local map = kind == 'mapa'
    local bad = {}
    if m.cores < (map and P.cores or P.rcores) then bad[#bad + 1] = 'cores' end
    if m.detalhe < (map and P.detalhe or P.rdetalhe) then bad[#bad + 1] = 'detalhe' end
    if m.contorno > (map and P.contorno or 0.22) then bad[#bad + 1] = 'contorno' end
    if m.emissivo < (map and P.emissivo[1] or P.remissivo) or m.emissivo > P.emissivo[2] then bad[#bad + 1] = 'emissivo' end
    if map and ne < (spec.stage == 'arquetipo' and 4 or 3) then bad[#bad + 1] = 'cores emissivas' end
    print(string.format('  %s %s %s: opacos %d, cores %d, detalhe %.2f, contorno %.2f, emissivo %.3f, cores emissivas %d%s',
      name, spec.stage, kind, m.opacos, m.cores, m.detalhe, m.contorno, m.emissivo, ne,
      #bad > 0 and ('  ABAIXO DO PISO: ' .. table.concat(bad, '; ')) or ''))
  end
  regua('mapa', 'idle', W)
  regua('retrato', 'portrait', PW)
  print('ok ' .. name .. (warn > 0 and (' com ' .. warn .. ' avisos') or ' sem avisos'))
end

return K
