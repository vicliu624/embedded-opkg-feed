"""Run a target libsoup client against an isolated native loopback HTTP server."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import subprocess
import threading

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--root', type=Path, required=True)
parser.add_argument('--media-root', type=Path, required=True)
parser.add_argument('--consumer', type=Path, required=True)
args = parser.parse_args()
requests = []

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        requests.append((self.path, self.headers.get('User-Agent')))
        body = b'tdvp-libsoup-loopback\n'
        self.send_response(200)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

with ThreadingHTTPServer(('127.0.0.1', 0), Handler) as server:
    worker = threading.Thread(target=server.serve_forever, daemon=True)
    worker.start()
    root, media = (p.resolve(strict=True) for p in (args.root, args.media_root))
    env = {name: value for name, value in os.environ.items()
           if not name.lower().endswith('_proxy') and not name.startswith(('GIO_', 'LD_'))}
    env['G_DEBUG'] = 'fatal-criticals'
    try:
        result = subprocess.run(['qemu-riscv64', '-cpu', 'rv64,v=false', '-L', str(root), '-E',
            'LD_LIBRARY_PATH=' + ':'.join(str(p) for p in (media / 'usr/lib', root / 'usr/lib', root / 'lib')),
            str(args.consumer), f'http://127.0.0.1:{server.server_port}/acceptance'],
            env=env, capture_output=True, text=True, timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr
        assert requests == [('/acceptance', 'TDVP-Feed-Acceptance')], requests
        print(result.stdout.strip())
    finally:
        server.shutdown()
        worker.join()
print('libsoup loopback: PASS target request received with exact path and user-agent')
