#!/usr/bin/env python3
"""Conferência do vão do Arquétipo de noite e de dia: docs/art/final/vao_dia.png.

Uma fileira por família: o mapa de 64 a 4x (noite, dia) e o retrato de 128 a 2x (noite, dia). De dia o corpo vai sem
tom e os emissivos apagados: o vão tem de continuar violeta só pela camada corpo.
Rodar: python3 tools/art/creatures/vao_dia.py
"""
from familia import compose
from resumo import FAMS, layers, sheet

if __name__ == '__main__':
    rows = []
    for f in FAMS:
        p = f'{f}_arquetipo'
        m, r = layers(p, 'idle', 64), layers(p, 'portrait', 128)
        rows.append([(f'{f} 64 noite', compose(*m, 4, True)), (f'{f} 64 dia', compose(*m, 4, False)),
                     (f'{f} 128 noite', compose(*r, 2, True)), (f'{f} 128 dia', compose(*r, 2, False))])
    print(sheet(rows, 'vao_dia.png'))
