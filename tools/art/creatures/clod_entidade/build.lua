-- Entidade Maior da família Clod (nome e pasta provisórios: clod_entidade), arte final a partir do conceito aprovado
-- da rodada 3, com o ajuste do dono. O tatu fechado em bola, e a bola é de entulho: escudo de cascalho de um lado,
-- pedaço de parede e entulho do outro, vergalhão, e as três cintas no meio com a junta acesa.
-- REGRA QUEBRADA: a bola não abre, e o que está dentro dela está fora. Três cabeças e três patas saem dela por onde
-- não há abertura, cada uma de uma trinca acesa.
-- AJUSTE DO DONO: uma cabeça de tatu legível em 48 px saindo de um ponto errado. A da direita é a cabeça inteira, de
-- perfil (escudo, orelhas, olho, focinho); a da esquerda sai do lado oposto, de cabeça para baixo (orelhas para o
-- chão), com o olho aceso; a terceira sai pelo alto, com o focinho para cima.
-- SEGUNDO AJUSTE DO DONO: as cabeças liam como rato e a bola tinha listras amarelas. A cabeça é a do tatu-bola (o
-- escudo de placas cobre o alto, com aba; orelhas em toco; focinho curto; sem pele rosada) e as três cintas são de
-- concreto e entulho, com a junta escura. A luz do tipo fica só nas trincas, perto de cada saída.
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
-- Tatu-bola: o escudo de placas cobre o alto da cabeça da nuca à ponta do focinho (é ele que diz tatu); as orelhas
-- são tocos redondos atrás do escudo; o focinho é curto e o rosto fica na sombra da aba.
local HEAD = {
  '...n..n........',
  '..nN.nN........',
  '..nN1nN1l1.....',
  '..1l12l12l1l...',
  '.l12l12l12l12..',
  '.12l12l12l12l1.',
  '.KMMMMMMMMMM12.',
  '.KKoWKKKlKKKMMo',
  '..lKooKKKKKllo.',
  '...lllllll.....',
}
local DUST = { { 3, 13 }, { 6, 41, 's' }, { 40, 42 }, { 44.6, 9, 's' }, { 13, 5 }, { 2.4, 34 }, { 37, 44.6, 's' }, { 45, 39 }, { 24, 3.6 },
  { 8, 9 }, { 41, 14, 's' }, { 3.6, 27 }, { 44, 30 }, { 10, 43 }, { 30, 45, 's' }, { 36, 8 }, { 19, 4.6 }, { 45.6, 22 } }

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
    for i = 0, 1 do                                               -- duas orelhas: tocos redondos atrás do escudo
      local bx, by = x0 + ux * (-0.6 + i * 2) + nx * 3, y0 + uy * (-0.6 + i * 2) + ny * 3
      t:cap(bx, by, bx + nx * 2.8 - ux * 0.6, by + ny * 2.8 - uy * 0.6, 1.2, 0.9, function(x, y, u, v)
        return ((u - bx) * ux + (v - by) * uy > -0.1) and 'N' or 'n'
      end)
    end
    x1, y1 = x1 - ux * 1.2, y1 - uy * 1.2                         -- focinho curto
    t:cap(x0, y0, x1, y1, 3.6, 1.8, function(x, y, u, v)
      local s = (u - x0) * ux + (v - y0) * uy
      local a = s / (len - 1.2)
      local b = (u - x0) * nx + (v - y0) * ny
      if a > 0.97 and b < 0.5 then return 'o' end                 -- o nariz
      local lip = 0.1 + a * 0.3
      if b > lip then                                             -- o escudo: placas em fileiras, da nuca ao focinho
        local row = floor((b - lip) / 1.5)
        local c = (s + (row % 2) * 0.75) / 1.5
        if (b - lip) % 1.5 < 1.1 / k or (c % 1) * 1.5 < 1.1 / k then return 'M' end   -- a junta: 1 px
        return ((c % 1) > 0.66 or C.rnd(floor(c), row, 4) > 0.75) and '2' or '1'
      end
      if b > lip - 0.7 then return 'M' end                        -- a sombra da aba do escudo
      return b < -2.2 and 'l' or 'K'                              -- o rosto, na sombra
    end)
    local ex, ey = x0 + dx * 0.36 - nx * 1.5, y0 + dy * 0.36 - ny * 1.5
    t:ell(ex, ey, 0.85, 0.85, q.eye or 'o')
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
      local near = 99                                             -- distância até a saída mais próxima
      for _, q in ipairs(HEADS) do                                -- a trinca em volta de cada saída
        local r = sqrt((u - q[1]) ^ 2 + (v - q[2]) ^ 2)
        if r < 3.7 then return r > 3 and 'H' or 'J' end
        near = math.min(near, r)
      end
      for _, q in ipairs(LEGS) do
        local r = sqrt((u - q[1]) ^ 2 + (v - q[2]) ^ 2)
        if r < 2.5 then return r > 1.9 and 'H' or 'J' end
        near = math.min(near, r + 2.5)
      end
      -- a trinca acesa se espalha da saída pelo rejunte do cascalho
      local pulse = still and 0 or sin(t6 - near * 0.7)             -- a luz corre da saída para fora
      local function crack(c)
        if c ~= '5' or near > 13 + glow * 6 then return c end
        return near < 5.2 and 'Y' or ((near < 8 or pulse > 0.6) and 'J' or 'H')
      end
      -- as três cintas do tatu, em concreto e entulho, com a junta escura entre elas
      for n, sx in ipairs({ -0.36, -0.12, 0.12, 0.36 }) do
        local dd = abs(lon - sx) * hw
        if dd < (k > 1 and 0.5 or 0.62) then
          return '5'                                              -- sem listra acesa: a luz fica nas trincas do cascalho
        end
      end
      if abs(lon) < 0.36 then
        local band = floor((lon + 0.36) / 0.24)
        local pp = ((lon + 0.36) / 0.24) % 1
        if ((b + band * 1.1) / 2.7) % 1 < (k > 1 and 0.13 or 0.26) then                  -- as placas de cada cinta
          return near < 11.5 + glow * 6 and (near < 6 and 'J' or 'H') or '4'              -- a trinca atravessa a cinta, curta
        end
        if k > 1 and C.rnd(x, y, 9) > 0.9 then return '3' end                           -- poros
        if band == 1 and C.rnd(floor(b / 2.7 + 0.4), 3, 9) > 0.6 then                   -- um caco de tijolo preso na cinta do meio
          return sh > 0.3 and 't' or (pp < 0.4 and 'p' or 'q')
        end
        local i = (pp < 0.35 and 1 or 2) + (sh > 0.25 and 1 or 0) + (sh > 0.65 and 1 or 0)
        return ('1234'):sub(i, i)
      end
      if lon > 0 then                                             -- o escudo da frente: parede e entulho
        if b < -1 then
          local row = floor(v / 1.7)
          local bx = (u + (row % 2) * 1.7) % 3.4
          if bx < 0.5 or v % 1.7 < 0.45 then return near < 9 + glow * 6 and (near < 5.6 and 'J' or 'H') or '4' end
          return R.pick('tqp', 0.6 - sh * 0.5, R.noise(p, 8)(x, y))
        end
        return crack(stone(x, y, 3 * k, 21, sh > 0.3 and C.RUBD or C.RUB, '5', 0.32 * k, k))
      end
      return crack(stone(x, y, 2.3 * k, 7, sh > 0.4 and C.GRAVD or C.GRAV, '5', 0.3 * k, k))
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
