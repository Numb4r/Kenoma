#!/usr/bin/env python3
# The local workbench: a live window into a game's build. python3 workbench/server.py   (settings in workbench/config.json)
import http.server, json, mimetypes, os, re, subprocess, threading, time, urllib.parse, uuid
clock = lambda f='%I:%M %p': time.strftime(f).lstrip('0')
HERE = os.path.dirname(os.path.abspath(__file__))
CFG = json.load(open(os.path.join(HERE, 'config.json')))
REPO = os.path.abspath(os.path.join(HERE, CFG.get('repo', '..')))
at = lambda p: os.path.abspath(os.path.join(HERE, os.path.expanduser(p)))
SHOTS = [at(p) for p in CFG.get('shotDirs', ['shots'])]
CLIPS = at(CFG.get('clipDir', 'clips'))
CAT = at(CFG.get('catalogDir', 'catalog'))
NOTEF = os.path.join(HERE, 'notes.json')
LOCK = threading.Lock()
def load(name, none):
    try: return json.load(open(os.path.join(HERE, name)))
    except Exception: return none
def notes(): return load('notes.json', [])
def save_notes(L):
    tmp = NOTEF + '.tmp'; json.dump(L, open(tmp, 'w'), indent=1); os.replace(tmp, NOTEF)
def sh(*a):
    try: return subprocess.run(a, capture_output=True, text=True, cwd=REPO, timeout=5).stdout.rstrip()
    except Exception: return ''
def newest(n=16):
    L = []
    for i, base in enumerate(SHOTS):
        for root, ds, fs in os.walk(base):
            for f in fs:
                if f.lower().endswith(('.jpg', '.jpeg', '.png')):
                    p = os.path.join(root, f)
                    try: L.append((os.path.getmtime(p), i, os.path.relpath(p, base)))
                    except OSError: pass
    L.sort(reverse=True)
    return [{'url': '/shot/%d/%s' % (i, urllib.parse.quote(r)), 'name': r, 'age': int(time.time() - t)} for t, i, r in L[:n]]
def clips():
    try: L = sorted(((os.path.getmtime(os.path.join(CLIPS, f)), f) for f in os.listdir(CLIPS) if f.lower().endswith(('.gif', '.webm', '.mp4'))), reverse=True)
    except OSError: L = []
    return [{'url': '/clip/' + urllib.parse.quote(f), 'name': f, 'video': not f.lower().endswith('.gif'), 'age': int(time.time() - t)} for t, f in L[:12]]
def running():
    pat = CFG.get('running'); out = []
    if not pat: return out
    t = sh('ps', '-axo', 'etime=,command=')
    for m in re.finditer(r'^\s*([\d:-]+)\s+(.*)$', t, re.M):
        c = re.search(pat, m.group(2))
        if c and 'server.py' not in m.group(2) and not re.match(r'(\S*/)?(ba|z|da)?sh\b', m.group(2)):   # shells that merely mention the command would list it twice
            n = c.group(1) if c.groups() else c.group(0)
            if not any(x['name'] == n for x in out): out.append({'name': n, 'for': m.group(1)})
    return out[:6]
