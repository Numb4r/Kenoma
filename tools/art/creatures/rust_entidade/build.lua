-- Entidade Maior da família Rust (nome e pasta provisórios: rust_entidade), arte final a partir do conceito aprovado
-- da rodada 3. O besouro-rinoceronte de perfil, com os élitros levantados como quem vai voar, e cada élitro é uma
-- folha de portão inteira, com barras, travessa e lanças, girando na dobradiça das costas. Onde eles estavam, o
-- abdome está aberto e aceso. O chifre é uma lança de portão.
-- REGRA QUEBRADA: as patas não são dele. Sete vergalhões saem do chão, cada um num lugar, e seguram o corpo por onde
-- alcançam: a barriga, a ponta da folha, o chifre.
-- Costura do Véu: uma, larga, na dobradiça, só no glow.
-- Camadas: corpo; leds = o miolo da luz do abdome (pisca); glow = o resto da luz do abdome e a que fica atrás das
-- barras da folha, a costura e a limalha solta.
-- Animação (6 quadros, lenta): as duas folhas rangem na dobradiça, uma depois da outra; a luz do abdome cresce e
-- encolhe; o corpo sobe e desce e os vergalhões, presos no chão, dobram para acompanhar.
-- Os vergalhões não têm contorno.
-- Rodar: KENOMA_ART='<repo>/tools/art/'; dofile(KENOMA_ART .. 'creatures/rust_entidade/build.lua')
local Ru = dofile(assert(KENOMA_ART, 'defina KENOMA_ART') .. 'creatures/_rust.lua')
local L, R = Ru.L, Ru.R
local sin, pi = math.sin, math.pi
local iron = Ru.iron

local DUST = { { 45.4, 12 }, { 3, 7 }, { 24, 4 }, { 44, 6 }, { 27, 41 }, { 9.6, 42 }, { 42.6, 42.4 }, { 18, 44 } }

