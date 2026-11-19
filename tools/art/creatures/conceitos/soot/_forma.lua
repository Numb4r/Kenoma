-- Formas e sombreado para os conceitos de soot, rill e frond (as três famílias desta sessão usam este arquivo).
-- Uso: local F = dofile(KENOMA_ART .. 'creatures/conceitos/soot/_forma.lua')(C)
--   local P = F.pen(g, k, ox, oy)   -- caneta em unidades do mapa: posição u vira u*k + (k-1)/2 + deslocamento, raio r vira r*k
--   P:ell(cx, cy, rx, ry, c, mask, rot)   P:limb(pts, r0, r1, c, mask)   P:poly(pts, c, mask)   P:px(x, y, c, mask)
--   F.shade(g, src, ramp, o)  -- troca o caractere src pela rampa (do claro ao escuro), luz de cima à esquerda,
--     o = { p = período da hachura em px, ax, ay = direção, jit = tremor, seed, zones = nº de zonas de valor, bias }
return function(C)
  local L = C.L
  local F = {}
  local floor, ceil, sqrt, abs = math.floor, math.ceil, math.sqrt, math.abs

  function F.hash(x, y, k)
    local v = (floor(x) * 73856093) ~ (floor(y) * 19349663) ~ ((k or 0) * 83492791)
    v = v ~ (v >> 13)
    return (v * 1274126177) & 0x7fffffff
  end
  function F.rnd(x, y, k) return (F.hash(x, y, k) % 1000) / 1000 end

  local Pen = {}
  Pen.__index = Pen
  function F.pen(g, k, ox, oy)
    return setmetatable({ g = g, k = k, ox = (ox or 0) + (k - 1) / 2, oy = (oy or 0) + (k - 1) / 2 }, Pen)
  end
  function Pen:X(u) return u * self.k + self.ox end
  function Pen:Y(v) return v * self.k + self.oy end
  function Pen:px(x, y, c, mask) L.set(self.g, self:X(x), self:Y(y), c, mask) end
  -- ponto em pixels da grade, sem escala (para detalhe fino do retrato)
  function Pen:ell(cx, cy, rx, ry, c, mask, rot)
    local k = self.k
    cx, cy, rx, ry = self:X(cx), self:Y(cy), rx * k, ry * k
    local r = math.max(rx, ry) + 1
    local ca, sa = math.cos(math.rad(rot or 0)), math.sin(math.rad(rot or 0))
    for y = floor(cy - r), ceil(cy + r) do
      for x = floor(cx - r), ceil(cx + r) do
        local dx, dy = x - cx, y - cy
        local u, v = dx * ca + dy * sa, -dx * sa + dy * ca
        if (u / rx) ^ 2 + (v / ry) ^ 2 <= 1 then L.set(self.g, x, y, c, mask) end
      end
    end
  end
  local function stamp(g, x, y, r, c, mask)
    if r <= 0.6 then L.set(g, x, y, c, mask); return end
    for yy = floor(y - r), ceil(y + r) do
      for xx = floor(x - r), ceil(x + r) do
        if (xx - x) ^ 2 + (yy - y) ^ 2 <= r * r + 0.2 then L.set(g, xx, yy, c, mask) end
      end
    end
  end
  -- linha quebrada grossa, o raio indo de r0 a r1
  function Pen:limb(pts, r0, r1, c, mask)
    local k, total, acc = self.k, 0, 0
    for i = 1, #pts - 1 do total = total + sqrt((pts[i + 1][1] - pts[i][1]) ^ 2 + (pts[i + 1][2] - pts[i][2]) ^ 2) end
    for i = 1, #pts - 1 do
      local x0, y0, x1, y1 = pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]
      local len = sqrt((x1 - x0) ^ 2 + (y1 - y0) ^ 2)
      local n = math.max(1, ceil(len * k * 2))
      for s = 0, n do
        local t = s / n
        local r = (r0 + (r1 - r0) * (acc + len * t) / math.max(total, 0.001)) * k
        stamp(self.g, self:X(x0 + (x1 - x0) * t), self:Y(y0 + (y1 - y0) * t), r, c, mask)
      end
      acc = acc + len
    end
  end
  function Pen:poly(pts, c, mask)
    local q = {}
    for i, p in ipairs(pts) do q[i] = { self:X(p[1]), self:Y(p[2]) } end
    C.poly(self.g, q, c, mask)
  end
  function Pen:disc(cx, cy, r, c, mask) self:ell(cx, cy, r, r, c, mask) end
  -- faísca solta: um bloco de k px
  function Pen:dot(x, y, c, mask)
    local k = math.max(1, floor(self.k * 0.6 + 0.5))
    local px, py = floor(self:X(x)), floor(self:Y(y))
    L.rect(self.g, px, py, px + k - 1, py + k - 1, c, mask or '.')
  end

  -- Sombreado: t = posição do pixel ao longo do eixo da luz dentro da forma (0 na borda iluminada, 1 na borda escura).
  -- within: caracteres que contam como a mesma forma (padrão: tudo o que não é vazio).
  function F.shade(g, src, ramp, o)
    o = o or {}
    local p, ax, ay = o.p or 1, o.ax or 0.5, o.ay or 1
    local zones = o.zones or (#ramp - 1)
    local cap = o.cap or 40
    local hit = {}
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      if src:find(g[y][x], 1, true) then hit[#hit + 1] = { x, y } end
    end end
    local function solid(x, y)
      local c = L.get(g, x, y)
      if c == '.' then return false end
      return o.within == nil or o.within:find(c, 1, true) ~= nil
    end
    local outp = {}
    for n, q in ipairs(hit) do
      local x, y = q[1], q[2]
      local lt, sh = 0, 0
      while lt < cap and solid(x - lt - 1, y - floor((lt + 1) * (o.ly or 1) + 0.5)) do lt = lt + 1 end
      while sh < cap and solid(x + sh + 1, y + floor((sh + 1) * (o.ly or 1) + 0.5)) do sh = sh + 1 end
      local t = (lt + 0.5) / (lt + sh + 1)
      if o.depth then t = math.min(t, (lt + 0.5) / o.depth) ; if sh < (o.rim or 0) then t = 1 end end
      t = math.max(0, math.min(0.999, t + (o.bias or 0)))
      local idx = floor(t * zones)
      local jit = (o.jit or 0) * F.rnd(floor((x * ay - y * ax) / (o.jw or 2)), 0, o.seed or 1)
      local band = floor((x * ax + y * ay + jit) / p) % 2
      if o.fn then band = o.fn(x, y, band, t) end
      idx = math.min(#ramp - 1, idx + band)
      outp[n] = ramp:sub(idx + 1, idx + 1)
    end
    for n, q in ipairs(hit) do g[q[2]][q[1]] = outp[n] end
  end

  -- copia uma grade em outra com deslocamento
  function F.blit(dst, src, dx, dy)
    for y = 0, src.h - 1 do for x = 0, src.w - 1 do
      if src[y][x] ~= '.' then L.set(dst, x + dx, y + dy, src[y][x]) end
    end end
  end
  -- Tira do corpo tudo o que não está ligado à peça principal (ligação em 8); loose: caracteres só do emissivo, que ficam.
  -- Avisa quando a peça tirada é grande (aí o desenho é que está errado).
  function F.prune(g, loose, tag)
    local id, sizes, n = {}, {}, 0
    local function body(x, y)
      local c = L.get(g, x, y)
      return c ~= '.' and not loose:find(c, 1, true)
    end
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      if body(x, y) and not id[y * g.w + x] then
        n = n + 1; sizes[n] = 0
        local stack = { { x, y } }
        id[y * g.w + x] = n
        while #stack > 0 do
          local q = table.remove(stack)
          sizes[n] = sizes[n] + 1
          for dy = -1, 1 do for dx = -1, 1 do
            local xx, yy = q[1] + dx, q[2] + dy
            if body(xx, yy) and not id[yy * g.w + xx] then id[yy * g.w + xx] = n; stack[#stack + 1] = { xx, yy } end
          end end
        end
      end
    end end
    local main = 1
    for i = 2, n do if sizes[i] > sizes[main] then main = i end end
    for i = 1, n do if i ~= main and sizes[i] > 12 then print('AVISO ' .. (tag or '') .. ': peça solta de ' .. sizes[i] .. ' px tirada') end end
    for k, v in pairs(id) do if v ~= main then g[k // g.w][k % g.w] = '.' end end
    return g
  end
  -- conta caracteres (para acertar o emissivo)
  function F.count(g, chars)
    local n = 0
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do if chars:find(g[y][x], 1, true) then n = n + 1 end end end
    return n
  end
  return F
end