def state():
    paths = CFG.get('gitPaths', ['.'])
    ships = []
    for l in sh('git', 'log', '-30', '--format=%ad|%h|%s', '--date=format:%-I:%M %p', '--', *paths).split('\n'):
        if l.count('|') >= 2: t, h, s = l.split('|', 2); ships.append({'t': t, 'h': h, 's': s})
    b = at(CFG['buildFile']) if CFG.get('buildFile') else ''
    tasks = load('tasks.json', {})
    return {'now': clock('%I:%M:%S %p'), 'build': sh('git', 'log', '-1', '--format=%h'), 'dirty': [l[3:] for l in sh('git', 'status', '--short', *paths).split('\n') if l][:12],
            'shipAge': int(time.time() - os.path.getmtime(b)) if b and os.path.exists(b) else 0, 'owner': tasks.get('owner'), 'tasks': tasks, 'grades': load('grades.json', []),
            'numbers': load('numbers.json', []), 'ships': ships, 'notes': notes(), 'shots': newest(), 'clips': clips(), 'running': running()}
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def send(self, b, ct, code=200):
        self.send_response(code); self.send_header('Content-Type', ct); self.send_header('Content-Length', str(len(b))); self.send_header('Accept-Ranges', 'bytes'); self.send_header('Cache-Control', 'no-store'); self.end_headers(); self.wfile.write(b)
    def file(self, base, rel):
        p = os.path.realpath(os.path.join(base, rel))
        if not p.startswith(os.path.realpath(base) + os.sep) or not os.path.isfile(p): return self.send(b'not found', 'text/plain', 404)
        b, ct = open(p, 'rb').read(), mimetypes.guess_type(p)[0] or 'application/octet-stream'
        m = re.match(r'bytes=(\d+)-(\d*)$', self.headers.get('Range', ''))
        if not m or int(m.group(1)) >= len(b): return self.send(b, ct)
        s, e = int(m.group(1)), min(int(m.group(2) or len(b) - 1), len(b) - 1)
        self.send_response(206); self.send_header('Content-Type', ct); self.send_header('Content-Range', 'bytes %d-%d/%d' % (s, e, len(b))); self.send_header('Accept-Ranges', 'bytes'); self.send_header('Content-Length', str(e - s + 1)); self.end_headers(); self.wfile.write(b[s:e + 1])
    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path == '/': return self.send(open(os.path.join(HERE, 'index.html'), 'rb').read(), 'text/html; charset=utf-8')
        if u.path == '/state.json': return self.send(json.dumps(state()).encode(), 'application/json')
        if u.path == '/config.json': return self.send(json.dumps({k: CFG.get(k) for k in ('game', 'theme')}).encode(), 'application/json')
        if u.path.startswith('/shot/'):
            i, r = u.path[6:].split('/', 1); return self.file(SHOTS[int(i)], urllib.parse.unquote(r))
        if u.path.startswith('/clip/'): return self.file(CLIPS, urllib.parse.unquote(u.path[6:]))
        if u.path == '/catalog.json':
            p = os.path.join(CAT, 'catalog.json')
            return self.send(open(p, 'rb').read() if os.path.exists(p) else b'{}', 'application/json')
        if u.path.startswith('/cat/'): return self.file(CAT, urllib.parse.unquote(u.path[5:]))
        self.send(b'not found', 'text/plain', 404)
    def do_HEAD(self): self.send_response(200); self.end_headers()
    def do_POST(self):
        u = urllib.parse.urlparse(self.path)
        try: d = json.loads(self.rfile.read(int(self.headers.get('Content-Length', 0))) or b'{}')
        except Exception: return self.send(b'bad', 'text/plain', 400)
        with LOCK:
            L = notes()
            if u.path == '/note':
                text = str(d.get('text', '')).strip()[:4000]
                if not text: return self.send(b'empty', 'text/plain', 400)
                n = {'id': uuid.uuid4().hex[:8], 'at': clock(), 'ts': time.time(), 'kind': str(d.get('kind', 'Note'))[:20], 'on': str(d.get('on', 'General'))[:120], 'tab': str(d.get('tab', ''))[:30], 'ref': str(d.get('ref', ''))[:120], 'text': text, 'status': 'new', 'reply': ''}
                L.append(n); save_notes(L); return self.send(json.dumps(n).encode(), 'application/json')
            if u.path == '/note/remove':
                L = [x for x in L if x['id'] != d.get('id')]; save_notes(L); return self.send(b'{}', 'application/json')
        self.send(b'not found', 'text/plain', 404)
PORT = int(CFG.get('port', 8977))
print('workbench on http://localhost:%d' % PORT, flush=True)
http.server.ThreadingHTTPServer(('127.0.0.1', PORT), H).serve_forever()
