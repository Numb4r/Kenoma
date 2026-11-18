-- Fagulhas (0.25.1): uma por tipo, 4 quadros de 12x12 em laço (repouso, aceso, pico, aceso), forma própria por tipo.
-- Camadas: base (com contorno) e glow (o que brilha de noite). Rodar: aseprite -b --script build.lua
-- Letras: d escuro, m cor do tipo (colors.dart typeColor), l claro, w miolo. No repouso '1' é m e '2' é l;
-- no quadro aceso '1' vira l e '2' vira w. O pico é desenho próprio.
local S = dofile('/home/yuri/Documentos/kenoma/tools/art/traffic/_strip.lua')
local L = S.L
local DIR = L.ROOT .. 'sparks/'
local O = '#1A1424'

local TYPES = {
  { 'fire', m = '#FF5A36', d = '#B8321E', l = '#FFB05A', w = '#FFF0B0', lum = true,  -- chama
    a = { '..........', '.....m....', '....mm....', '....mmm...', '...mm1m.m.', '..mm1l1mm.', '..m1l2l1m.', '..m1l22lm.', '...mm11m..', '..........' },
    c = { '..........', '....m.....', '....mm....', '...mmlm...', '...mllm.m.', '..mmlwlmm.', '..mllwwlm.', '..mlwwwlm.', '...mllmm..', '..........' } },
  { 'water', m = '#4AA8FF', d = '#2A6FC0', l = '#A0D4FF', w = '#FFFFFF',  -- gota
    a = { '..........', '....m.....', '....m.....', '...mmm....', '...m1mm...', '..m2mmmd..', '..m1mmmd..', '..mmmmdd..', '...mddd...', '..........' },
    c = { '..........', '....m.....', '...mmm....', '...mlmm...', '..mlwmmm..', '..mwlmmmd.', '..mlmmmmd.', '..mmmmmdd.', '...mmddd..', '..........' } },
  { 'plant', m = '#6BD36A', d = '#3A8E4A', l = '#B4F08A', w = '#F0FFD0',  -- folha
    a = { '..........', '.....mmm..', '...mm11m..', '..mm1lmm..', '..m1lmmm..', '..mlmmmd..', '..mmmmdd..', '.dmmddd...', '.d........', '..........' },
    c = { '..........', '....mmmmm.', '...mmllwm.', '..mmllwmm.', '..mllwmmm.', '..mlwmmmd.', '..mwmmmdd.', '.dmmmddd..', '.d........', '..........' } },
  { 'electric', m = '#FFD84A', d = '#C89A20', l = '#FFF0A0', w = '#FFFFFF', lum = true,  -- faísca
    a = { '..........', '.....m1m..', '....m1m...', '...m1m....', '..m1111m..', '....m1m...', '...m1m....', '..m1m.....', '..mm......', '..........' },
    c = { '..........', '.m...mwm..', '..m.mwm...', '...mwm....', '..mwwwwm..', '....mwm.m.', '...mwm.m..', '..mwm.....', '..mm......', '..........' } },
  { 'earth', m = '#C79A5B', d = '#8A6638', l = '#E8C890', w = '#FFF0D0',  -- pedrinha
    a = { '..........', '..........', '...mmmm...', '..m11mmd..', '.mm1mmmdd.', '.mmmmmddd.', '.mmmmdddd.', '..mddddd..', '..........', '..........' },
    c = { '..........', '...mmmm...', '..mllmmd..', '.mmlwmmdd.', '.mmlmmmdd.', '.mmmmmddd.', '..mmdddd..', '...dd.m...', '..........', '..........' } },
  { 'metal', m = '#9FB3C8', d = '#5E7088', l = '#D4E2F0', w = '#FFFFFF',  -- lasca
    a = { '..........', '......mm..', '.....m2m..', '....m2md..', '...m1md...', '..m1mdd...', '..mmdd....', '.mddd.....', '.dd.......', '..........' },
    c = { '..........', '......lw..', '.....mwl..', '....mwmd..', '...mwmd.l.', '..mwmdd...', '..mlmd....', '.mmdd.....', '.dd.......', '..........' } },
  { 'light', m = '#FFF3B0', d = '#D8BE6A', l = '#FFFBE0', w = '#FFFFFF', lum = true,  -- raio de luz
    a = { '..........', '....m.....', '....m.....', '...m1m....', '.mm121mm..', '...m1m....', '....m.....', '....m.....', '..........', '..........' },
    c = { '..........', '....l.....', '..m.l.m...', '...lwl....', '.llwwwll..', '...lwl....', '..m.l.m...', '....l.....', '..........', '..........' } },
  { 'shadow', m = '#6B5A8E', d = '#3A2E55', l = '#9B8FC0', w = '#CFC6E8', lum = true,  -- fiapo de sombra (a borda violeta acende)
    a = { '..........', '...mmmm...', '..mddddm..', '..md..1dm.', '..mm..mdm.', '.....mdm..', '....mdm...', '...mdm....', '...mm.....', '..........' },
    c = { '..........', '..mmmm....', '.mddddm...', '.ml..ldm..', '.mm...mdm.', '......mdm.', '.....mlm..', '....mdm...', '....mm....', '..........' } },
  { 'spectral', m = '#B8C4D6', d = '#7F8CA8', l = '#E4ECF8', w = '#FFFFFF', lum = true,  -- chama fria, oca
    a = { '..........', '....m.....', '....mm....', '...mmm.m..', '..mm1mmm..', '..m1dd1m..', '..m1dd1m..', '..mm11mm..', '...mmmm...', '..........' },
    c = { '..........', '...m......', '...mm..m..', '..mmlm.m..', '..mllmmm..', '..mlddlm..', '..mlddwm..', '..mmllmm..', '...mmmm...', '..........' } },
  { 'digital', m = '#3DFFB0', d = '#1E9E78', l = '#A8FFDC', w = '#FFFFFF', lum = true,  -- pixel
    a = { '..........', '..........', '..mmmmm...', '..m111m...', '..m121m...', '..m111mmm.', '..mmmmmdm.', '......mmm.', '..........', '..........' },
    c = { '..........', '..........', '..mmmmm...', '..mlllm.m.', '..mlwlmm..', '.mmlllmmm.', '..mmmmmlm.', '......mmm.', '..........', '..........' } },
  { 'fae', m = '#FF8FD8', d = '#C05A9E', l = '#FFC8EC', w = '#FFFFFF', lum = true,  -- pó de fada
    a = { '..........', '......m...', '.....m2m..', '......m...', '...m......', '..m1m.....', '...m...m..', '.....m....', '..........', '..........' },
    c = { '..........', '......l...', '.....lwl..', '...m..l...', '..mlm.....', '...m..m...', '.....mlm..', '......m...', '..........', '..........' } },
  { 'draconic', m = '#D14B4B', d = '#8E2A34', l = '#F08A7A', w = '#FFD8C8',  -- escama
    a = { '..........', '...mmmm...', '..m1111m..', '..m1mm1m..', '..mmmmmm..', '..dmmmmd..', '..ddmmdd..', '...dddd...', '....dd....', '..........' },
    c = { '..........', '...mmmm...', '..mllllm..', '..mlwwlm..', '..mlmmlm..', '..dmllmd..', '..ddmmdd..', '...dddd...', '....dd....', '..........' } },
}

