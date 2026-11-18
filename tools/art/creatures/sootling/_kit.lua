-- Kit das familias Soot, Rill e Frond (0.25.1). O mesmo formato de saida do Humoth (../humoth/build.lua), com a
-- especie como parametro: cada build.lua desta leva monta um `spec` e chama K.build(spec).
-- Um caractere por pixel, '.' vazio, 'A' contorno. A criatura olha para a direita.
local L = dofile('/home/yuri/Documentos/kenoma/tools/art/npc/_lib.lua')
local K = { L = L }

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
local function mix(a, b, t)
  local ar, ag, ab = rgb(a)
  local br, bg, bb = rgb(b)
  local function ch(p, q) return math.floor(p + (q - p) * t + 0.5) end
  return string.format('#%02x%02x%02x', ch(ar, br), ch(ag, bg), ch(ab, bb))
end

-- Degrade de cada variante (sombra, meio, luz): a escada de valor do Humoth. O corpo base e remapeado pela luminancia.
K.GRADS = {
  -- Meios-tons espacados em luminancia (27, 47, 82, 145, 178, 205, 232) para o par passar no teste de cinza.
  urban = { '#30333E', '#4E5260', '#7C808E' },
  green = { '#3E6A3C', '#72AA62', '#C4E8A8' },
  water = { '#081824', '#123850', '#6CB4D4' },
  residential = { '#8A6850', '#D0AA8E', '#F0DCC0' },
  lit = { '#B2AC9E', '#ECE8DE', '#FFFFFF' },
  sacred = { '#8A84A6', '#CEC8E4', '#F0ECFF' },
  crimson = { '#16080E', '#36101A', '#B03A4A' },
}
K.ORDER = { 'urban', 'green', 'water', 'residential', 'lit', 'sacred', 'crimson' }

-- Grades.
function K.copy(g)
  local o = L.grid(g.w, g.h)
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do o[y][x] = g[y][x] end end
  return o
end
-- Duplica a linha [row]: o que esta acima sobe 1 px (os pes ficam no chao).
function K.stretch(g, row)
  local o = L.grid(g.w, g.h)
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do o[y][x] = L.get(g, x, y < row and y + 1 or y) end end
  return o
end
-- Tira a linha [row]: o que esta acima desce 1 px.
function K.squash(g, row)
  local o = L.grid(g.w, g.h)
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do o[y][x] = L.get(g, x, y <= row and y - 1 or y) end end
  return o
end
function K.shiftRow(g, y, dx)
  local row = {}
  for x = 0, g.w - 1 do row[x] = L.get(g, x - dx, y) end
  for x = 0, g.w - 1 do g[y][x] = row[x] end
end
function K.swap(g, map)
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local c = map[g[y][x]]
    if c then g[y][x] = c end
  end end
end
function K.stamp(dst, src, dx, dy)
  for y = 0, src.h - 1 do for x = 0, src.w - 1 do
    if src[y][x] ~= '.' then L.set(dst, x + (dx or 0), y + (dy or 0), src[y][x]) end
  end end
end
-- L.put so por cima dos caracteres de [mask].
function K.put(g, x0, y0, rows, mask)
  for j, row in ipairs(rows) do
    for i = 1, #row do
      local c = row:sub(i, i)
      if c ~= '.' then L.set(g, x0 + i - 1, y0 + j - 1, c, mask) end
    end
  end
