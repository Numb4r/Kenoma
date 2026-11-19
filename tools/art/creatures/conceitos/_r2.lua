-- Ferramentas de desenho da rodada 2 dos conceitos (as peças refeitas de cada família usam este arquivo).
-- Uso, no build.lua da família, depois de carregar o _conceito.lua em C:
--   local R = dofile(KENOMA_ART .. 'creatures/conceitos/_r2.lua')(C)
--   local d = R.ctx(48 * k, k)            -- quadro de 48 no mapa; k = 2 dá o retrato com textura mais fina
--   d:layer(function(t) t:ell(24, 20, 6, 4, R.mat('abc', R.diag(1), R.lum(24, 20, 6, 4))) end)
--   return d.g
-- As formas são em unidades do mapa (1 = 1 px no mapa); a textura é por pixel. fn é um caractere ou
-- function(x, y, u, v) (pixel e unidade do mapa). R.ctx(S, k, ox, oy): ox, oy deslocam em pixels (busto do Arquétipo).
-- KENOMA_SO = { entidade = true, ... } antes do dofile do build grava só essas etapas (R.skip).
return function(C)
  local L = C.L
  local floor, ceil, max, min, abs, sin, cos, rad = math.floor, math.ceil, math.max, math.min, math.abs, math.sin, math.cos, math.rad
  local R, D = {}, {}
  D.__index = D

  function R.skip(stage) return KENOMA_SO ~= nil and not KENOMA_SO[stage] end
  function R.hash(x, y, s)
    local v = (x * 73856093) ~ (y * 19349663) ~ ((s or 0) * 83492791)
    v = v ~ (v >> 13)
    return ((v * 1274126177) & 0x7fffffff) / 0x7fffffff
  end
  -- tom da rampa pal (escuro -> claro) em v (0..1), alternando com o vizinho mais claro quando st
  function R.pick(pal, v, st)
    local i = floor(max(0, min(1, v)) * (#pal - 2) + 0.5) + (st and 1 or 0)
    return pal:sub(i + 1, i + 1)
  end
  function R.diag(p) return function(x, y) return floor((x + y) / p) % 2 == 0 end end
  function R.gaid(p) return function(x, y) return floor((x - y) / p) % 2 == 0 end end
  function R.ver(p) return function(x, y) return floor(x / p) % 2 == 0 end end
  function R.hor(p) return function(x, y) return floor(y / p) % 2 == 0 end end
  function R.chk(p) return function(x, y) return (floor(x / p) + floor(y / p)) % 2 == 0 end end
  function R.noise(p, s) return function(x, y) return R.hash(floor(x / p), floor(y / p), s) > 0.5 end end
  function R.chev(cx, p) return function(x, y) return floor((y + abs(x - cx) * 0.7) / p) % 2 == 0 end end
  -- luz de cima à esquerda sobre uma elipse; e a mesma por uma direção só
  function R.lum(cx, cy, rx, ry) return function(u, v) return 0.5 - 0.3 * (u - cx) / rx - 0.4 * (v - cy) / ry end end
  function R.flat(v) return function() return v end end
  -- material: rampa + padrão + luz
  function R.mat(pal, pat, light)
    if type(light) == 'number' then light = R.flat(light) end
    return function(x, y, u, v) return R.pick(pal, light(u, v), pat(x, y)) end
  end

  function R.ctx(S, k, ox, oy)
    return setmetatable({ g = L.grid(S, S), S = S, k = k, ox = ox or 0, oy = oy or 0 }, D)
  end
  function D:X(u) return u * self.k + (self.k - 1) / 2 + self.ox end
  function D:Y(v) return v * self.k + (self.k - 1) / 2 + self.oy end
  function D:th(w) return max(1, floor((w or 1) * self.k + 0.5)) end
  function D:pp() return max(1, floor(self.k / 2 + 0.5)) end
  local function put(d, x, y, fn, mask)
    if x < 0 or y < 0 or x >= d.S or y >= d.S then return end
    local ch = fn
    if type(fn) == 'function' then
      ch = fn(x, y, (x - d.ox - (d.k - 1) / 2) / d.k, (y - d.oy - (d.k - 1) / 2) / d.k)
    end
    if ch then L.set(d.g, x, y, ch, mask) end
  end
  function D:ell(cx, cy, rx, ry, fn, mask)
    local X, Y, k = self:X(cx), self:Y(cy), self.k
    for y = max(0, floor(Y - ry * k)), min(self.S - 1, ceil(Y + ry * k)) do
      for x = max(0, floor(X - rx * k)), min(self.S - 1, ceil(X + rx * k)) do
        if ((x - X) / (rx * k)) ^ 2 + ((y - Y) / (ry * k)) ^ 2 <= 1 then put(self, x, y, fn, mask) end
      end
    end
  end
  function D:cap(x0, y0, x1, y1, r0, r1, fn, mask)
    local k = self.k
    x0, y0, x1, y1, r0, r1 = self:X(x0), self:Y(y0), self:X(x1), self:Y(y1), r0 * k, r1 * k
    local dx, dy = x1 - x0, y1 - y0
    local l2, rr = dx * dx + dy * dy, max(r0, r1)
    for y = max(0, floor(min(y0, y1) - rr)), min(self.S - 1, ceil(max(y0, y1) + rr)) do
      for x = max(0, floor(min(x0, x1) - rr)), min(self.S - 1, ceil(max(x0, x1) + rr)) do
        local t = l2 == 0 and 0 or max(0, min(1, ((x - x0) * dx + (y - y0) * dy) / l2))
        if (x - x0 - dx * t) ^ 2 + (y - y0 - dy * t) ^ 2 <= (r0 + (r1 - r0) * t) ^ 2 then put(self, x, y, fn, mask) end
      end
    end
  end
  function D:poly(pts, fn, mask)
    local p, y0, y1 = {}, math.huge, -math.huge
    for i, q in ipairs(pts) do
      p[i] = { self:X(q[1]), self:Y(q[2]) }
      y0 = min(y0, p[i][2]); y1 = max(y1, p[i][2])
    end
    for y = max(0, floor(y0)), min(self.S - 1, ceil(y1)) do
      local xs = {}
      for i = 1, #p do
        local a, b = p[i], p[i % #p + 1]
        if (a[2] <= y and b[2] > y) or (b[2] <= y and a[2] > y) then
          xs[#xs + 1] = a[1] + (y - a[2]) / (b[2] - a[2]) * (b[1] - a[1])
        end
      end
      table.sort(xs)
      for i = 1, #xs - 1, 2 do
        for x = max(0, ceil(xs[i] - 0.5)), min(self.S - 1, floor(xs[i + 1] + 0.5)) do put(self, x, y, fn, mask) end
      end
    end
  end
  -- linha quebrada de espessura w (unidades do mapa); b entra a cada três passos
  function D:wire(pts, a, b, w, mask)
    local th = self:th(w or 0.5)
    local n, o = 0, (th - 1) / 2
    for i = 1, #pts - 1 do
      local x0, y0, x1, y1 = self:X(pts[i][1]), self:Y(pts[i][2]), self:X(pts[i + 1][1]), self:Y(pts[i + 1][2])
      local m = max(abs(x1 - x0), abs(y1 - y0))
      for s = 0, floor(m) do
        local t = m == 0 and 0 or s / m
        n = n + 1
        local ch = (b and (n // th) % 3 == 0) and b or a
        local x, y = floor(x0 + (x1 - x0) * t - o + 0.5), floor(y0 + (y1 - y0) * t - o + 0.5)
        for dy = 0, th - 1 do for dx = 0, th - 1 do put(self, x + dx, y + dy, ch, mask) end end
      end
    end
  end
  function D:rect(x0, y0, x1, y1, fn, mask)
    for y = floor(self:Y(y0) - (self.k - 1) / 2), floor(self:Y(y1) + (self.k - 1) / 2) do
      for x = floor(self:X(x0) - (self.k - 1) / 2), floor(self:X(x1) + (self.k - 1) / 2) do put(self, x, y, fn, mask) end
    end
  end
  -- faísca solta (só no vazio)
  function D:dot(u, v, ch)
    local s, x, y = self:th(0.6), floor(self:X(u)), floor(self:Y(v))
    for dy = 0, s - 1 do for dx = 0, s - 1 do put(self, x + dx, y + dy, ch, '.') end end
  end
  -- camada: desenha à parte, contorna e cola por cima (o contorno separa do que está atrás)
  function D:layer(draw, solid)
    local t = R.ctx(self.S, self.k, self.ox, self.oy)
    draw(t)
    if solid ~= false then L.outline(t.g, 'A', solid) end
    for y = 0, self.S - 1 do for x = 0, self.S - 1 do
      if t.g[y][x] ~= '.' then self.g[y][x] = t.g[y][x] end
    end end
    return t
  end
  -- borda de luz: os pixels de [chars] encostados no vazio (de cima e da esquerda, ou em volta com all) viram c
  function D:rim(chars, c, all, w, skip)
    local g = self.g
    for _ = 1, self:th(w or 0.5) do
      local add = {}
      local function e(x, y) local q = L.get(g, x, y); return q == '.' or q == c end
      for y = 0, g.h - 1 do for x = 0, g.w - 1 do
        if chars:find(g[y][x], 1, true) and (e(x - 1, y) or e(x, y - 1) or (all and (e(x + 1, y) or e(x, y + 1))))
          and not (skip and R.hash(x // skip, y // skip, 4) < 0.3) then add[#add + 1] = { x, y } end
      end end
      for _, q in ipairs(add) do g[q[2]][q[1]] = c end
    end
  end
  -- costura do Véu: linha de z (aceso, com par apagado na legenda) de largura w, com pontos atravessados a cada
  -- step; só pinta por cima dos caracteres de mask (o corpo), nunca no vazio
  function D:suture(pts, z, w, step, mask)
    self:wire(pts, z, nil, w, mask)
    if not step then return end
    for i = 1, #pts - 1 do
      local a, b = pts[i], pts[i + 1]
      local dx, dy = b[1] - a[1], b[2] - a[2]
      local len = math.sqrt(dx * dx + dy * dy)
      local nx, ny = -dy / len, dx / len
      for s = step / 2, len, step do
        local x, y = a[1] + dx * s / len, a[2] + dy * s / len
        self:wire({ { x - nx * (w + 0.8), y - ny * (w + 0.8) }, { x + nx * (w + 0.8), y + ny * (w + 0.8) } }, z, nil, 0.5, mask)
      end
    end
  end
  -- o vão: inside(u, v) devolve 0 (centro) a 1 (borda) ou nil. Abre o buraco no corpo; a borda fica em X, o meio
  -- em xadrez de Y que rareia para o centro. X e Y são soltos (só emissivo).
  function D:vao(inside, X, Y, edge)
    local g, pk = self.g, self:pp()
    edge = edge or 0.72
    for y = 0, self.S - 1 do for x = 0, self.S - 1 do
      local t = inside((x - self.ox - (self.k - 1) / 2) / self.k, (y - self.oy - (self.k - 1) / 2) / self.k)
      if t then
        g[y][x] = '.'
        if t > edge then g[y][x] = X
        elseif t > 0.3 and (x // pk + y // pk) % 2 == 0 then g[y][x] = Y
        elseif t > 0.12 and (x // pk) % 2 == 0 and (y // pk) % 2 == 0 then g[y][x] = Y end
      end
    end end
  end
  -- copia a metade esquerda sobre a direita em torno de cx (unidades do mapa)
  function D:mirror(cx)
    local X = self:X(cx)
    for y = 0, self.S - 1 do for x = 0, floor(X) do
      local m = floor(2 * X - x + 0.5)
      if m > x and m < self.S then self.g[y][m] = self.g[y][x] end
    end end
  end
  function R.fit(src, size)
    local g = L.grid(size, size)
    local ox, oy = (size - src.w) // 2, (size - src.h) // 2
    for y = 0, src.h - 1 do for x = 0, src.w - 1 do
      if src[y][x] ~= '.' then L.set(g, x + ox, y + oy, src[y][x]) end
    end end
    return g
  end
  return R
end