local function conv(rows, one, two)
  local out = {}
  for i, r in ipairs(rows) do out[i] = r:gsub('1', one):gsub('2', two) end
  return out
end

local function frame(rows, tag)
  local g = L.grid(12, 12)
  L.put(g, 1, 1, L.frame(rows, 10, 10, tag) and rows)
  L.outline(g, 'o')
  S.check(tag, g)
  return g
end

local items = {}
for i, t in ipairs(TYPES) do
  local name = 'spark_' .. t[1]
  local leg = { o = O, m = t.m, d = t.d, l = t.l, w = t.w }
  local rest = frame(conv(t.a, 'm', 'l'), name .. ' q1')
  local lit = frame(conv(t.a, 'l', 'w'), name .. ' q2')
  local peak = frame(t.c, name .. ' q3')
  local frames = { rest, lit, peak, lit }
  local glow = {}
  for f, g in ipairs(frames) do glow[f] = S.pick(g, t.lum and 'mlw' or 'lw') end
  S.save(DIR .. name, leg, {
    { name = 'base', frames = frames, png = DIR .. name .. '.png' },
    { name = 'glow', frames = glow, png = DIR .. name .. '_glow.png' },
  }, 5)
  -- Folha: os 4 quadros no asfalto, na grama e na calçada.
  for f = 1, 4 do
    for b = 0, 2 do
      items[#items + 1] = { g = frames[f], glow = glow[f], leg = leg, x = 2 + b * 50 + (f - 1) * 12, y = 1 + (i - 1) * 14 }
    end
  end
end

local H = #TYPES * 14 + 2
S.folha(DIR .. 'sparks_folha.png', 152, H, {
  { 0, H - 1, 0, 50, '#343949', '#2B2F3D', '#40465A' },
  { 0, H - 1, 51, 100, '#429658', '#2F7446', '#5FB26A' },
  { 0, H - 1, 101, 151, '#A3A7B3', '#8E92A0', '#B6BAC4' },
}, items, 4)
print('problemas: ' .. S.problems)
