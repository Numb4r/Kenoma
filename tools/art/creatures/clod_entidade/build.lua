-- Entidade Maior da família Clod (nome e pasta provisórios: clod_entidade), arte final a partir do conceito aprovado
-- da rodada 3, com o ajuste do dono. O tatu fechado em bola, e a bola é de entulho: escudo de cascalho de um lado,
-- pedaço de parede e entulho do outro, vergalhão, e as três cintas no meio com a junta acesa.
-- REGRA QUEBRADA: a bola não abre, e o que está dentro dela está fora. Três cabeças e três patas saem dela por onde
-- não há abertura, cada uma de uma trinca acesa.
-- AJUSTE DO DONO: uma cabeça de tatu legível em 48 px saindo de um ponto errado. A da direita é a cabeça inteira, de
-- perfil (escudo, orelhas, olho, focinho); a da esquerda sai do lado oposto, de cabeça para baixo (orelhas para o
-- chão), com o olho aceso; a terceira sai pelo alto, com o focinho para cima.
-- Costura do Véu: uma, larga, fechando a bola embaixo (onde ela devia abrir), só no glow.
-- Camadas: corpo; leds = o olho aceso da cabeça virada (pisca); glow = as juntas, as trincas, a costura e a poeira.
-- Animação (6 quadros, lenta): a bola balança sem abrir (as cintas giram um pouco e voltam), a luz corre pelas juntas,
-- cada cabeça entra e sai da trinca no seu passo, as patas mexem. No alerta saem todas; na antecipação recolhem.
-- O vergalhão não tem contorno.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/clod_entidade/build.lua')
local C = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_clod.lua')
local L, R = C.L, C.R
local floor, sqrt, abs, sin, cos, max, pi, rad = math.floor, math.sqrt, math.abs, math.sin, math.cos, math.max, math.pi, math.rad
local stone = C.stone

