-- Motor comum das formas Wisp, Bit, Sprig e Wyrm (0.25.1): o mesmo formato de saida do Humoth
-- (tools/art/creatures/humoth/build.lua), com o desenho de cada especie no build.lua da pasta dela.
-- Uso: local F = dofile(<este arquivo>); F.build { name=, W=, LEG=, BODY_KEYS=, EMIT=, BRIGHT=, DARK=, pose=, acc=, portrait= }
--   LEG       caractere -> cor; 'A' contorno, 'S' e 's' faisca solta (so em glow).
--   BODY_KEYS caracteres do corpo que as variantes trocam.
--   EMIT      caractere aceso -> { caractere apagado, 'leds' ou 'glow' }.
--   BRIGHT    caractere de glow -> o mesmo mais forte (alerta, fuga, tuned).
--   DARK      caractere da silhueta escura do spawn.
--   pose(p)   grade sem contorno do quadro; p = 0, 1, 2 (laco), 'alert', 'crouch'. Pode devolver tambem uma
--             lista de faiscas soltas { x, y, c } que acompanham o corpo.
--   acc       chave da variante -> lista de { x, y, linhas } sobre o quadro 0 do idle.
--   ramps     (opcional) chave -> { escuro, medio, claro }.
--   portrait(f) grade 96 x 96 sem contorno do quadro f (1..4) e, opcional, grade de faiscas soltas.
local L = dofile('/home/yuri/Documentos/kenoma/tools/art/npc/_lib.lua')
local F = { L = L }

local function hash(x, y, k)
  local v = (x * 73856093) ~ (y * 19349663) ~ (k * 83492791)
  v = v ~ (v >> 13)
  return (v * 1274126177) & 0x7fffffff
end
F.hash = hash

-- Linhas da largura inteira da grade, a partir de y0 (erro com o numero da linha).
function F.rows(g, y0, rows, tag)
  for j, row in ipairs(rows) do
    if #row ~= g.w then error((tag or '?') .. ' linha ' .. j .. ': ' .. #row .. ' colunas, esperava ' .. g.w .. ': ' .. row) end
  end
  L.put(g, 0, y0, rows)
end

function F.ell(g, cx, cy, rx, ry, c, mask)
  for y = math.floor(cy - ry), math.ceil(cy + ry) do
    for x = math.floor(cx - rx), math.ceil(cx + rx) do
      -- +0.4: sem o pixel sozinho nas pontas da elipse de raio inteiro
      if ((x - cx) / (rx + 0.4)) ^ 2 + ((y - cy) / (ry + 0.4)) ^ 2 <= 1 then L.set(g, x, y, c, mask) end
    end
  end
end

-- Traco de espessura variavel: pts = { { x, y, raio }, ... }.
function F.stroke(g, pts, c, mask)
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i + 1]
    local n = math.max(1, math.ceil(math.max(math.abs(b[1] - a[1]), math.abs(b[2] - a[2])) * 2))
    for k = 0, n do
      local t = k / n
      local x, y, r = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t
      if r < 0.6 then L.set(g, x, y, c, mask) else L.disc(g, x, y, r + 0.4, c, mask) end
    end
  end
end

