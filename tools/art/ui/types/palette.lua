-- Cores dos 12 tipos (0.26.0): a fonte única. m principal, l claro, d escuro. Quem usa: build.lua daqui e
-- tools/art/sparks/build.lua. Regra: nenhuma principal perto do ciano do sinal (#5FD3C6) nem do violeta do Véu
-- (#9B7BFF); o Fogo fica no vermelho para não se confundir com o laranja da Essência (#FF7A45).
return {
  { id = 'fire',     nome = 'Fogo',      m = '#F0502E', l = '#FF9C7A', d = '#A82E1C', icone = 'chama' },
  { id = 'water',    nome = 'Água',      m = '#4A9CFF', l = '#A4D0FF', d = '#2A62B8', icone = 'gota' },
  { id = 'plant',    nome = 'Planta',    m = '#4DBD62', l = '#A2E8A0', d = '#2B7A40', icone = 'folha' },
  { id = 'earth',    nome = 'Terra',     m = '#C0915A', l = '#E6C594', d = '#7E5A32', icone = 'pedra' },
  { id = 'electric', nome = 'Elétrico',  m = '#FFD23A', l = '#FFEE9A', d = '#B8901C', icone = 'raio' },
  { id = 'metal',    nome = 'Metal',     m = '#93A1B3', l = '#CCD6E2', d = '#566274', icone = 'lingote' },
  { id = 'light',    nome = 'Luz',       m = '#FFF0B8', l = '#FFFBE6', d = '#CDB468', icone = 'sol' },
  { id = 'shadow',   nome = 'Sombra',    m = '#A677AB', l = '#D2ABD6', d = '#68426E', icone = 'lua escura' },
  { id = 'spectral', nome = 'Espectral', m = '#D3E2F4', l = '#F2F7FF', d = '#8A9DBA', icone = 'chama fria, oca' },
  { id = 'digital',  nome = 'Digital',   m = '#A8F040', l = '#DCFA9E', d = '#62A01E', icone = 'pixel' },
  { id = 'fae',      nome = 'Feérico',   m = '#FFA8E0', l = '#FFD6F1', d = '#C0669E', icone = 'asas de fada' },
  { id = 'draconic', nome = 'Dracônico', m = '#DE4F84', l = '#F797B6', d = '#8E2852', icone = 'escama' },
}
