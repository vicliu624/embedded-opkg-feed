"""Serve a real dataset and verify the target NetCDF byte-range client."""
import argparse
import http.server
from pathlib import Path
import re
import subprocess
import threading

parser = argparse.ArgumentParser()
parser.add_argument('--root', required=True)
parser.add_argument('--library-root', required=True)
parser.add_argument('--consumer', required=True)
parser.add_argument('--dataset', required=True)
args = parser.parse_args()
data = Path(args.dataset).read_bytes()
requests = []

class Handler(http.server.BaseHTTPRequestHandler):
    def do_HEAD(self):
        self.respond(False)

    def do_GET(self):
        self.respond(True)

    def respond(self, body):
        if self.path != '/dataset.nc':
            self.send_error(404)
            return
        value = self.headers.get('Range')
        requests.append((self.command, value))
        start, end = 0, len(data) - 1
        if value:
            match = re.fullmatch(r'bytes=(\d+)-(\d*)', value)
            if not match:
                self.send_error(416)
                return
            start = int(match[1])
            end = min(int(match[2]) if match[2] else end, end)
            if start > end:
                self.send_error(416)
                return
        self.send_response(206 if value else 200)
        self.send_header('Content-Type', 'application/octet-stream')
        self.send_header('Accept-Ranges', 'bytes')
        self.send_header('Content-Length', str(end - start + 1))
        if value:
            self.send_header('Content-Range', f'bytes {start}-{end}/{len(data)}')
        self.end_headers()
        if body:
            self.wfile.write(data[start:end + 1])

    def log_message(self, *unused):
        pass

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    url = f'http://127.0.0.1:{server.server_port}/dataset.nc#mode=bytes'
    subprocess.run(['qemu-riscv64', '-cpu', 'rv64,v=false', '-L', args.root,
                    '-E', f'LD_LIBRARY_PATH={args.library_root}/usr/lib:{args.root}/usr/lib',
                    args.consumer, url], check=True, timeout=30)
    assert any(method == 'GET' and value for method, value in requests), requests
    print('NetCDF HTTP fixture: PASS real Range request observed')
finally:
    server.shutdown()
    server.server_close()
    thread.join()
