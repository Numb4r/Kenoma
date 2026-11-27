-- Cairnhollow (clod.ritual), arte final: o tatu-bola fechado em bola no chão, de perfil, com o terço direito aberto como
-- geodo partido: lábio claro de casca, fundo escuro, coroa de cinco cachos de cristal (11 prismas, cada um com eixo próprio), e pela abertura
-- a cabeça pequena (olho fechado em todo quadro) e as duas mãos de duas garras agarradas ao lábio.
-- Silhueta e coordenadas do conceito (conceitos/rituais/cairnhollow/build.lua), refeita no kit Clod (_clod.lua).
-- A luz que vazava pelas juntas mora na coroa; sobra uma junta acesa (a do meio), e a de lon -0,275 acende no alerta.
-- Camadas: corpo; leds = a ponta de cada prisma (I, T); glow = facetas dos prismas, a junta, as duas costuras e a poeira.
-- Animação: a casca respira 1 px e a base fica no chão; a luz corre na coroa; cabeça e mãos paradas (recuam no alerta,
-- somem na abertura na fuga e no spawn). O TOOTH (comprimento) e depois ROOT são os botões do emissivo (mapa, retrato).
-- Rodar: tools/art/rodar.sh tools/art/creatures/cairnhollow/build.lua
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_clod.lua')
local L = C.L
local floor, sqrt, abs, max = math.floor, math.sqrt, math.abs, math.max
local dseg, inpoly = C.dseg, C.inpoly

local OPEN = { { 19, 9.2 }, { 22, 12.5 }, { 19.5, 15.5 }, { 16.5, 20.5 }, { 19.5, 25.5 }, { 22, 28.5 }, { 19, 31.8 }, { 24, 30.2 },
  { 27.2, 25 }, { 28, 20.5 }, { 27.2, 16 }, { 24, 10.8 } }
-- cinco cachos de 11 prismas, cada um com eixo próprio: { bx, by, ang (graus de tela, 0 = direita, 90 = baixo), len, meia largura, cacho }
local CRYSTALS = {
  { 19.0, 16.6, 8, 5.2, 1.2, 1 }, { 19.8, 15.2, -22, 3.4, 0.9, 1 }, { 18.2, 18.2, 58, 2.6, 0.9, 1 },
  { 27.4, 17.2, 222, 2.6, 0.9, 2 }, { 27.7, 18.6, 180, 1.6, 0.8, 2 },
  { 19.2, 24.6, -12, 4.0, 1.1, 3 }, { 20.2, 26.2, 8, 2.2, 0.9, 3 },
  { 27.3, 24.6, 160, 2.2, 0.8, 4 },
  { 20.4, 10.0, 35, 2.4, 0.8, 5 }, { 21.8, 10.2, 120, 1.2, 0.8, 5 }, { 22.4, 30.7, 190, 1.8, 0.8, 5 },
}
local TOOTH = { 1.0, 1.1 }   -- o botão do emissivo (só o comprimento): mapa, retrato
local ROOT = 0.32            -- segundo botão: fração da raiz no corpo (0,25 a 0,35)
local YEDGE = { [1] = true, [6] = true, [2] = true }   -- os três maiores levam a aresta Y no retrato
local CX, CY, R = 16, 20.5, 12
-- em cada fase do idle um cacho acende (não dá a volta na abertura, de propósito)
local GROW = { [0] = { 1 }, { 4, 5 }, { 3 }, { 2 } }
local DUST = { { 3, 12, 'S' }, { 31, 6, 's' }, { 33, 16, 'S' }, { 2.6, 29, 's' }, { 13, 4, 'S' }, { 31, 33, 's' } }
local DUSTB = { DUST[1], DUST[4] }   -- na deriva só atrás (x < 10)

local function tone3(dv, hi, mid, lo) return dv < -0.4 and hi or (dv < 0.35 and mid or lo) end
-- cápsula de duas pontas com 3 tons pelo lado de cima
local function pcap(u, v, x0, y0, x1, y1, r0, r1, a, b, c)
  local dx, dy = x1 - x0, y1 - y0
  local t = max(0, math.min(1, ((u - x0) * dx + (v - y0) * dy) / (dx * dx + dy * dy)))
  local px, py = x0 + dx * t, y0 + dy * t
  local r = r0 + (r1 - r0) * t
  if sqrt((u - px) ^ 2 + (v - py) ^ 2) <= r then return tone3((v - py) / r, a, b, c) end