end
function K.ell(g, cx, cy, rx, ry, c, mask)
  for y = math.floor(cy - ry), math.ceil(cy + ry) do
    for x = math.floor(cx - rx), math.ceil(cx + rx) do
      if ((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2 <= 1 then L.set(g, x, y, c, mask) end
    end
  end
end
-- Traco que afina: discos ao longo dos pontos, raio de r0 a r1.
function K.stroke(g, pts, r0, r1, c, mask)
  local total = 0
  for i = 2, #pts do total = total + math.sqrt((pts[i][1] - pts[i - 1][1]) ^ 2 + (pts[i][2] - pts[i - 1][2]) ^ 2) end
  local done = 0
  for i = 2, #pts do
    local ax, ay, bx, by = pts[i - 1][1], pts[i - 1][2], pts[i][1], pts[i][2]
    local len = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    local n = math.max(1, math.ceil(len * 2))
    for s = 0, n do
      local t = s / n
      local r = r0 + (r1 - r0) * ((done + len * t) / math.max(total, 0.001))
      L.disc(g, ax + (bx - ax) * t, ay + (by - ay) * t, r, c, mask)
    end
    done = done + len
  end
end
-- Luz de cima e da esquerda: em cada rampa 'sombra meio luz', o meio vira luz se ha vazio a ate [nh] px na direcao
-- da luz, e sombra se ha vazio a ate [nl] px na direcao oposta.
function K.relight(g, ramps, nh, nl)
  local mid = {}
  for _, r in ipairs(ramps) do mid[r:sub(2, 2)] = r end
  local out = {}
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    local r = mid[g[y][x]]
    if r then
      local to
      for i = 1, nh do
        if L.get(g, x - math.floor(i * 0.6 + 0.5), y - i) == '.' then to = r:sub(3, 3); break end
      end
      if not to then
        for i = 1, nl do
          if L.get(g, x + math.floor(i * 0.6 + 0.5), y + i) == '.' then to = r:sub(1, 1); break end
        end
      end
      if to then out[#out + 1] = { x, y, to } end
    end
  end end
  for _, p in ipairs(out) do g[p[2]][p[1]] = p[3] end
end
-- Pinta com [c] o vazio fechado dentro da forma (o que nao se alcanca da borda).
function K.fillHoles(g, c)
  local ext, stack = {}, {}
  local function push(x, y)
    if x < 0 or y < 0 or x >= g.w or y >= g.h then return end
    local k = y * g.w + x
    if ext[k] or g[y][x] ~= '.' then return end
    ext[k] = true; stack[#stack + 1] = k
  end
  for i = 0, g.w - 1 do push(i, 0); push(i, g.h - 1); push(0, i); push(g.w - 1, i) end
  while #stack > 0 do
    local k = table.remove(stack)
    local x, y = k % g.w, k // g.w
    push(x - 1, y); push(x + 1, y); push(x, y - 1); push(x, y + 1)
  end
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if g[y][x] == '.' and not ext[y * g.w + x] then g[y][x] = c end
  end end
end
function K.speckle(g, from, to, n, k)
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if g[y][x] == from and hash(x, y, k or 9) % n == 0 then g[y][x] = to end
  end end
end

-- Ajudas de faisca para um quadro de lado [W].
function K.S(W)
  local S = {}
  function S.mir(list)
    local o = {}
    for _, p in ipairs(list) do o[#o + 1] = p; o[#o + 1] = { W - 1 - p[1], p[2], p[3] } end
    return o
  end
  function S.plus(x, y) return { { x, y, 's' }, { x - 1, y }, { x + 1, y }, { x, y - 1 }, { x, y + 1 } } end
  function S.cat(...)
    local o = {}
    for _, t in ipairs({ ... }) do for _, p in ipairs(t) do o[#o + 1] = p end end
    return o
  end
  function S.ring(n, r, phase, cx, cy)
    local o = {}
    for k = 0, n - 1 do
      local a = math.rad(phase + k * 360 / n)
      o[#o + 1] = { (cx or (W - 1) / 2) + r * math.cos(a), (cy or W / 2) + r * 0.9 * math.sin(a), k % 2 == 0 and 's' or 'S' }
    end
    return o
  end
  return S
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

-- Pecas ligadas (8 vizinhos) de uma grade.
local function pieces(g)
  local seen, n = {}, 0
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if g[y][x] ~= '.' and not seen[y * g.w + x] then
      n = n + 1
      local stack = { { x, y } }
      seen[y * g.w + x] = true
      while #stack > 0 do
        local q = table.remove(stack)
        for dy = -1, 1 do for dx = -1, 1 do
          local nx, ny = q[1] + dx, q[2] + dy
          if L.get(g, nx, ny) ~= '.' and not seen[ny * g.w + nx] then
            seen[ny * g.w + nx] = true; stack[#stack + 1] = { nx, ny }
          end
        end end
      end
    end
  end end
  return n
end
local function onBorder(g)
  for i = 0, g.w - 1 do
    if g[0][i] ~= '.' or g[g.h - 1][i] ~= '.' or g[i][0] ~= '.' or g[i][g.w - 1] ~= '.' then return true end
  end
  return false
end

function K.build(spec)
  local name, W = spec.name, spec.size
  local H = W
  local DIR = L.ROOT .. 'creatures/' .. name .. '/'
  local LEG, emit = spec.leg, spec.emit
  local S = K.S(W)
  local sc = W / 28
  local cx, cy = (W - 1) / 2, W / 2
  local warn = {}

  local function split(g, sg)
    local b, l, w = L.grid(g.w, g.h), L.grid(g.w, g.h), L.grid(g.w, g.h)
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      local c = g[y][x]
      local e = emit[c]
      if e then
        b[y][x] = e[1]
        if e[2] == 'l' then l[y][x] = c else w[y][x] = c end
      else b[y][x] = c end
      local s = sg and sg[y][x]
      if s and s ~= '.' then w[y][x] = s end
    end end
    return b, l, w
  end

  local function defaultLean(y) return y < H * 0.4 and 1 or 0 end
  local function move(g, lean, dy)
    local o = L.grid(W, H)
    for y = 0, H - 1 do
      local dx = lean and lean(y) or 0
      for x = 0, W - 1 do
        if g[y][x] ~= '.' then L.set(o, x + dx, y + dy, g[y][x]) end
      end
    end
    return o
  end
  local function erode(g, sg, t, prev)
    for y = 0, H - 1 do for x = 0, W - 1 do
      if g[y][x] ~= '.' then
        local d = math.sqrt(((x - cx) / (W * 0.46)) ^ 2 + ((y - cy) / (H * 0.41)) ^ 2) + (hash(x, y, 7) % 100) / 100 * 0.24 - 0.12
        if d > t then
          g[y][x] = '.'
          local m = d <= prev and 3 or 7
          if hash(x, y, 3) % m == 0 then sg[y][x] = hash(x, y, 4) % 3 == 0 and 's' or 'S' end
        end
      end
    end end
  end
  local function shaped(o)
    local g = spec.pose(o)
    if o.stretch then g = K.stretch(g, o.stretch) end
    if o.squash then g = K.squash(g, o.squash) end
    return g
  end

  local function frame(o, tag)
    local sg, g = L.grid(W, H), L.grid(W, H)
    local dy = o.dy or 0
    if not o.nobody then
      g = shaped(o)
      if o.dark then
        for y = 0, H - 1 do for x = 0, W - 1 do
          if g[y][x] ~= '.' and not emit[g[y][x]] then g[y][x] = spec.dark end
        end end
      end
      if o.erode then erode(g, sg, o.erode[1], o.erode[2]) end
      g = move(g, o.lean and (spec.lean or defaultLean), dy)
      L.outline(g, 'A')
    end
    for _, p in ipairs(o.sparks or {}) do
      local x, y = math.floor(p[1] + 0.5), math.floor(p[2] + 0.5)
      if x >= 1 and y >= 1 and x <= W - 2 and y <= H - 2 then sg[y][x] = p[3] or 'S' end
    end
    local b, l, w = split(g, sg)
    if not o.nobody then
      if onBorder(b) or onBorder(l) then warn[#warn + 1] = tag .. ': encosta na borda' end
      if not o.erode and pieces(b) ~= 1 then warn[#warn + 1] = tag .. ': ' .. pieces(b) .. ' pecas' end
    end
    return { b = b, l = l, w = w, body = not o.nobody,
      -- bob: o tronco sobe dentro da propria pose (a base fica no chao); so entra no body_dy
      dy = dy + (o.stretch and -1 or 0) + (o.squash and 1 or 0) + (o.bob or 0) }
  end

  local function with(o, extra)
    local t = {}
    for k, v in pairs(o) do t[k] = v end
    for k, v in pairs(extra) do t[k] = v end
    return t
  end
  local function P(list) -- posicoes pensadas em 28 px
    local o = {}
    for _, p in ipairs(list) do o[#o + 1] = { p[1] * sc, p[2] * sc, p[3] } end
    return o
  end
  local function plusP(x, y) return S.plus(math.floor(x * sc + 0.5), math.floor(y * sc + 0.5)) end
  local function edge(o)
    local g = shaped(o)
    L.outline(g, 'A')
    local out = {}
    for y = 0, H - 1 do for x = 0, W - 1 do
      -- so o contorno de fora: num corpo cheio, faisca no miolo vira mancha
      local open = L.get(g, x - 1, y) == '.' or L.get(g, x + 1, y) == '.' or L.get(g, x, y - 1) == '.' or L.get(g, x, y + 1) == '.'
      if g[y][x] == 'A' and open and hash(x, y, 1) % 2 == 0 then
        out[#out + 1] = { x, y, hash(x, y, 2) % 4 == 0 and 's' or 'S' }
      end
    end end
    return out
  end
  local function cloud(o, m, scale)
    local g = shaped(o)
    local out = {}
    for y = 0, H - 1 do for x = 0, W - 1 do
      if g[y][x] ~= '.' and hash(x, y, 5) % m == 0 then
        out[#out + 1] = { cx + (x - cx) * scale, cy + (y - cy) * scale, hash(x, y, 6) % 3 == 0 and 's' or 'S' }
      end
    end end
    return out
  end

  local I = spec.idle
  local still = { stretch = false, squash = false, dy = 0, bob = 0 }
  local al = spec.alert or I[1]
  local fps = spec.fps or {}
  local function A(nm, f, list)
    local fr = {}
    for n, o in ipairs(list) do fr[n] = frame(o, nm .. ' ' .. n) end
    return { name = nm, fps = fps[nm] or f, frames = fr }
  end
  local ANIMS = {
    A('idle', 8, I),
    A('drift', 8, { with(I[1], { lean = true }), with(I[2], { lean = true }), with(I[3], { lean = true }), with(I[4], { lean = true }) }),
    A('alert', 6, {
      with(al, { glow = 1 }),
      with(al, { glow = 2, sparks = spec.alert2 or {} }),
      with(al, { glow = 3, sparks = spec.alert3 or {} }),
    }),
    A('flee', 12, {
      with(spec.crouch or I[1], { stretch = false, dy = 0, squash = spec.sq, glow = 3 }),
      with(I[1], with(still, { lean = true, glow = 2, sparks = P { { 10, 26 }, { 8, 25, 's' } } })),
      with(I[2], with(still, { lean = true, dy = -1, sparks = P { { 11, 25, 's' }, { 9, 26 }, { 7, 24 }, { 5, 26 } } })),
      with(I[1], with(still, { lean = true, dy = -2, glow = 2,
        sparks = S.cat(plusP(10, 24), P { { 7, 26 }, { 5, 24 }, { 3, 26 }, { 13, 26 } }) })),
      with(I[2], with(still, { lean = true, dy = -2,
        sparks = P { { 11, 23, 's' }, { 9, 25 }, { 6, 25, 's' }, { 4, 23 }, { 2, 25 }, { 8, 22 } } })),
      with(I[3], with(still, { lean = true, dy = -2, sparks = P { { 10, 24 }, { 7, 23 }, { 4, 25 }, { 1, 24, 's' }, { 12, 25 } } })),
    }),
    A('spawn', 10, {
      { nobody = true, sparks = S.ring(6, 12 * sc, 20) },
      { nobody = true, sparks = S.cat(S.ring(8, 8 * sc, 0), S.ring(4, 12 * sc, 65), S.plus(W // 2, H // 2)) },
      { nobody = true, sparks = S.cat(edge(with(I[1], still)), S.plus(W // 2 - 1, H // 2), S.plus(W // 2, H // 2)) },
      with(I[3], with(still, { dark = true, glow = 3, sparks = S.ring(6, 10 * sc, 40) })),
      with(I[2], with(still, { glow = 2, sparks = S.ring(4, 12 * sc, 10) })),
      with(I[1], with(still, { sparks = P { { 3, 7 }, { 24, 24 } } })),
    }),
    A('tuned', 10, {
      with(I[1], with(still, { glow = 3, sparks = spec.alert2 or {} })),
      with(I[1], with(still, { glow = 3, erode = { 0.80, 9 } })),
      with(I[1], with(still, { glow = 3, erode = { 0.55, 0.80 } })),
      with(I[1], with(still, { glow = 3, erode = { 0.30, 0.55 } })),
      { nobody = true, sparks = cloud(with(I[1], still), 5, 1) },
      { nobody = true, sparks = S.cat(cloud(with(I[1], still), 10, 0.5), S.plus(W // 2, H // 2)) },
    }),
  }

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
      strips(DIR .. name .. '_' .. a.name, a.frames)
    end
    saveSprite(DIR .. name .. '.aseprite', W, H, all, tags)
  end

  -- Variantes: o corpo remapeado pela luminancia no degrade da variante (ou `ramp` explicito, na ordem de
  -- spec.keys) e o acessorio sobre o quadro 0 do idle.
  local VARIANTS = spec.variants
  do
    local lo, hi = 999, -1
    for _, ch in ipairs(spec.keys) do
      local v = lum(LEG[ch]); lo = math.min(lo, v); hi = math.max(hi, v)
    end
    local spr = Sprite(W, H, ColorMode.RGB)
    local out = { '{' }
    for n, v in ipairs(VARIANTS) do
      if v.key ~= K.ORDER[n] then error('variante fora de ordem: ' .. v.key) end
      local g = L.grid(W, H)
      for _, p in ipairs(v.put) do L.put(g, p[1], p[2], p[3]) end
      if v.outline then L.outline(g, 'A') end
      v.legend.A = LEG.A
      v.acc = g
      v.map = {}
      local grad = v.grad or K.GRADS[v.key]
      local pairsOut = {}
      for k, ch in ipairs(spec.keys) do
        local to
        if v.ramp then to = v.ramp[k]
        else
          local t = (lum(LEG[ch]) - lo) / math.max(hi - lo, 1)
          to = t < 0.5 and mix(grad[1], grad[2], t * 2) or mix(grad[2], grad[3], (t - 0.5) * 2)
        end
        v.map[LEG[ch]:lower()] = to:lower()
        pairsOut[#pairsOut + 1] = string.format('"%s": "%s"', LEG[ch]:lower(), to:lower())
      end
      local img = image(g, v.legend)
      savePng(img, DIR .. name .. '_acc_' .. v.key .. '.png')
      if n > 1 then spr:newEmptyFrame() end
      spr:newCel(spr.layers[1], n, img, Point(0, 0))
      local tag = spr:newTag(n, n); tag.name = v.key
      out[#out + 1] = string.format('  "%s": { "map": { %s }, "accessory": "%s_acc_%s.png" }%s',
        v.key, table.concat(pairsOut, ', '), name, v.key, n < #VARIANTS and ',' or '')
    end
    if #VARIANTS ~= 7 then error('faltam variantes') end
    out[#out + 1] = '}'
    spr:saveAs(DIR .. name .. '_acc.aseprite'); spr:close()
    local f = assert(io.open(DIR .. name .. '_variants.json', 'w'))
    f:write(table.concat(out, '\n') .. '\n'); f:close()
  end

  -- O criterio do teste do app: no quadro 0 do idle, cada par de aparencias (comum e as 7 variantes, com o
  -- acessorio) precisa de 12 pixels ou mais em que a luminancia difere mais de 24 ou so um dos dois e transparente.
  -- Aqui o aviso sai abaixo de 20, para passar com folga.
  do
    local f0 = ANIMS[1].frames[1]
    local looks = {}
    local function look(v)
      local o = {}
      for y = 0, H - 1 do for x = 0, W - 1 do
        local c, val = f0.b[y][x], -1
        if c ~= '.' then
          local hex = LEG[c]
          if v and v.map[hex:lower()] then hex = v.map[hex:lower()] end
          val = lum(hex)
        end
        if v then
          local a = L.get(v.acc, x, y - f0.dy)
          if a ~= '.' then val = lum(v.legend[a]) end
        end
        if f0.l[y][x] ~= '.' then val = lum(LEG[f0.l[y][x]]) end
        if f0.w[y][x] ~= '.' then val = lum(LEG[f0.w[y][x]]) end
        o[y * W + x] = val
      end end
      return o
    end
    looks[1] = { 'comum', look(nil) }
    for _, v in ipairs(VARIANTS) do looks[#looks + 1] = { v.key, look(v) } end
    local worst, wn = '', 9999
    for i = 1, #looks do for j = i + 1, #looks do
      local n = 0
      for k = 0, W * H - 1 do
        local p, q = looks[i][2][k], looks[j][2][k]
        if (p < 0) ~= (q < 0) or (p >= 0 and q >= 0 and math.abs(p - q) > 24) then n = n + 1 end
      end
      if n < wn then wn = n; worst = looks[i][1] .. ' x ' .. looks[j][1] end
      if n < 20 then warn[#warn + 1] = 'cinza: ' .. looks[i][1] .. ' x ' .. looks[j][1] .. ' so ' .. n .. ' px' end
    end end
    print(name .. ': par mais parecido em cinza ' .. worst .. ' = ' .. wn .. ' px')
  end

  -- Retrato 96 x 96, 4 quadros: spec.portrait(f) devolve a grade sem contorno e a grade de faiscas.
  local PFPS = spec.pfps or 6
  do
    local frames = {}
    for f = 1, 4 do
      local g, sg = spec.portrait(f)
      L.outline(g, 'A')
      local b, l, w = split(g, sg)
      if onBorder(b) or onBorder(l) or onBorder(w) then warn[#warn + 1] = 'retrato ' .. f .. ': encosta na borda' end
      if pieces(b) ~= 1 then warn[#warn + 1] = 'retrato ' .. f .. ': ' .. pieces(b) .. ' pecas' end
      frames[f] = { b = b, l = l, w = w, ms = 1000 / PFPS }
    end
    strips(DIR .. name .. '_portrait', frames)
    saveSprite(DIR .. name .. '_portrait.aseprite', 96, 96, frames, { { name = 'hover', from = 1, to = 4 } })
  end

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

  -- Folha de conferencia, como a do Humoth: 6 fileiras de animacao com o tom da noite, depois as variantes em cor,
  -- em cinza e com o tom da noite.
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
        local l = 0.299 * c[1] + 0.587 * c[2] + 0.114 * c[3]
        cv[y][x] = { l, l, l }
      end
    end
    local img = Image(CW * Z, CH * Z, ColorMode.RGB)
    for y = 0, CH - 1 do for x = 0, CW - 1 do
      local c = cv[y][x]
      local p = app.pixelColor.rgba(math.floor(c[1] + 0.5), math.floor(c[2] + 0.5), math.floor(c[3] + 0.5), 255)
      for j = 0, Z - 1 do for i = 0, Z - 1 do img:putPixel(x * Z + i, y * Z + j, p) end end
    end end
    local s = Sprite(img.width, img.height, ColorMode.RGB)
    s:newCel(s.layers[1], 1, img, Point(0, 0))
    s:saveAs(DIR .. name .. '_folha.aseprite')
    s:saveCopyAs(DIR .. name .. '_folha.png')
    s:close()
  end
  print('ok ' .. name .. (#warn > 0 and ('\nAVISOS:\n' .. table.concat(warn, '\n')) or ' sem avisos'))
end

return K