local CX, CY, RR = 23, 28, 15.5
-- de onde sai cada coisa (na bola) e para onde aponta; flip: de cabeça para baixo; o último é o olho aceso
local HEADS = { { 35.5, 32.6, 45, 34.6 }, { 11.6, 19.4, 2.6, 18.6, flip = true, eye = 'I' }, { 29.6, 13.4, 29.8, 4.4 } }
local LEGS = { { 18, 14, 15.6, 7.6 }, { 9.6, 33.4, 4.6, 36 }, { 37, 22.6, 41.6, 20.4 } }
-- no mapa a cabeça é desenhada pixel a pixel (focinho para a direita): escudo de placas, duas orelhas, olho, focinho
local HEAD = {
  '...N...N.......',
  '..Nn..Nn.......',
  '..Nn..Nn.......',
  '.KKlKKlKK......',
  'KlMKKlMKKlK....',
  'KKlKoWlKKlMKK..',
  'lMKKooKlMKKlKKn',
  '.nNNNNNNNNNNNno',
  '..nnNNNNNNNnnoo',
  '....nnnnnnn....',
}
local DUST = { { 3, 13 }, { 6, 41, 's' }, { 40, 42 }, { 44.6, 9, 's' }, { 13, 5 }, { 2.4, 34 }, { 37, 44.6, 's' }, { 45, 39 }, { 24, 3.6 } }

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local S = g.w
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local t6 = ph / NL * 2 * pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local d = R.ctx(S, k, ox, oy + (o.dy or 0)); d.g = g
  local p = d:pp()
  local rock = still and 0 or 4 * sin(t6)
  local ca, sa = cos(rad(-24 + rock)), sin(rad(-24 + rock))
  local glow = alert and 0.3 or (still and 0 or 0.15 + 0.15 * sin(t6))
  -- quanto cada cabeça está para fora (0 = toda; negativo recolhe), cada uma no seu passo
  local function out(n)
    if alert then return 0 elseif crouch then return -2 end
    return sin(t6 + n * 2.1) > -0.3 and 0 or -1
  end
  local function wig(n) return still and 0 or 0.7 * sin(t6 * 2 + n * 1.9) end
  local function head(t, q, e)
    local x0, y0, x1, y1 = q[1], q[2], q[3], q[4]
    local dx, dy = x1 - x0, y1 - y0
    local len = sqrt(dx * dx + dy * dy)
    local ux, uy = dx / len, dy / len
    x1, y1 = x1 + ux * e, y1 + uy * e
    x0, y0 = x0 + ux * e, y0 + uy * e
    local nx, ny = -uy, ux
    if (ny > 0) ~= (q.flip == true) then nx, ny = -nx, -ny end
    for i = 0, 1 do                                               -- duas orelhas
      local bx, by = x0 + ux * (0.2 + i * 2.2) + nx * 2.6, y0 + uy * (0.2 + i * 2.2) + ny * 2.6
      local sp = i == 0 and -1.6 or 0.8
      t:cap(bx, by, bx + nx * 4.6 + ux * sp, by + ny * 4.6 + uy * sp, 1.15, 0.5, i == 0 and 'R' or 'r')
    end
    t:cap(x0, y0, x1, y1, 3.4, 1.2, function(x, y, u, v)
      local a = ((u - x0) * ux + (v - y0) * uy) / len
      local b = (u - x0) * nx + (v - y0) * ny
      if a > 0.9 then return 'o' end
      if b > 0.3 and a < 0.7 then return stone(x, y, 1.5 * k, 11, { '12K', '1Kl' }, 'l', 0.25 * k, k) end
      return b < -1.2 and 'R' or (a > 0.55 and b > -0.2 and 'C' or 'r')
    end)
    local ex, ey = x0 + dx * 0.45 + nx * 0.6, y0 + dy * 0.45 + ny * 0.6
    t:ell(ex, ey, 1, 1, q.eye or 'o')
    if not q.eye then t:ell(ex - 0.2, ey - 0.2, 0.25, 0.25, 'W') end
  end
  local function leg(t, q, w)
    local x0, y0, x1, y1 = q[1], q[2], q[3] + w, q[4] + w * 0.6
    local a = math.atan(y1 - y0, x1 - x0)
    t:cap(x0, y0, x1, y1, 1.9, 1.4, R.mat('fMl', R.hor(p), 0.5))
    for c = -1, 1 do
      t:cap(x1, y1, x1 + cos(a + c * 0.6) * 2.6, y1 + sin(a + c * 0.6) * 2.6, 0.7, 0.3, R.mat('DC', R.ver(p), c == 1 and 0 or 1))
    end
  end
  local function stamp(t, x0, y0, mode, lit)
    y0 = y0 + (o.dy or 0)
    for j, row in ipairs(HEAD) do
      for i = 1, #row do
        local c = row:sub(i, i)
        if c ~= '.' then
          if lit and (c == 'o' or c == 'W') and i < 8 then c = c == 'W' and 'I' or 'T' end
          local x, y = i - 1, j - 1
          if mode == 'flip' then x, y = #row - 1 - x, #HEAD - 1 - y elseif mode == 'up' then x, y = #HEAD - 1 - (j - 1), #row - 1 - (i - 1) end
          L.set(t.g, x0 + x, y0 + y, c)
        end
      end
    end
  end
  d:layer(function(t)                                             -- a bola
    t:ell(CX, CY, RR, RR, function(x, y, u, v)
      local a = (u - CX) * ca + (v - CY) * sa
      local b = -(u - CX) * sa + (v - CY) * ca
      local hw = RR * sqrt(max(0.02, 1 - (b / RR) ^ 2))
      local lon = a / hw
      local sh = (u - CX) / RR * 0.45 + (v - CY) / RR * 0.9
      for _, q in ipairs(HEADS) do                                -- a trinca em volta de cada saída
        local r = sqrt((u - q[1]) ^ 2 + (v - q[2]) ^ 2)
        if r < 3.7 then return r > 3 and 'H' or 'J' end
      end
      for _, q in ipairs(LEGS) do
        local r = sqrt((u - q[1]) ^ 2 + (v - q[2]) ^ 2)
        if r < 2.5 then return r > 1.9 and 'H' or 'J' end
      end
      for _, sx in ipairs({ -0.12, 0.12, -0.36, 0.36 }) do
        local dd = abs(lon - sx) * hw
        if dd < (k > 1 and 0.5 or 0.62) then
          if sh > 0.35 - glow then return 'H' end
          return (sh < -0.35 + glow and dd < 0.3) and 'Y' or 'J'
        end
      end
      if abs(lon) < 0.36 then
        local pp = ((lon + 0.36) / 0.24) % 1
        if k > 1 and (b * 0.62) % 1 < 0.18 then return 'M' end
        local i = (pp < 0.4 and 1 or 2) + (sh > 0.4 and 1 or 0)
        return ('KlM'):sub(i, i)
      end
      if lon > 0 then                                             -- o escudo da frente: parede e entulho
        if b < -1 then
          local row = floor(v / 1.7)
          local bx = (u + (row % 2) * 1.7) % 3.4
          if bx < 0.5 or v % 1.7 < 0.45 then return '4' end
          return R.pick('tqp', 0.6 - sh * 0.5, R.noise(p, 8)(x, y))
        end
        return stone(x, y, 3 * k, 21, sh > 0.3 and C.RUBD or C.RUB, '5', 0.32 * k, k)
      end
      return stone(x, y, 2.3 * k, 7, sh > 0.4 and C.GRAVD or C.GRAV, '5', 0.3 * k, k)
    end)
    t:suture({ { 14.6, 37 }, { 19, 41.4 }, { 26, 42.4 } }, 'Z', 1.3, k > 1 and 3 or nil)
  end, o.dark and '' or C.SOLID)
  d:wire({ { 36, 26 }, { 42.6, 25.6 }, { 44.6, 27.4 } }, 'e', 'E', 0.6, '.')   -- vergalhão
  d:layer(function(t)
    for n, q in ipairs(LEGS) do leg(t, q, wig(n)) end
    if k == 1 then
      stamp(t, 31 + out(1), 27, nil); stamp(t, 2 - out(2), 13, 'flip', true); stamp(t, 24, 3 - out(3), 'up')
    else
      for n, q in ipairs(HEADS) do head(t, q, out(n)) end
    end
  end, o.dark and '' or C.SOLID)
  C.prune(g)
  C.dust(g, sg, k, ox, oy, DUST, ph, NL)
end

C.run {
  name = 'clod_entidade', stage = 'entidade', W = 48, PW = 96, draw = draw,
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  -- o retrato é o mesmo desenho feito em 96 (as cabeças são desenhadas por forma, com olho e brilho)
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2, o, 0, 2)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 20, 27 }, green = { 17, 30 }, water = { 19, 25 }, residential = { 19, 26 }, lit = { 19, 28 },
    sacred = { 19, 13 }, crimson = { 22, 26 },
  },
}
