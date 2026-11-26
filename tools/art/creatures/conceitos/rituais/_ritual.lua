-- Ajudante dos conceitos das espécies de ritual (uma por família, etapa Espírito: mapa 36, retrato 96).
-- A regra do ser de ritual está em docs/art/conceitos/rituais.md; a régua é a do _conceito.lua (C.save confere).
-- Cada build desenha UMA vez, em unidades do mapa (0 a 36), com a caneta P; o retrato é o mesmo desenho em escala 2,6,
-- com a textura feita no pixel do retrato (R.shade trabalha no pixel do quadro, nunca em bloco).
-- Ordem num build: formas com caracteres provisórios -> emissivos e costuras (com máscara) -> R.shade em cada
-- provisório -> (o build chama) contorno, faíscas soltas e C.save.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/conceitos/rituais/<nome>/build.lua')
local ART = assert(KENOMA_ART, 'defina KENOMA_ART (tools/art/, com a barra no fim)')
local C = dofile(ART .. 'creatures/conceitos/_conceito.lua')
C.DIR = ART .. 'creatures/conceitos/rituais/'
local L = C.L
local floor, ceil, sqrt, max, min = math.floor, math.ceil, math.sqrt, math.max, math.min
local R = { C = C, L = L }

function R.hash(x, y, k)
  local v = (x * 73856093) ~ (y * 19349663) ~ (k * 83492791)
  v = v ~ (v >> 13)
  return (v * 1274126177) & 0x7fffffff
end
function R.rnd(x, y, k) return (R.hash(x, y, k) % 1000) / 1000 end

function R.inpoly(u, v, p)
  local c, j = false, #p
  for i = 1, #p do
    local a, b = p[i], p[j]
    if ((a[2] > v) ~= (b[2] > v)) and (u < (b[1] - a[1]) * (v - a[2]) / (b[2] - a[2]) + a[1]) then c = not c end
    j = i
  end
  return c
end

-- Caneta: coordenadas em unidades do mapa; k = escala, (ox, oy) = deslocamento em pixels do quadro.
-- mask: caracteres que podem ser cobertos (nil cobre tudo; ponha '.' para cobrir o vazio).
local Pen = {}
Pen.__index = Pen
function R.pen(g, k, ox, oy) return setmetatable({ g = g, k = k, ox = ox or 0, oy = oy or 0 }, Pen) end

-- f(u, v, x, y): verdadeiro pinta c; um caractere pinta esse caractere.
function Pen:fill(u0, v0, u1, v1, c, mask, f)
  local g, k = self.g, self.k
  for y = max(0, floor(v0 * k + self.oy) - 1), min(g.h - 1, ceil(v1 * k + self.oy) + 1) do
    for x = max(0, floor(u0 * k + self.ox) - 1), min(g.w - 1, ceil(u1 * k + self.ox) + 1) do
      if mask == nil or mask:find(g[y][x], 1, true) then
        local ch = f((x + 0.5 - self.ox) / k, (y + 0.5 - self.oy) / k, x, y)
        if ch then g[y][x] = ch == true and c or ch end
      end
    end
  end
end
function Pen:ell(cx, cy, rx, ry, c, mask)
  self:fill(cx - rx, cy - ry, cx + rx, cy + ry, c, mask, function(u, v) return ((u - cx) / rx) ^ 2 + ((v - cy) / ry) ^ 2 <= 1 end)
end
-- Elipse girada de [a] graus (y para baixo).
function Pen:rell(cx, cy, rx, ry, a, c, mask)
  local ca, sa, rm = math.cos(math.rad(a)), math.sin(math.rad(a)), max(rx, ry)
  self:fill(cx - rm, cy - rm, cx + rm, cy + rm, c, mask, function(u, v)
    local dx, dy = u - cx, v - cy
    return ((dx * ca + dy * sa) / rx) ^ 2 + ((-dx * sa + dy * ca) / ry) ^ 2 <= 1
  end)
end
function Pen:ring(cx, cy, r0, r1, c, mask)
  self:fill(cx - r1, cy - r1, cx + r1, cy + r1, c, mask, function(u, v)
    local d = sqrt((u - cx) ^ 2 + (v - cy) ^ 2)
    return d >= r0 and d <= r1
  end)
end
function Pen:poly(pts, c, mask)
  local u0, v0, u1, v1 = 1e9, 1e9, -1e9, -1e9
  for _, p in ipairs(pts) do u0 = min(u0, p[1]); u1 = max(u1, p[1]); v0 = min(v0, p[2]); v1 = max(v1, p[2]) end
  self:fill(u0, v0, u1, v1, c, mask, function(u, v) return R.inpoly(u, v, pts) end)
end
-- Linha grossa que afina: raio r0 no começo, r1 no fim (0,5 = 1 px no mapa).
function Pen:limb(pts, r0, r1, c, mask)
  local len, acc = {}, 0
  local u0, v0, u1, v1 = 1e9, 1e9, -1e9, -1e9
  for i, p in ipairs(pts) do
    u0 = min(u0, p[1]); u1 = max(u1, p[1]); v0 = min(v0, p[2]); v1 = max(v1, p[2])
    if i < #pts then len[i] = sqrt((pts[i + 1][1] - p[1]) ^ 2 + (pts[i + 1][2] - p[2]) ^ 2); acc = acc + len[i] end
  end
  local rm = max(r0, r1)
  self:fill(u0 - rm, v0 - rm, u1 + rm, v1 + rm, c, mask, function(u, v)
    local s = 0
    for i = 1, #pts - 1 do
      local a, b = pts[i], pts[i + 1]
      local dx, dy = b[1] - a[1], b[2] - a[2]
      local t = max(0, min(1, ((u - a[1]) * dx + (v - a[2]) * dy) / max(1e-6, dx * dx + dy * dy)))
      local d = sqrt((u - a[1] - dx * t) ^ 2 + (v - a[2] - dy * t) ^ 2)
      if d <= r0 + (r1 - r0) * (s + t * len[i]) / max(1e-6, acc) then return true end
      s = s + len[i]
    end
  end)
