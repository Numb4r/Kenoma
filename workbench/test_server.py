#!/usr/bin/env python3
"""Teste das notas do workbench (0.20.4): o server.py de verdade, numa cópia de workbench/ com outra porta, recebe uma nota,
grava no notes.json com o id do item, devolve no /state.json, recusa nota vazia e apaga. Só escuta em 127.0.0.1.
Uso: python3 workbench/test_server.py"""
import json
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import unittest
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent


def free_port() -> int:
    with socket.socket() as s:
        s.bind(('127.0.0.1', 0))
        return s.getsockname()[1]


class NotesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix='workbench-'))
        for f in ('server.py', 'index.html', 'tasks.json', 'numbers.json'):
            shutil.copy(HERE / f, cls.tmp / f)
        (cls.tmp / 'notes.json').write_text('[]')
        cfg = json.loads((HERE / 'config.json').read_text())
        cls.port = cfg['port'] = free_port()
        cfg['repo'] = str(HERE.parent)
        cfg['fontDir'] = str(HERE.parent / 'app/assets/fonts')
        (cls.tmp / 'config.json').write_text(json.dumps(cfg))
        cls.proc = subprocess.Popen([sys.executable, str(cls.tmp / 'server.py')], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(50):
            try:
                urllib.request.urlopen(f'http://127.0.0.1:{cls.port}/state.json', timeout=1)
                break
            except OSError:
                time.sleep(0.1)

    @classmethod
    def tearDownClass(cls):
        cls.proc.terminate()
        cls.proc.wait(5)
        shutil.rmtree(cls.tmp)

    def post(self, path, body):
        req = urllib.request.Request(f'http://127.0.0.1:{self.port}{path}', data=json.dumps(body).encode(), headers={'Content-Type': 'application/json'})
        try:
            with urllib.request.urlopen(req, timeout=5) as r:
                return r.status, json.loads(r.read() or b'{}')
        except urllib.error.HTTPError as e:
            return e.code, None

    def test_nota_chega_ao_notes_json_presa_ao_item_e_sai(self):
        code, n = self.post('/note', {'kind': 'Fix this', 'on': 'Poças do Rill', 'tab': 'checklist', 'ref': 'checklist:0203-pocas-rill', 'text': 'não vi nenhuma'})
        self.assertEqual(code, 200)
        saved = json.loads((self.tmp / 'notes.json').read_text())
        self.assertEqual([(x['ref'], x['text'], x['status']) for x in saved], [('checklist:0203-pocas-rill', 'não vi nenhuma', 'new')])
        state = json.loads(urllib.request.urlopen(f'http://127.0.0.1:{self.port}/state.json', timeout=5).read())
        self.assertEqual([x['id'] for x in state['notes']], [n['id']])
        self.assertEqual(self.post('/note', {'text': '   '})[0], 400, 'nota vazia é recusada')
        self.assertEqual(self.post('/note/remove', {'id': n['id']})[0], 200)
        self.assertEqual(json.loads((self.tmp / 'notes.json').read_text()), [])

    def test_so_localhost_e_as_fontes_do_jogo(self):
        src = (HERE / 'server.py').read_text()
        self.assertIn("ThreadingHTTPServer(('127.0.0.1', PORT)", src, 'o acesso de fora é pelo tailscale serve, nunca o servidor aberto')
        css = urllib.request.urlopen(f'http://127.0.0.1:{self.port}/fonts.css', timeout=5).read().decode()
        self.assertIn('Silkscreen', css)
        self.assertEqual(urllib.request.urlopen(f'http://127.0.0.1:{self.port}/font/PixelifySans.ttf', timeout=5).status, 200)

    def test_sem_ratings(self):
        html = (HERE / 'index.html').read_text()
        self.assertNotIn("['ratings', 'Ratings']", html)


if __name__ == '__main__':
    unittest.main()
