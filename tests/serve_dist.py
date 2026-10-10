# Tiny static server for the web export that behaves like a real host:
# /login -> login.html, and unknown paths (e.g. protected routes) fall back to index.html (client-side router decides).
# Usage: python3 tests/serve_dist.py <dist-folder> <port>
import http.server, os, sys

ROOT = os.path.abspath(sys.argv[1]); PORT = int(sys.argv[2])

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **k): super().__init__(*a, directory=ROOT, **k)
    def translate_path(self, path):
        p = super().translate_path(path)
        if os.path.isfile(p): return p
        if os.path.isfile(p + '.html'): return p + '.html'
        if os.path.isdir(p) and os.path.isfile(os.path.join(p, 'index.html')): return os.path.join(p, 'index.html')
        return os.path.join(ROOT, 'index.html')
    def log_message(self, *a): pass

http.server.ThreadingHTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
