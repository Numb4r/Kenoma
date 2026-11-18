-- Kit das formas da fase 1 (0.25.1): o mesmo formato do Humoth (tools/art/creatures/humoth/build.lua), com a
-- forma desenhada por primitivas numa grade de W x W (mapa) e de 96 x 96 (retrato). Cada build.lua de especie
-- monta um `spec` e chama K.run(spec). Usado por pebblet, umbrel, rustling, glimlet, coilkin, bouldkin, shadekin,
-- gratekin e prismkin.
local L = dofile('/home/yuri/Documentos/kenoma/tools/art/npc/_lib.lua')
local K = { L = L }
local floor, ceil = math.floor, math.ceil

function K.hash(x, y, k)
  local v = (x * 73856093) ~ (y * 19349663) ~ (k * 83492791)
  v = v ~ (v >> 13)
  return (v * 1274126177) & 0x7fffffff
end
local hash = K.hash

local function rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end
local function lum(hex)
  local r, g, b = rgb(hex)
  return 0.299 * r + 0.587 * g + 0.114 * b
end

-- Primitivas (coordenadas de pixel, podem ser fracionarias).
function K.ell(g, cx, cy, rx, ry, c, mask)
  for y = floor(cy - ry), ceil(cy + ry) do
    for x = floor(cx - rx), ceil(cx + rx) do
      if ((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2 <= 1 then L.set(g, x, y, c, mask) end
    end
  end
end

function K.poly(g, pts, c, mask)
  local y0, y1 = math.huge, -math.huge
  for _, p in ipairs(pts) do y0 = math.min(y0, p[2]); y1 = math.max(y1, p[2]) end
  for y = ceil(y0), floor(y1) do
    local xs = {}
    for i = 1, #pts do
      local a, b = pts[i], pts[i % #pts + 1]
      if (a[2] <= y) ~= (b[2] <= y) then xs[#xs + 1] = a[1] + (y - a[2]) / (b[2] - a[2]) * (b[1] - a[1]) end
    end
    table.sort(xs)
    for i = 1, #xs - 1, 2 do
      for x = ceil(xs[i] - 0.5), floor(xs[i + 1] + 0.5) do L.set(g, x, y, c, mask) end
    end
  end
end

-- Luz de cima e da esquerda: a borda de cima-esquerda da regiao [base] vira [light], a de baixo-direita [dark].
function K.rim(g, base, light, dark, n)
  local ch = {}
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if g[y][x] == base then
      local hi, lo = false, false
      for k = 1, n do
        if L.get(g, x - k, y - k) ~= base then hi = true end
        if L.get(g, x + k, y + k) ~= base then lo = true end
      end
      if hi and light then ch[#ch + 1] = { x, y, light } elseif lo and dark then ch[#ch + 1] = { x, y, dark } end
    end
  end end
  for _, p in ipairs(ch) do g[p[2]][p[1]] = p[3] end
end

-- Contexto de desenho: coordenadas na grade do mapa, ampliadas por s (1 no mapa, ~3 no retrato).
function K.ctx(g, s, ox, oy)
  local D = { g = g, s = s }
  local function X(x) return ox + (x + 0.5) * s - 0.5 end
  local function Y(y) return oy + (y + 0.5) * s - 0.5 end
  D.X, D.Y = X, Y
  function D.ell(cx, cy, rx, ry, c, mask) K.ell(g, X(cx), Y(cy), rx * s, ry * s, c, mask) end
  function D.rect(x0, y0, x1, y1, c, mask)
    L.rect(g, floor(ox + x0 * s + 0.5), floor(oy + y0 * s + 0.5), floor(ox + (x1 + 1) * s + 0.5) - 1,
      floor(oy + (y1 + 1) * s + 0.5) - 1, c, mask)
  end
  function D.px(x, y, c, mask) D.rect(x, y, x, y, c, mask) end
  function D.poly(pts, c, mask)
    local q = {}
    for i, p in ipairs(pts) do q[i] = { X(p[1]), Y(p[2]) } end
    K.poly(g, q, c, mask)
  end
  -- t: espessura em pixels do mapa.
  function D.line(x0, y0, x1, y1, c, mask, t)
    local r = ((t or 1) * s - 1) / 2
    if s == 1 and (t or 1) >= 2 then -- fio de 2 px limpo no mapa
      L.line(g, x0, y0, x1, y1, c, mask)
      if math.abs(x1 - x0) >= math.abs(y1 - y0) then L.line(g, x0, y0 + 1, x1, y1 + 1, c, mask)
      else L.line(g, x0 + 1, y0, x1 + 1, y1, c, mask) end
      return
    end
    if r < 0.3 then L.line(g, X(x0), Y(y0), X(x1), Y(y1), c, mask); return end
    r = math.max(r, 0.71)
    local n = ceil(math.max(math.abs(x1 - x0), math.abs(y1 - y0)) * s * 2)
    for i = 0, n do
      local k = n == 0 and 0 or i / n
      L.disc(g, X(x0 + (x1 - x0) * k), Y(y0 + (y1 - y0) * k), r, c, mask)
    end
  end
  -- fn(mx, my, c) em coordenadas do mapa para cada pixel pintado; devolve a cor nova ou nil.
  function D.each(fn)
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      if g[y][x] ~= '.' then
        local c = fn((x + 0.5 - ox) / s - 0.5, (y + 0.5 - oy) / s - 0.5, g[y][x])
        if c then g[y][x] = c end
      end
    end end
  end
  function D.swap(from, to) D.each(function(_, _, c) if c == from then return to end end) end
  function D.rim(base, light, dark, n) K.rim(g, base, light, dark, n or math.max(1, floor(s + 0.5))) end
  -- Granulado so no retrato: um em cada m pixels de [from] vira [to].
  function D.speck(from, to, m, seed)
    if s <= 1 then return end
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      if g[y][x] == from and hash(x // 2, y, seed or 9) % m == 0 then g[y][x] = to end
    end end
  end
  return D
end

-- Acessorios das variantes: os mesmos do Humoth (a mesma peca diz a mesma variante em toda familia).
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
-- Pontas da escada de valor (a cor mais escura e a mais clara do corpo), da mais escura a mais clara.
local RAMP = {
  { 'urban', '#202228', '#666B7C' }, { 'green', '#2A3D2C', '#7AA870' }, { 'water', '#0C2231', '#2A6484' },
  { 'residential', '#5A4236', '#C8A888' }, { 'lit', '#807A70', '#F0ECE0' }, { 'sacred', '#5C5674', '#C8C2DC' },
  { 'crimson', '#22101A', '#8A2A3C' },
}

function K.run(spec)
  local W, LEG, name = spec.W, spec.LEG, spec.name
  local H = W
  local DIR = L.ROOT .. 'creatures/' .. name .. '/'
  local C, SC = (W - 1) / 2, W / 28
  local EM = spec.EMIS
  local leanFn = spec.lean or function(y)
    return (y < W * 0.25 and 2) or (y < W * 0.46 and 1) or (y >= W * 0.8 and -1) or 0
  end

  local function heat(g, lv)
    if lv == 0 or not spec.heat then return end
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      local c = g[y][x]
      if lv == 1 then
        if spec.heat.alt[c] and (x + y) % 2 == 0 then g[y][x] = spec.heat.alt[c] end
      elseif spec.heat.all[c] then g[y][x] = spec.heat.all[c] end
    end end
  end
  local function pose(o)
    local g = L.grid(W, H)
    spec.draw(K.ctx(g, 1, 0, 0), o)
    return g
  end
  local function move(g, lean, dy)
    local o = L.grid(W, H)
    for y = 0, H - 1 do
      local dx = lean and leanFn(y) or 0
      for x = 0, W - 1 do
        if g[y][x] ~= '.' then L.set(o, x + dx, y + dy, g[y][x]) end
      end
    end
    return o
  end
  local function erode(g, sg, t, prev)
    for y = 0, H - 1 do for x = 0, W - 1 do
      if g[y][x] ~= '.' then
        local d = math.sqrt(((x - C) / (W * 0.46)) ^ 2 + ((y - C) / (W * 0.41)) ^ 2) + (hash(x, y, 7) % 100) / 100 * 0.24 - 0.12
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
  local function frame(o)
    local sg, g = L.grid(W, H), L.grid(W, H)
    if not o.nobody then
      g = pose(o)
      heat(g, o.hot or 0)
      if o.dark then
        for y = 0, H - 1 do for x = 0, W - 1 do
          if g[y][x] ~= '.' and not EM[g[y][x]] then g[y][x] = spec.DARK end
        end end
      end
      if o.erode then erode(g, sg, o.erode[1], o.erode[2]) end
      g = move(g, o.lean, o.dy or 0)
      L.outline(g, 'A')
    end
    for _, p in ipairs(o.sparks or {}) do
      local x, y = floor(p[1] + 0.5), floor(p[2] + 0.5)
      if L.get(g, x, y) == '.' then L.set(sg, x, y, p[3] or 'S') end
    end
    local b, l, w = split(g, sg)
    return { b = b, l = l, w = w, dy = o.dy or 0, body = not o.nobody, plain = not o.nobody and not o.erode }
  end

  -- Ajudas de faisca (coordenadas do Humoth, ampliadas para W).
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
      o[#o + 1] = { C + r * SC * math.cos(a), C + r * SC * 0.9 * math.sin(a), k % 2 == 0 and 's' or 'S' }
    end
    return o
  end
  local sc, plus, cat, ring = Hh.sc, Hh.plus, Hh.cat, Hh.ring
  local function outlineSparks()
    local g = pose({ p = 2 })
    L.outline(g, 'A')
    local o = {}
    for y = 0, H - 1 do for x = 0, W - 1 do
      if g[y][x] == 'A' and hash(x, y, 1) % 2 == 0 then o[#o + 1] = { x, y, hash(x, y, 2) % 4 == 0 and 's' or 'S' }
      elseif g[y][x] ~= '.' and g[y][x] ~= 'A' and hash(x, y, 2) % 9 == 0 then o[#o + 1] = { x, y } end
    end end
    return o
  end
  local function cloud(m, scale)
    local g = pose({ p = 0 })
    local o = {}
    for y = 0, H - 1 do for x = 0, W - 1 do
      if g[y][x] ~= '.' and hash(x, y, 5) % m == 0 then
        o[#o + 1] = { C + (x - C) * scale, C + (y - C) * scale, hash(x, y, 6) % 3 == 0 and 's' or 'S' }
      end
    end end
    return o
  end

  local c0 = floor(C + 0.5)
  local OS = {
    idle = { { p = 0, dy = 0 }, { p = 1, dy = -1 }, { p = 2, dy = -1 }, { p = 1, dy = 0 } },
    drift = { { p = 0, lean = true, dy = 0 }, { p = 1, lean = true, dy = -1 }, { p = 2, lean = true, dy = -1 },
      { p = 1, lean = true, dy = 0 } },
    alert = { { p = 'alert' }, { p = 'alert', hot = 1, sparks = ring(4, 12.5, 45) },
      { p = 'alert', hot = 2, sparks = cat(ring(6, 12.5, 15), plus(2 * SC, 23 * SC), plus(W - 1 - 2 * SC, 23 * SC)) } },
    flee = {
      { p = 'crouch', dy = 1, hot = 2 },
      { p = 0, lean = true, dy = 0, hot = 1, sparks = sc { { 10, 27 }, { 8, 26, 's' } } },
      { p = 1, lean = true, dy = -1, sparks = sc { { 11, 26, 's' }, { 9, 27 }, { 7, 25 }, { 5, 27 } } },
      { p = 0, lean = true, dy = -2, hot = 1, sparks = cat(plus(10 * SC, 25 * SC), sc { { 7, 27 }, { 5, 25 }, { 3, 27 }, { 13, 27 } }) },
      { p = 1, lean = true, dy = -2, sparks = sc { { 11, 24, 's' }, { 9, 26 }, { 6, 26, 's' }, { 4, 24 }, { 2, 26 }, { 8, 23 } } },
      { p = 2, lean = true, dy = -2, sparks = sc { { 10, 25 }, { 7, 24 }, { 4, 26 }, { 1, 25, 's' }, { 12, 26 } } },
    },
    spawn = {
      { nobody = true, sparks = ring(6, 12, 20) },
      { nobody = true, sparks = cat(ring(8, 8, 0), ring(4, 12, 65), plus(c0, c0)) },
      { nobody = true, sparks = cat(outlineSparks(), plus(c0 - 1, c0), plus(c0, c0)) },
      { p = 2, dark = true, hot = 2, sparks = ring(6, 12.5, 40) },
      { p = 1, hot = 1, sparks = ring(4, 12.5, 10) },
      { p = 0, sparks = sc { { 3, 7 }, { 24, 24 } } },
    },
    tuned = {
      { p = 0, hot = 2, sparks = ring(4, 12.5, 30) },
      { p = 0, hot = 2, erode = { 0.80, 9 } },
      { p = 0, hot = 2, erode = { 0.55, 0.80 } },
      { p = 0, hot = 2, erode = { 0.30, 0.55 } },
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

  -- Conferencia: borda e pecas soltas no corpo.
  local warn = 0
  for _, a in ipairs(ANIMS) do
    for n, f in ipairs(a.frames) do
      local edge = false
      for i = 0, W - 1 do
        if f.b[0][i] ~= '.' or f.b[H - 1][i] ~= '.' or f.b[i][0] ~= '.' or f.b[i][W - 1] ~= '.' then edge = true end
      end
      if edge then warn = warn + 1; print('BORDA ' .. a.name .. ' ' .. n) end
      if f.plain then
        local seen, comps = {}, 0
        for y = 0, H - 1 do for x = 0, W - 1 do
          if f.b[y][x] ~= '.' and not seen[y * W + x] then
            comps = comps + 1
            local st = { { x, y } }
            seen[y * W + x] = true
            while #st > 0 do
              local q = table.remove(st)
              for dy = -1, 1 do for dx = -1, 1 do
                local nx, ny = q[1] + dx, q[2] + dy
                if L.get(f.b, nx, ny) ~= '.' and not seen[ny * W + nx] then seen[ny * W + nx] = true; st[#st + 1] = { nx, ny } end
              end end
            end
          end
        end end
        if comps ~= 1 then warn = warn + 1; print('SOLTA ' .. a.name .. ' ' .. n .. ': ' .. comps .. ' pecas') end
      end
    end
  end

  -- Saida.
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

  -- Variantes: o valor de cada cor do corpo escolhe o ponto entre as duas pontas da variante; 30% do matiz
  -- da base fica (o musgo continua diferente da pedra).
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
      local ends = (spec.ramp and spec.ramp[key]) or { r[2], r[3] }
      local a = ACC[key]
      local v = { key = key, legend = {}, map = {} }
      for k, hex in pairs(a.legend) do v.legend[k] = hex end
      v.legend.A = LEG.A
      local g = L.grid(W, H)
      local at = spec.acc[key]
      L.put(g, at[1], at[2], at.rows or a.rows)
      if a.outline then L.outline(g, 'A') end
      v.acc = g
      local pairsOut = {}
      for _, ch in ipairs(spec.BODY_KEYS) do
        local base = LEG[ch]
        local t = hi > lo and (lum(base) - lo) / (hi - lo) or 0.5
        local r0, g0, b0 = rgb(ends[1]); local r1, g1, b1 = rgb(ends[2])
        local tr, tg, tb = r0 + (r1 - r0) * t, g0 + (g1 - g0) * t, b0 + (b1 - b0) * t
        local br, bg, bb = rgb(base)
        local k = (0.299 * tr + 0.587 * tg + 0.114 * tb) / math.max(1, lum(base))
        local function mix(tc, bc) return math.max(0, math.min(255, floor(tc * 0.7 + math.min(255, bc * k) * 0.3 + 0.5))) end
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

  -- Retrato 96 x 96: o mesmo desenho ampliado (mais granulado e detalhe), 4 quadros.
  local PFPS = spec.pfps or 6
  do
    local PS = 96
    local ps = spec.ps
    local pf = spec.pframes or { { p = 0, hot = 0 }, { p = 1, hot = 1, dy = -1 }, { p = 2, hot = 2, dy = -2 }, { p = 1, hot = 1, dy = -1 } }
    local frames = {}
    for f = 1, 4 do
      local o = pf[f]
      o.portrait = f
      local g = L.grid(PS, PS)
      spec.draw(K.ctx(g, ps, (PS - W * ps) / 2 + (spec.pox or 0), (PS - W * ps) / 2 + (spec.poy or 0) + (o.dy or 0)), o)
      heat(g, o.hot or 0)
      L.outline(g, 'A')
      for i = 0, PS - 1 do
        if g[0][i] ~= '.' or g[PS - 1][i] ~= '.' or g[i][0] ~= '.' or g[i][PS - 1] ~= '.' then
          warn = warn + 1; print('BORDA retrato ' .. f); break
        end
      end
      local b, l, w = split(g, nil)
      frames[f] = { b = b, l = l, w = w, ms = 1000 / PFPS }
    end
    strips(DIR .. name .. '_portrait', frames)
    saveSprite(DIR .. name .. '_portrait.aseprite', PS, PS, frames, { { name = 'hover', from = 1, to = 4 } })
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
      .. '\n  },\n  "portrait": { "frame": 96, "frames": 4, "fps": ' .. PFPS .. ' }\n}\n')
    f:close()
  end

  -- Folha de conferencia, como a do Humoth.
  do
    local PITCH, M, Z = W + 2, 4, 4
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
  print('ok ' .. name .. (warn > 0 and (' com ' .. warn .. ' avisos') or ' sem avisos'))
end

return K
