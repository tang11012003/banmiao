import http.server, socketserver, urllib.request, urllib.error, os

ROOT = "/workspace/peidu-community/frontend/build/web"
UPSTREAM = "http://127.0.0.1:8080"


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self): self.route()
    def do_POST(self): self.route()
    def do_PUT(self): self.route()
    def do_DELETE(self): self.route()
    def do_OPTIONS(self): self.route()

    def route(self):
        if self.path.startswith("/api") or self.path.startswith("/health"):
            self.proxy()
        else:
            self.serve_static()

    def proxy(self):
        url = UPSTREAM + self.path
        length = int(self.headers.get("Content-Length", 0) or 0)
        body = self.rfile.read(length) if length else None
        req = urllib.request.Request(url, data=body, method=self.command)
        for k in ("Authorization", "Content-Type"):
            v = self.headers.get(k)
            if v:
                req.add_header(k, v)
        try:
            resp = urllib.request.urlopen(req, timeout=30)
            data = resp.read()
            self.send_response(resp.status)
            ct = resp.headers.get("Content-Type", "application/json")
            self.send_header("Content-Type", ct)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except urllib.error.HTTPError as e:
            data = e.read()
            self.send_response(e.code)
            self.send_header("Content-Type", e.headers.get("Content-Type", "application/json"))
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except Exception as e:
            msg = str(e).encode()
            self.send_response(502)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)

    def serve_static(self):
        rel = self.path.split("?")[0]
        fpath = os.path.normpath(os.path.join(ROOT, rel.lstrip("/")))
        if not fpath.startswith(ROOT):
            self.send_error(403)
            return
        if rel == "/" or os.path.isdir(fpath):
            fpath = os.path.join(ROOT, "index.html")
        if not os.path.exists(fpath):
            fpath = os.path.join(ROOT, "index.html")  # SPA 兜底
        try:
            with open(fpath, "rb") as f:
                data = f.read()
            self.send_response(200)
            self.send_header("Content-Type", self.guess(fpath))
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        except Exception:
            self.send_error(404)

    @staticmethod
    def guess(p):
        if p.endswith(".js"): return "text/javascript; charset=utf-8"
        if p.endswith(".wasm"): return "application/wasm"
        if p.endswith(".html"): return "text/html; charset=utf-8"
        if p.endswith(".json"): return "application/json"
        if p.endswith(".png"): return "image/png"
        if p.endswith(".css"): return "text/css"
        if p.endswith(".ico"): return "image/x-icon"
        return "application/octet-stream"

    def log_message(self, *a):
        pass


socketserver.TCPServer.allow_reuse_address = True
print("web proxy on :8081 (static build/web + /api -> 8080)")
with socketserver.ThreadingTCPServer(("0.0.0.0", 8081), Handler) as httpd:
    httpd.serve_forever()
