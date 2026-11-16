#!/usr/bin/env python3
"""Captura os eventos da época 12 (e as três combinações) no emulador, cada um no estado certo: o clima pedido, de noite os
noturnos, o Frio de manhã, e os que se movem num GIF curto. Dirige o menu de debug pelo adb: força o clima e os eventos,
acerta o Relógio UTC e abre o mapa no Centro. As posições dos botões são as do AVD kenoma_g54 (1080 × 2400).
Uso: workbench/capture/eventos.py [ids...]   (sem ids: todos)"""
import subprocess, sys, time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'workbench/catalog/eventos'
ADB = ['adb', '-s', 'emulator-5554']

# Os chips: (rolagem, y). Rolagem 0: lista de cima; 1: depois de um arrasto para cima.
CLIMA = {'clear': (0, 888), 'cloudy': (0, 1023), 'rain': (0, 1158), 'storm': (0, 1293), 'drizzle': (0, 1563), 'fog': (0, 1833), 'cold': (0, 1968), 'snow': (1, 1365)}
EVENTO = {'rainbow': (0, 888), 'tornado': (0, 1023), 'aurora': (0, 1158), 'static': (0, 1293), 'meteor_shower': (0, 1428), 'double_moon': (0, 1563),
          'black_sun': (0, 1698), 'vigil': (0, 1833), 'silence': (0, 1968), 'fog_procession': (0, 2103), 'veil_tide': (0, 2238),
          'rift_wind': (1, 1718), 'echo_storm': (1, 1853), 'crimson_moon': (1, 1988), 'veil_prism': (1, 2123)}
NOITE, MANHA = '2026-11-17 02:00', '2026-11-17 09:30'  # 23h e 6h30 em Campinas

# id da foto: (clima, eventos, relógio, GIF)
ITENS = {
    'rainbow': ('clear', ['rainbow'], None, True),
    'tornado': ('storm', ['tornado'], None, True),
    'aurora': ('clear', ['aurora'], NOITE, False),
    'static': ('clear', ['static'], None, False),
    'meteor_shower': ('clear', ['meteor_shower'], NOITE, False),
    'double_moon': ('clear', ['double_moon'], NOITE, False),
    'crimson_moon__chuva': ('rain', ['crimson_moon'], None, False),
    'crimson_moon__sol': ('clear', ['crimson_moon'], None, False),
    'black_sun': ('clear', ['black_sun'], None, False),
    'veil_prism__garoa': ('drizzle', ['veil_prism'], None, False),
    'veil_prism__seco': ('clear', ['veil_prism'], None, False),
    'vigil': ('cloudy', ['vigil'], None, True),
    'silence': ('clear', ['silence'], None, False),
    'fog_procession': ('fog', ['fog_procession'], None, True),
    'fog_procession__sem_neblina': ('clear', ['fog_procession'], None, True),
    'veil_tide': ('clear', ['veil_tide'], None, True),
    'rift_wind': ('clear', ['rift_wind'], None, False),
    'echo_storm': ('storm', ['echo_storm'], None, False),
    'combo__vigil_storm': ('storm', ['vigil'], None, True),
    'combo__crimson_storm': ('storm', ['crimson_moon'], None, False),
    'combo__aurora_snow': ('snow', ['aurora'], NOITE, False),
    'clima__cold': ('cold', [], MANHA, False),
}


def adb(*a: str) -> bytes:
    return subprocess.run(ADB + list(a), capture_output=True, timeout=40).stdout


def tap(x: int, y: int, wait: float = 1.0) -> None:
    adb('shell', 'input', 'tap', str(x), str(y))
    time.sleep(wait)


def search(text: str) -> None:
    for _ in range(3):
        adb('shell', 'input', 'swipe', '540', '500', '540', '2100', '200')
    tap(540, 305, 0.5)
    adb('shell', 'input', 'keyevent', '123')
    for _ in range(20):
        adb('shell', 'input', 'keyevent', '67')
    adb('shell', 'input', 'text', text.replace(' ', '%s'))
    time.sleep(1.5)
    adb('shell', 'input', 'keyevent', '111')
    time.sleep(1)


def chip(pos: tuple[int, int]) -> None:
    if pos[0]:
        adb('shell', 'input', 'swipe', '540', '2000', '540', '900' if pos is not CLIMA.get('snow') else '700', '600')
        time.sleep(1.5)
    tap(540, pos[1])


def shot() -> Image.Image:
    from io import BytesIO
    return Image.open(BytesIO(adb('exec-out', 'screencap', '-p'))).convert('RGB')


def capture(name: str, climate: str, events: list[str], clock: str | None, gif: bool) -> None:
    adb('shell', 'am', 'force-stop', 'com.numb4r.kenoma')
    adb('shell', 'monkey', '-p', 'com.numb4r.kenoma', '-c', 'android.intent.category.LAUNCHER', '1')
    time.sleep(6)
    if clock:
        search('relogio')
        tap(540, 645, 1.5)
        adb('shell', 'input', 'text', clock.replace(' ', '%s'))
        time.sleep(1)
        adb('shell', 'input', 'keyevent', '111')
        time.sleep(1)
        tap(540, 793, 1.5)
    search('clima for')
    tap(540, 1428, 2)  # Todos os climas
    chip(CLIMA[climate])
    if events:
        search('eventos for')
        tap(540, 888, 2)  # Todos os eventos
        for e in events:
            chip(EVENTO[e])
            for _ in range(3):
                adb('shell', 'input', 'swipe', '540', '500', '540', '2100', '200')
    search('mapa do jogo')
    tap(540, 580, 22)
    frames = [shot()]
    if gif:
        for _ in range(9):
            time.sleep(0.5)
            frames.append(shot())
    OUT.mkdir(parents=True, exist_ok=True)
    frames[0].save(OUT / f'{name}.png')
    if gif:
        small = [f.resize((360, 800), Image.NEAREST) for f in frames]
        small[0].save(OUT / f'{name}.gif', save_all=True, append_images=small[1:], duration=500, loop=0)
    print(f'{name}: {"gif + " if gif else ""}png', flush=True)


if __name__ == '__main__':
    for name in sys.argv[1:] or list(ITENS):
        capture(name, *ITENS[name])