function F.poly(g, pts, c, mask)
  local y0, y1 = math.huge, -math.huge
  for _, p in ipairs(pts) do y0 = math.min(y0, p[2]); y1 = math.max(y1, p[2]) end
  for y = math.floor(y0), math.ceil(y1) do
    local xs = {}
    for i = 1, #pts do
      local a, b = pts[i], pts[i % #pts + 1]
      if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then
        xs[#xs + 1] = a[1] + (y - a[2]) / (b[2] - a[2]) * (b[1] - a[1])
      end
    end
    table.sort(xs)
    for i = 1, #xs - 1, 2 do
      for x = math.ceil(xs[i]), math.floor(xs[i + 1]) do L.set(g, x, y, c, mask) end
    end
  end
end

-- Luz de cima e da esquerda: dentro do conjunto [set], quem esta a ate k px da borda de cima vira [hi] e quem
-- esta a ate k px da borda de baixo vira [lo].
function F.bevel(g, set, hi, lo, k)
  local function inn(x, y) return set:find(L.get(g, x, y), 1, true) ~= nil end
  local add = {}
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if inn(x, y) then
      local h, l = false, false
      for d = 1, k do
        if not inn(x, y - d) or not inn(x - d, y - d) then h = true end
        if not inn(x, y + d) or not inn(x + d, y + d) then l = true end
      end
      if h and not l and hi then add[#add + 1] = { x, y, hi } elseif l and not h and lo then add[#add + 1] = { x, y, lo } end
    end
  end end
  for _, p in ipairs(add) do g[p[2]][p[1]] = p[3] end
end

function F.plus(x, y)
  return { { x, y, 's' }, { x - 1, y }, { x + 1, y }, { x, y - 1 }, { x, y + 1 } }
end
function F.cat(...)
  local o = {}
  for _, t in ipairs({ ... }) do for _, p in ipairs(t) do o[#o + 1] = p end end
  return o
end

local function rgb(hex)
  return tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
end
local function lum(hex)
  local r, g, b = rgb(hex)
  return 0.299 * r + 0.587 * g + 0.114 * b
end

-- Escada de valor, do mais escuro ao mais claro: crimson, water, urban, green, residential, sacred, lit.
local VARIANTS = {
  { key = 'urban', ramp = { '#2A2C34', '#585C6C', '#B6BAC4' }, legend = { W = '#B6BAC4', w = '#8E92A0' } },
  { key = 'green', ramp = { '#2A3D2C', '#5C8058', '#D4EAC0' }, legend = { L = '#8AB874', l = '#5FB26A', d = '#2F7446' }, outline = true },
  { key = 'water', ramp = { '#0C2231', '#1E4A62', '#9CD0E8' }, legend = { U = '#E8F8FF', u = '#9FD4F0', v = '#5A9AB8' } },
  { key = 'residential', ramp = { '#5A4236', '#A4846A', '#F2E4CC' }, legend = { O = '#A03C2C', o = '#6E261E' }, outline = true },
  { key = 'lit', ramp = { '#807A70', '#D0CABC', '#FFFFFF' }, legend = { N = '#2B2F3D', M = '#40465A' } },
  { key = 'sacred', ramp = { '#5C5674', '#AAA4C0', '#F4F0FF' }, legend = { G = '#F2E6B0', g = '#C8B878' }, outline = true },
  { key = 'crimson', ramp = { '#22101A', '#5A1E2E', '#E87080' }, legend = { R = '#FF5A6A', r = '#C03048' } },
}

function F.build(S)
  local W, H = S.W, S.W
  local LEG = S.LEG
  local DIR = L.ROOT .. 'creatures/' .. S.name .. '/'
  local CX, CY = (W - 1) / 2, W / 2
  local K = W / 28
  local fps = S.fps or {}

  local function bright(g, mode)
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      local b = S.BRIGHT[g[y][x]]
      if b and (mode == 'all' or (x + y) % 2 == 0) then g[y][x] = b end
    end end
  end
  local function leanDx(y)
    return (y <= math.floor(H * 6 / 28) and 2) or (y <= math.floor(H * 12 / 28) and 1) or (y >= math.floor(H * 22 / 28) and -1) or 0
  end
  local function move(g, lean, dy)
    local o = L.grid(W, H)
    for y = 0, H - 1 do
      local dx = lean and leanDx(y) or 0
      for x = 0, W - 1 do
        if g[y][x] ~= '.' then L.set(o, x + dx, y + dy, g[y][x]) end
      end
    end
    return o
  end
  local function erode(g, sg, t, prev)
    for y = 0, H - 1 do for x = 0, W - 1 do
      if g[y][x] ~= '.' then
        local d = math.sqrt(((x - CX) / (W * 0.46)) ^ 2 + ((y - CY) / (W * 0.41)) ^ 2) + (hash(x, y, 7) % 100) / 100 * 0.24 - 0.12
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
      local e = S.EMIT[c]
      if e then
        b[y][x] = e[1]
        if e[2] == 'leds' then l[y][x] = c else w[y][x] = c end
      else b[y][x] = c end
      local s = sg and sg[y][x]
      if s and s ~= '.' then w[y][x] = s end
    end end
    return b, l, w
  end
  local function frame(o)
    local sg, g = L.grid(W, H), L.grid(W, H)
    if not o.nobody then
      local extra
      g, extra = S.pose(o.p == 'crouch' and 2 or o.p or 0)
      if o.p == 'crouch' then -- antecipacao: a metade de cima desce 1 px sobre o tronco
        for y = math.floor(CY) + 2, 1, -1 do g[y] = g[y - 1] end
        g[0] = L.grid(W, 1)[0]
      end
      if o.glow then bright(g, o.glow) end
      if o.dark then
        for y = 0, H - 1 do for x = 0, W - 1 do
          if g[y][x] ~= '.' and not S.EMIT[g[y][x]] then g[y][x] = S.DARK end
        end end
      end
      if o.erode then erode(g, sg, o.erode[1], o.erode[2]) end
      g = move(g, o.lean, o.dy or 0)
      L.outline(g, 'A')
      if not o.erode then
        for _, p in ipairs(extra or {}) do
          local y = math.floor(p[2] + 0.5)
          local x = p[1] + (o.lean and leanDx(y) or 0)
          if L.get(g, x, y + (o.dy or 0)) == '.' then L.set(sg, x, y + (o.dy or 0), p[3] or 'S') end
        end
      end
    end
    for _, p in ipairs(o.sparks or {}) do
      local x, y = math.floor(p[1] + 0.5), math.floor(p[2] + 0.5)
      if x >= 1 and y >= 1 and x <= W - 2 and y <= H - 2 and g[y][x] == '.' then sg[y][x] = p[3] or 'S' end
    end
    local b, l, w = split(g, sg)
    return { b = b, l = l, w = w, dy = o.dy or 0, body = not o.nobody, eroded = o.erode ~= nil }
  end

  -- Faiscas.
  local function ring(n, r, phase)
    local o = {}
    for k = 0, n - 1 do
      local a = math.rad(phase + k * 360 / n)
      o[#o + 1] = { CX + r * K * math.cos(a), CY + r * K * 0.9 * math.sin(a), k % 2 == 0 and 's' or 'S' }
    end
    return o
  end
  local function trail(list) -- pontos do rastro da fuga, na grade de 28
    local o = {}
    for _, p in ipairs(list) do o[#o + 1] = { p[1] * K, (p[2] - 1) * K, p[3] } end
    return o
  end
  local function outlineSparks()
    local g = S.pose(2)
    L.outline(g, 'A')
    local o = {}
    for y = 0, H - 1 do for x = 0, W - 1 do
      if g[y][x] == 'A' and hash(x, y, 1) % 2 == 0 then o[#o + 1] = { x, y, hash(x, y, 2) % 4 == 0 and 's' or 'S' }
      elseif g[y][x] ~= '.' and g[y][x] ~= 'A' and hash(x, y, 2) % 9 == 0 then o[#o + 1] = { x, y } end
    end end
    return o
  end
  local function cloud(m, scale)
    local g = S.pose(0)
    local o = {}
    for y = 0, H - 1 do for x = 0, W - 1 do
      if g[y][x] ~= '.' and hash(x, y, 5) % m == 0 then
        o[#o + 1] = { CX + (x - CX) * scale, CY + (y - CY) * scale, hash(x, y, 6) % 3 == 0 and 's' or 'S' }
      end
    end end
    return o
  end
  local cat, plus = F.cat, F.plus
  local c = math.floor(CY)

  local ANIMS = {
    { name = 'idle', fps = fps.idle or 8, frames = {
      frame { p = 0, dy = 0 }, frame { p = 1, dy = -1 }, frame { p = 2, dy = -1 }, frame { p = 1, dy = 0 },
    } },
    { name = 'drift', fps = fps.drift or 8, frames = {
      frame { p = 0, lean = true, dy = 0 }, frame { p = 1, lean = true, dy = -1 },
      frame { p = 2, lean = true, dy = -1 }, frame { p = 1, lean = true, dy = 0 },
    } },
    { name = 'alert', fps = fps.alert or 6, frames = {
      frame { p = 'alert' },
      frame { p = 'alert', glow = 'alt', sparks = ring(4, 12, 35) },
      frame { p = 'alert', glow = 'all', sparks = cat(ring(8, 12.5, 12), ring(4, 10.5, 60)) },
    } },
    { name = 'flee', fps = fps.flee or 12, frames = {
      frame { p = 'crouch', dy = 1, glow = 'all' },
      frame { p = 0, lean = true, dy = 0, glow = 'alt', sparks = trail { { 10, 27 }, { 8, 26, 's' } } },
      frame { p = 1, lean = true, dy = -1, sparks = trail { { 11, 26, 's' }, { 9, 27 }, { 7, 25 }, { 5, 27 } } },
      frame { p = 0, lean = true, dy = -2, glow = 'alt',
        sparks = trail(cat(plus(10, 25), { { 7, 27 }, { 5, 25 }, { 3, 27 }, { 13, 27 } })) },
      frame { p = 1, lean = true, dy = -2,
        sparks = trail { { 11, 24, 's' }, { 9, 26 }, { 6, 26, 's' }, { 4, 24 }, { 2, 26 }, { 8, 23 } } },
      frame { p = 2, lean = true, dy = -2, sparks = trail { { 10, 25 }, { 7, 24 }, { 4, 26 }, { 2, 25, 's' }, { 12, 26 } } },
    } },
    { name = 'spawn', fps = fps.spawn or 10, frames = {
      frame { nobody = true, sparks = ring(6, 12, 20) },
      frame { nobody = true, sparks = cat(ring(8, 8, 0), ring(4, 12, 65), plus(c, c)) },
      frame { nobody = true, sparks = cat(outlineSparks(), plus(c - 1, c), plus(c, c)) },
      frame { p = 2, dark = true, glow = 'all', sparks = ring(6, 12, 40) },
      frame { p = 1, glow = 'alt', sparks = ring(4, 12.5, 10) },
      frame { p = 0, sparks = { { 2, 6 * K }, { W - 3, H - 4 } } },
    } },
    { name = 'tuned', fps = fps.tuned or 10, frames = {
      frame { p = 0, glow = 'all', sparks = ring(4, 12.5, 100) },
      frame { p = 0, glow = 'all', erode = { 0.80, 9 } },
      frame { p = 0, glow = 'all', erode = { 0.55, 0.80 } },
      frame { p = 0, glow = 'all', erode = { 0.30, 0.55 } },
      frame { nobody = true, sparks = cloud(5, 1) },
      frame { nobody = true, sparks = cat(cloud(10, 0.5), plus(c, c)) },
    } },
  }

  -- Conferencia: corpo fora da borda e numa peca so (menos os quadros que se desfazem).
  for _, a in ipairs(ANIMS) do
    for n, f in ipairs(a.frames) do
      local edge, seen, comps = false, {}, 0
      for y = 0, H - 1 do for x = 0, W - 1 do
        if f.b[y][x] ~= '.' then
          if x == 0 or y == 0 or x == W - 1 or y == H - 1 then edge = true end
          if not seen[y * W + x] then
            comps = comps + 1
            local stack = { { x, y } }
            seen[y * W + x] = true
            while #stack > 0 do
              local q = table.remove(stack)
              for dy = -1, 1 do for dx = -1, 1 do
                local nx, ny = q[1] + dx, q[2] + dy
                if L.get(f.b, nx, ny) ~= '.' and not seen[ny * W + nx] then seen[ny * W + nx] = true; stack[#stack + 1] = { nx, ny } end
              end end
            end
          end
        end
      end end
      if edge then print('BORDA ' .. S.name .. ' ' .. a.name .. ' ' .. n) end
      if comps > 1 and not f.eroded then print('SOLTA ' .. S.name .. ' ' .. a.name .. ' ' .. n .. ': ' .. comps .. ' pecas') end
    end
  end

  -- Saida.
  local function image(g, legend)
    local img = Image(g.w, g.h, ColorMode.RGB)
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      local ch = g[y][x]
      if ch ~= '.' then
        if not legend[ch] then error(S.name .. ' sem cor: ' .. ch) end
        local r, gg, b = rgb(legend[ch])
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
      strips(DIR .. S.name .. '_' .. a.name, a.frames)
    end
    saveSprite(DIR .. S.name .. '.aseprite', W, H, all, tags)
  end

  -- Variantes: o corpo troca de cor pela ordem de valor das cores da base; acessorio sobre o quadro 0 do idle.
  local vars = {}
  do
    local order = {}
    for _, ch in ipairs(S.BODY_KEYS) do order[#order + 1] = ch end
    table.sort(order, function(a, b) return lum(LEG[a]) < lum(LEG[b]) end)
    local t = {}
    -- ate 0.75: o grosso do corpo fica perto do tom medio da variante, que e o que faz a escada de valor
    for i, ch in ipairs(order) do t[ch] = #order > 1 and (i - 1) / (#order - 1) * 0.75 or 0.5 end
    local function mix3(r, k)
      local a, b = r[1], r[2]
      if k > 0.5 then a, b, k = r[2], r[3], k - 0.5 end
      k = k * 2
      local ar, ag, ab = rgb(a)
      local br, bg, bb = rgb(b)
      return string.format('#%02x%02x%02x', math.floor(ar + (br - ar) * k + 0.5), math.floor(ag + (bg - ag) * k + 0.5),
        math.floor(ab + (bb - ab) * k + 0.5))
    end
    local spr = Sprite(W, H, ColorMode.RGB)
    local out = { '{' }
    for n, base in ipairs(VARIANTS) do
      local v = { key = base.key, outline = base.outline, legend = { A = LEG.A }, map = {} }
      for k2, hex in pairs(base.legend) do v.legend[k2] = hex end
      local ramp = (S.ramps and S.ramps[v.key]) or base.ramp
      local g = L.grid(W, H)
      for _, p in ipairs(S.acc[v.key] or error(S.name .. ' sem acessorio ' .. v.key)) do L.put(g, p[1], p[2], p[3]) end
      if v.outline then L.outline(g, 'A') end
      v.acc = g
      local pairsOut = {}
      for _, ch in ipairs(S.BODY_KEYS) do
        local to = mix3(ramp, t[ch])
        v.map[LEG[ch]:lower()] = to
        pairsOut[#pairsOut + 1] = string.format('"%s": "%s"', LEG[ch]:lower(), to)
      end
      local img = image(g, v.legend)
      savePng(img, DIR .. S.name .. '_acc_' .. v.key .. '.png')
      if n > 1 then spr:newEmptyFrame() end
      spr:newCel(spr.layers[1], n, img, Point(0, 0))
      local tag = spr:newTag(n, n); tag.name = v.key
      out[#out + 1] = string.format('  "%s": { "map": { %s }, "accessory": "%s_acc_%s.png" }%s',
        v.key, table.concat(pairsOut, ', '), S.name, v.key, n < #VARIANTS and ',' or '')
      vars[n] = v
    end
    out[#out + 1] = '}'
    spr:saveAs(DIR .. S.name .. '_acc.aseprite'); spr:close()
    local f = assert(io.open(DIR .. S.name .. '_variants.json', 'w'))
    f:write(table.concat(out, '\n') .. '\n'); f:close()
  end

  -- Retrato 96 x 96, 4 quadros. So pode usar as cores do corpo que estao no mapa, as apagadas e as emissivas.
  local PFPS = fps.portrait or 6
  do
    local ok = { A = true, S = true, s = true, ['.'] = true }
    for _, ch in ipairs(S.BODY_KEYS) do ok[ch] = true end
    for ch, e in pairs(S.EMIT) do ok[ch] = true; ok[e[1]] = true end
    local frames = {}
    for f = 1, 4 do
      local g, sg = S.portrait(f)
      L.outline(g, 'A')
      for y = 0, 95 do for x = 0, 95 do
        if not ok[g[y][x]] then error(S.name .. ' retrato: cor fora do mapa: ' .. g[y][x]) end
        if g[y][x] ~= '.' and (x == 0 or y == 0 or x == 95 or y == 95) then print('BORDA ' .. S.name .. ' retrato ' .. f) end
      end end
      local b, l, w = split(g, sg)
      frames[f] = { b = b, l = l, w = w, ms = 1000 / PFPS }
    end
    strips(DIR .. S.name .. '_portrait', frames)
    saveSprite(DIR .. S.name .. '_portrait.aseprite', 96, 96, frames, { { name = 'hover', from = 1, to = 4 } })
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
    local f = assert(io.open(DIR .. S.name .. '.json', 'w'))
    f:write('{\n  "frame": ' .. W .. ',\n  "anims": {\n' .. table.concat(an, ',\n') .. '\n  },\n  "body_dy": {\n'
      .. table.concat(dy, ',\n') .. '\n  },\n  "body_visible": {\n' .. table.concat(vis, ',\n')
      .. '\n  },\n  "portrait": { "frame": 96, "frames": 4, "fps": ' .. PFPS .. ' }\n}\n')
    f:close()
  end

  -- Folha de conferencia, como a do Humoth: 6 fileiras de animacao com o tom da noite, depois as variantes em
  -- cor, em cinza e com o tom da noite.
  do
    local PITCH, M, Z = W + 2, 4, 4
    local CW, CH = M * 2 + PITCH * 8 - 2, M * 2 + PITCH * 9 - 2
    local NIGHT, NA = { 0x14, 0x10, 0x33 }, 0.58
    local function night(p)
      return { p[1] * (1 - NA) + NIGHT[1] * NA, p[2] * (1 - NA) + NIGHT[2] * NA, p[3] * (1 - NA) + NIGHT[3] * NA }
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
        local ch = f.b[y][x]
        local px
        if ch ~= '.' then
          local hex = LEG[ch]
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
    -- O criterio do teste do app: no quadro 0 do idle, cada par de aparencias precisa de 12 pixels ou mais em que a
    -- luminancia difere mais de 24 (ou um e transparente e o outro nao). Aqui avisa abaixo de 20, com os emissivos
    -- por cima contando como iguais (o caso mais apertado).
    do
      local function look(v)
        local o = {}
        for y = 0, H - 1 do for x = 0, W - 1 do
          local ch, lm = idle0.b[y][x], nil
          if ch ~= '.' then
            local hex = LEG[ch]
            if v and v.map[hex:lower()] then hex = v.map[hex:lower()] end
            lm = lum(hex)
          end
          if v and v.acc[y][x] ~= '.' then lm = lum(v.legend[v.acc[y][x]]) end
          if idle0.l[y][x] ~= '.' or idle0.w[y][x] ~= '.' then lm = -1000 end
          o[y * W + x] = lm
        end end
        return o
      end
      local looks, names = { look(nil) }, { 'comum' }
      for n, v in ipairs(vars) do looks[n + 1] = look(v); names[n + 1] = v.key end
      for i = 1, #looks do for j = i + 1, #looks do
        local d = 0
        for k = 0, W * H - 1 do
          local a, b = looks[i][k], looks[j][k]
          if (a == nil) ~= (b == nil) or (a and b and math.abs(a - b) > 24) then d = d + 1 end
        end
        if d < 20 then print('PARECIDAS ' .. S.name .. ' ' .. names[i] .. ' x ' .. names[j] .. ': ' .. d) end
        if not looks.min or d < looks.min then looks.min = d; looks.pair = names[i] .. ' x ' .. names[j] end
      end end
      print('menor par ' .. S.name .. ': ' .. looks.pair .. ' = ' .. looks.min)
    end
    for r = 6, 8 do
      cell(0, r, idle0, nil, r == 8)
      for n, v in ipairs(vars) do cell(n, r, idle0, v, r == 8) end
    end
    for y = M + 7 * PITCH - 1, M + 8 * PITCH - 2 do
      for x = 0, CW - 1 do
        local p = cv[y][x]
        local lm = 0.299 * p[1] + 0.587 * p[2] + 0.114 * p[3]
        cv[y][x] = { lm, lm, lm }
      end
    end
    local img = Image(CW * Z, CH * Z, ColorMode.RGB)
    for y = 0, CH - 1 do for x = 0, CW - 1 do
      local p = cv[y][x]
      local col = app.pixelColor.rgba(math.floor(p[1] + 0.5), math.floor(p[2] + 0.5), math.floor(p[3] + 0.5), 255)
      for j = 0, Z - 1 do for i = 0, Z - 1 do img:putPixel(x * Z + i, y * Z + j, col) end end
    end end
    local s = Sprite(img.width, img.height, ColorMode.RGB)
    s:newCel(s.layers[1], 1, img, Point(0, 0))
    s:saveAs(DIR .. S.name .. '_folha.aseprite')
    s:saveCopyAs(DIR .. S.name .. '_folha.png')
    s:close()
  end
  print('ok ' .. S.name)
end

return F