local function draw(g, sg, k, o, ox, oy)
  ox, oy = ox or 0, oy or 0
  local NL = o.portrait and 4 or 6
  local ph = (o.ph or 0) % NL
  local t6 = ph / NL * 2 * pi
  local alert, crouch = o.pose == 'alert', o.pose == 'crouch'
  local still = alert or crouch
  local all = o.jump and (o.dy or 0) or 0
  local by = ((o.dy or 0) - all) / k + (crouch and 1 or 0)
  local d = R.ctx(g.w, k, ox, oy + all + by * k); d.g = g         -- o corpo; os vergalhões ficam no chão
  local p = d:pp()
  local sol = o.dark and '' or Ru.SOLID
  local s1 = alert and 1.5 or (crouch and -1.5 or (still and 0 or sin(t6)))
  local s2 = alert and 1.5 or (crouch and -1.5 or (still and 0 or sin(t6 - 1.2)))
  local glow = alert and 1.3 or (crouch and 0.7 or 1 + 0.2 * sin(t6))
  d:layer(function(t)                                               -- a folha de lá, mais fechada
    Ru.gateLeaf(t, k, { 28.6, 24.6 }, { -9.6 - s2 * 0.6, -11.6 + s2 * 0.5 }, { 2, -8.6 }, 3, 0, Ru.IRONP)
  end, sol)
  d:layer(function(t)                                               -- o besouro
    t:ell(18, 31.6, 11, 5, function(x, y, u, v)                     -- o abdome aberto: anéis de ferro, luz dentro
      local e = ((u - 18) / 11) ^ 2 + ((v - 31.6) / 5) ^ 2
      local sh = (v - 31.6) / 5
      if e > 0.7 or v > 33.6 then return iron(0, 1, x, y, sh, k) end
      if (u - 8.4) % 3.4 < 0.9 then return iron(0, 0.5, x, y, sh, k) end
      local gl = (((u - 19.4) / 9) ^ 2 + ((v - 30.2) / 3.2) ^ 2) / glow
      return gl < 0.2 and 'I' or (gl < 0.6 and 'M' or 'D')
    end)
    t:cap(33, 24, 37.4, 21.6, 1.1, 0.5, function(x, y) return iron(0, 1, x, y, -0.2, k, Ru.IRONP) end)                       -- o chifre do pronoto
    t:ell(31, 29.6, 5, 6.6, function(x, y, u, v) return Ru.plate(x, y, (v - 29.6) / 6.6 * 0.85 + (u - 31) / 5 * 0.3, k) end)  -- pronoto
    t:ell(37.6, 32.2, 2.8, 3, function(x, y, u, v) return v < 31.2 and '4' or (v < 33.2 and '3' or '2') end)                 -- cabeça
    t:ell(38.6, 31.6, 0.8, 0.8, 'o'); if k > 1 then t:ell(38.4, 31.4, 0.3, 0.3, 'W') end
    t:cap(38.4, 30, 42, 27, 1.3, 1.1, function(x, y, u, v) return iron(0, 1, x, y, (v - 28) * 0.4, k, Ru.IRONP) end)          -- o chifre: lança de portão
    t:cap(42, 27, 43.6, 20, 1.1, 0.8, function(x, y, u, v) return iron(0, 1, x, y, (u - 43) * 0.6, k, Ru.IRONP) end)
    t:ell(43.6, 19.6, 1.6, 0.8, 'q')
    Ru.diamond(t, 43.8, 17.4, 1.8, 6, function(x, y, u, v) return iron(u - 43.8, 1.7, x, y, (v - 16) / 5, k, Ru.IRONP) end)
    t:cap(39.6, 34, 41.4, 35.2, 0.5, 0.4, '3')
    t:suture({ { 12.6, 26.8 }, { 25.6, 26 } }, 'Z', 1.3, k > 1 and 3 or nil, Ru.SOLID:gsub('[LMDIZ]', ''))   -- a costura, na dobradiça
  end, sol)
  d:layer(function(t)                                               -- a folha de cá, aberta
    Ru.gateLeaf(t, k, { 25.6, 25.6 }, { -19, -6 + s1 * 0.9 }, { -1 - s1 * 0.5, -13 }, 4, 0.55)
    t:ell(25.6, 25, 1.3, 1.3, R.mat('345', R.chk(p), 0.6))          -- a dobradiça
  end, sol)
  -- os vergalhões: o pé no chão, a ponta onde alcança o corpo (ela sobe com ele)
  local legs = {}
  local function rebar(pts)
    pts[#pts][2] = pts[#pts][2] + by
    if #pts > 3 then pts[#pts - 1][2] = pts[#pts - 1][2] + by end
    Ru.leg(legs, pts, 0.55, 'e', 'E', 4)
    legs[#legs + 1] = { pts[1][1] - 1.4, 45.2, pts[1][1] + 1.4, 45.2, 0.6, 0.6, 'n', 'n' }   -- o asfalto rachado no pé
  end
  rebar({ { 6, 45.5 }, { 5, 39 }, { 8.6, 34 } })
  rebar({ { 13, 45.5 }, { 15.4, 41 }, { 14, 36 } })
  rebar({ { 22.4, 45.5 }, { 20.4, 41.4 }, { 22.6, 36.2 } })
  rebar({ { 29, 45.5 }, { 32.4, 41.4 }, { 31, 35.6 } })
  rebar({ { 39, 45.5 }, { 36.4, 41 }, { 37.8, 34.6 } })
  rebar({ { 43.6, 45.5 }, { 45, 37 }, { 44.6, 28 }, { 44, 22 } })   -- esta segura o chifre
  rebar({ { 3, 45.5 }, { 2.6, 34 }, { 4.6, 26 + s1 * 0.9 }, { 7, 20.4 + s1 * 0.9 } })   -- e esta, a ponta da folha
  if not o.dark then Ru.behind(g, k, ox, oy + all, legs) end       -- na silhueta escura do nascer os vergalhões ainda não vieram
  Ru.dust(g, sg, k, ox, oy, DUST, ph, NL)
end

Ru.run {
  name = 'rust_entidade', stage = 'entidade', W = 48, PW = 96, draw = draw,
  nloop = 6, fps = { idle = 5, drift = 5 }, fleeDy = { 1, 0, 0, -1, -1, -1 },
  -- o retrato é o mesmo desenho feito em 96
  portrait = function(o)
    local g, sg = L.grid(96, 96), L.grid(96, 96)
    draw(g, sg, 2, o, 0, 2)
    return g, sg, 0, 0
  end,
  acc = {
    urban = { 27, 28 }, green = { 24, 31 }, water = { 26, 27 }, residential = { 26, 28 }, lit = { 26, 29 },
    sacred = { 28, 19 }, crimson = { 29, 28 },
  },
}