end

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local ph = (o.ph or (o.portrait and o.portrait - 1) or 0) % 4
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local tuck = crouch or o.jump
  local still = alert or crouch
  local all = o.jump and (o.dy or 0) or 0
  local by = ((o.dy or 0) - all) / k
  oy = oy + all
  local hot = o.hot or 0
  local glow = alert and 0.15 or (still and 0 or ({ [0] = 0, 0.15, 0.3, 0.15 })[ph])
  local hx = alert and -2 or 0
  local mz = (o.lean and not o.jump) and ({ [0] = 0, 0.6, 0, 0.6 })[ph] or 0
  local function st(n) return o.lean and ({ [0] = 0.8, 0, -0.8, 0 })[(ph + n) % 4] or 0 end
  local ht, hb = st(0) + (alert and -1 or 0), st(2) + (alert and -1 or 0)
  local hands = {
    { 25.5 + ht, 11.2, 28.4 + ht, 10.2, 0.6, 0.45, 'C', 'D' }, { 25.7 + ht, 12, 28.6 + ht, 12.2, 0.6, 0.45, 'C', 'D' },
    { 25.5 + hb, 28, 28.6 + hb, 27.6, 0.6, 0.45, 'C', 'D' }, { 25.4 + hb, 29.2, 28.4 + hb, 30, 0.6, 0.45, 'C', 'D' },
    { 21.5, 12.5, 25.5 + ht, 11.5, 1.2, 0.9, 'l', 'M' }, { 21, 28, 25.5 + hb, 28.5, 1.3, 1.0, 'l', 'M' },
  }
  local sw, sp = k > 1 and 0.55 or 0.8, k > 1 and 1.6 or nil
  local jw = 0.75 * (k > 1 and 0.6 or 1)

  local function head(u, v)
    if tuck then return end
    local a, b = u - hx - mz, u - hx
    if dseg(a, v, 26.8, 21.3, 28.2, 21.6) < 0.5 then return 'M' end
    local c = pcap(a, v, 23, 20.1, 27.2, 20.6, 0.8, 0.6, 'K', 'l', 'M')
    if c then return c end
    c = pcap(a, v, 22.5, 20.6, 26.5, 21.3, 1.6, 1.2, 'r', 'N', 'n') or pcap(a, v, 26.5, 21.3, 31, 22.2, 1.2, 0.8, 'r', 'N', 'n')
    if c then return c end
    if ((b - 24.6) / 0.6) ^ 2 + ((v - 19.4) / 0.8) ^ 2 <= 1 then return 'N' end
  end
  local function hand(u, v)
    if tuck then return end
    return C.caps(u, v, hands)
  end

  -- prismas: pré-passo por pixel (a ponta tem no mínimo 1 px; só sobre o fundo, fora da cabeça e das mãos)
  local tm = {}
  local grow = {}
  if not still and not o.lean then for _, i in ipairs(GROW[ph]) do grow[i] = true end end
  for i, b in ipairs(CRYSTALS) do
    local ca, sa = math.cos(math.rad(b[3])), math.sin(math.rad(b[3]))
    local ux, uy = sa, -ca   -- perpendicular do lado de cima
    if uy > 0 or (uy == 0 and ux > 0) then ux, uy = -ux, -uy end
    local Ln = b[4] * TOOTH[k > 1 and 2 or 1]
    if k == 1 then Ln = max(Ln, 2.2) end
    local w0 = k == 1 and max(b[5], 0.8) or b[5]
    local lit = grow[b[6]]
    local tl = 0.78 - (lit and 1 / (k * Ln) or 0)
    local px, best, bt = {}, nil, -9
    for y = 0, g.h - 1 do for x = 0, g.w - 1 do
      if not tm[y * g.w + x] then
        local u, v = (x + 0.5 - ox) / k, (y + 0.5 - oy) / k
        local t = ((u - b[1]) * ca + (v - b[2]) * sa) / Ln
        local sd = (u - b[1]) * ux + (v - b[2]) * uy   -- > 0: lado de cima
        local wl = sd >= 0 and w0 * (1 - max(0, t - 0.7) / 0.3) or w0 * max(0, 1 - max(0, t - 0.7) / 0.17)
        if t >= -0.1 and t <= 1 and abs(sd) <= wl + 0.15 and inpoly(u, v, OPEN) and not head(u, v) and not hand(u, v) then
          px[#px + 1] = { x, y, t, sd }
          if t > bt then best, bt = #px, t end
        end
      end
    end end
    local ntip = 0
    for _, p in ipairs(px) do if p[3] >= tl then ntip = ntip + 1 end end
    for n, p in ipairs(px) do
      local ch
      if p[3] < ROOT then ch = 'c'
      elseif p[3] < tl and not (ntip == 0 and n == best) then
        ch = (p[4] >= 0 or alert or lit) and 'J' or 'H'
        if k > 1 and YEDGE[i] and p[4] >= w0 - 1 / k and p[3] < 0.85 then ch = 'Y' end
      else ch = (n == best) and 'I' or 'T' end
      tm[p[2] * g.w + p[1]] = ch
    end
  end

  local function shell(u, v, x, sy)
    local hw = R * sqrt(max(0.02, 1 - ((v - CY) / R) ^ 2))
    local lon = (u - CX) / hw
    local sh = (u - CX) / R * 0.45 + (v - CY) / R * 0.9
    if C.seam(u, v, { 6.4, 15 }, { 5.6, 18.6 }, sw, sp) or C.seam(u, v, { 16, 29.4 }, { 18.4, 30.4 }, sw, sp) then return 'Z' end
    if lon > -0.95 and lon < -0.05 then
      for n, sx in ipairs({ -0.725, -0.5, -0.275 }) do
        if abs(lon - sx) * hw < jw then
          if n == 2 or (n == 3 and hot >= 1) then return sh > 0.35 - glow and 'H' or 'J' end
          return 'M'
        end
      end
      local p = ((lon + 0.95) / 0.225) % 1
      if k > 1 and (v * 0.62) % 1 < 0.18 then return 'M' end
      local i = (p < 0.4 and 1 or 2) + (sh > 0.4 and 1 or 0)
      return ('KlM'):sub(i, i)
    end
    return C.stone(x, sy, 2.4 * k, 7, sh > 0.4 and C.GRAVD or C.GRAV, '5', 0.3 * k, k)
  end
  local function inD(u, v) return (u - CX) ^ 2 + (v - CY) ^ 2 <= R * R end

  C.paint(g, k, ox, oy, function(u, v0, x, y)
    local c = head(u, v0) or hand(u, v0) or tm[y * g.w + x]
    if c then return c end
    local inO = inpoly(u, v0, OPEN)
    if not inO and inD(u, v0) then
      for i = 1, #OPEN do
        local a, b = OPEN[i], OPEN[i % #OPEN + 1]
        if dseg(u, v0, a[1], a[2], b[1], b[2]) < 0.5 then return '1' end
      end
      if k > 1 then
        for i = 1, #OPEN do
          local a, b = OPEN[i], OPEN[i % #OPEN + 1]
          if dseg(u, v0, a[1] - 0.9, a[2], b[1] - 0.9, b[2]) < 0.2 then return '2' end
        end
      end
    end
    if inO then return 'O' end
    local v, sy = v0 - by, y - floor(by * k + 0.5)
    if by > 0 and v0 > 32.5 then return end
    if not inD(u, v) then
      if by < 0 and inD(u, v0) then v, sy = v0, y else return end
    end
    return shell(u, v, x, sy)
  end)
  C.prune(g)
  if not (o.jump or crouch) then
    local list = k > 1 and DUST or { DUST[1], DUST[2], DUST[3], DUST[4], DUST[5] }
    if o.lean then list = DUSTB end
    C.dust(g, sg, k, ox, oy, list, ph, 4)
  end
end

C.run {
  name = 'cairnhollow', stage = 'espirito', W = 36, PW = 96, draw = draw, fps = { idle = 6, drift = 6 },
  fleeDy = { 1, 0, 0, -1, -1, -1 },
  -- o retrato é o mesmo desenho feito em 96 (escala 2,55)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2.55, o, 3.4, -4)
    return g, sg, 0, 0
  end,
  acc = { sacred = { 12, 5 }, green = { 7, 10 }, water = { 13, 12 }, residential = { 12, 17 }, urban = { 4, 21 }, lit = { 13, 24 }, crimson = { 6, 25 } },
}