end

-- Textura no pixel do quadro: devolve de -0,5 (claro) a 0,5 (escuro).
local TEX = {
  noise = function(x, y, s) return R.rnd(x, y, s) - 0.5 end,
  fur = function(x, y, s) return R.rnd(x, (y + (x * 5) % 3) // 3, s) - 0.5 end,
  feather = function(x, y, s)
    if y % 3 == 2 then return 0.45 end
    return ((x + (y // 3) * 2) % 4 == 0) and 0.3 or -0.25
  end,
  stone = function(x, y, s)
    local by = y // 3
    local bx = (x + by * 2) // 4
    if y % 3 == 0 and R.hash(bx, by, s) % 3 > 0 then return 0.4 end
    return R.rnd(bx, by, s) - 0.5
  end,
  metal = function(x, y, s) return ({ -0.35, 0.05, 0.4 })[x % 3 + 1] end,
  scale = function(x, y, s) return ((x + y) % 3 == 0 or (x - y) % 3 == 0) and 0.45 or -0.2 end,
  leaf = function(x, y, s) return ((x + 2 * y) % 5 == 0) and 0.5 or ((x - y) % 3 == 0 and 0.1 or -0.2) end,
}

-- Troca todo pixel [ch] por um degrau de [ramp] (do claro ao escuro): luz de cima à esquerda sobre a caixa do
-- material, borda clara do lado da luz e escura do outro, mais a textura. o = { tex, seed, amp, jit, bias, ax, ay }.
function R.shade(g, ch, ramp, o)
  o = o or {}
  local pts, x0, y0, x1, y1 = {}, 1e9, 1e9, -1, -1
  for y = 0, g.h - 1 do for x = 0, g.w - 1 do
    if g[y][x] == ch then
      pts[#pts + 1] = { x, y }
      x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
    end
  end end
  local n, tex, s = #ramp, TEX[o.tex or 'noise'], o.seed or 1
  for _, p in ipairs(pts) do
    local x, y = p[1], p[2]
    local l = (o.ax or 0.45) * (x - x0) / max(1, x1 - x0) + (o.ay or 0.55) * (y - y0) / max(1, y1 - y0)
    if L.get(g, x + 1, y) == '.' or L.get(g, x, y + 1) == '.' then l = l + 0.25 end
    if L.get(g, x - 1, y) == '.' or L.get(g, x, y - 1) == '.' then l = l - 0.25 end
    local i = floor((l + tex(x, y, s) * (o.amp or 0.7) + (R.rnd(x, y, s + 7) - 0.5) * (o.jit or 0.3) + (o.bias or 0)) * n)
    i = max(0, min(n - 1, i))
    g[y][x] = ramp:sub(i + 1, i + 1)
  end
end

-- Costura do Véu da etapa: 2 px de largura no mapa, caractere 'X' (aceso; o par apagado vem do LIT do build).
function R.seam(P, a, b, mask) P:limb({ a, b }, 1.0, 1.0, 'X', mask) end

-- Faixa de glitch: as linhas v0..v1, entre u0 e u1, andam d unidades (negativo = para a esquerda).
function R.glitch(P, v0, v1, u0, u1, d)
  local g, k = P.g, P.k
  local dd = floor(d * k + 0.5)
  for y = floor(v0 * k + P.oy), floor(v1 * k + P.oy) - 1 do
    local row = {}
    for x = 0, g.w - 1 do row[x] = g[y][x] end
    for x = floor(u0 * k + P.ox), floor(u1 * k + P.ox) do g[y][x] = row[x - dd] or '.' end
  end
end

-- Faíscas soltas (só no emissivo), depois do contorno, onde o quadro está vazio. list = { { u, v, ch } }.
function R.sparks(P, list)
  local g, n = P.g, P.k > 1 and 2 or 1
  for _, q in ipairs(list) do
    local x, y = floor(q[1] * P.k + P.ox), floor(q[2] * P.k + P.oy)
    for dy = 0, n - 1 do for dx = 0, n - 1 do
      if x + dx > 0 and y + dy > 1 and x + dx < g.w - 1 and y + dy < g.h - 1 and g[y + dy][x + dx] == '.' then
        g[y + dy][x + dx] = q[3]
      end
    end end
  end
end

-- spec = { name, LEG, LIT, LOOSE, draw = function(P, g, k), sparks = { { u, v, ch } }, after = function(P, g, k) }
function R.build(spec)
  print(spec.name)
  for _, t in ipairs({ { 'mapa', 36, 1, 0, 0 }, { 'retrato', 96, 2.6, 1.2, 1.2 } }) do
    local g = L.grid(t[2], t[2])
    local P = R.pen(g, t[3], t[4], t[5])
    spec.draw(P, g, t[3])
    L.outline(g, 'A')
    R.sparks(P, spec.sparks or {})
    if spec.after then spec.after(P, g, t[3]) end   -- emissivo solto que não cabe numa lista (só sobre o vazio)
    C.save(spec.name, 'espirito', t[1], g, spec.LEG, spec.LIT, spec.LOOSE)
  end
end

return R
