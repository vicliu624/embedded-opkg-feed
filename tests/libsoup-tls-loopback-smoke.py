"""Check real target HTTPS, explicit CA trust and rejection of an unrelated CA."""
import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
import ssl
import subprocess
import tempfile
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
        body = b'tdvp-libsoup-tls\n'
        self.send_response(200)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

with tempfile.TemporaryDirectory(prefix='tdvp-libsoup-tls-') as directory:
    temporary = Path(directory)
    for name in ('server', 'unrelated'):
        result = subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
            '-keyout', str(temporary / (name + '.key')), '-out', str(temporary / (name + '.pem')),
            '-days', '2', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost',
            '-addext', 'basicConstraints=critical,CA:TRUE'], capture_output=True, timeout=30)
        assert result.returncode == 0, result.stderr.decode()
    with ThreadingHTTPServer(('127.0.0.1', 0), Handler) as server:
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(temporary / 'server.pem', temporary / 'server.key')
        context.set_alpn_protocols(['http/1.1'])
        server.socket = context.wrap_socket(server.socket, server_side=True)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        root, media = (p.resolve(strict=True) for p in (args.root, args.media_root))
        env = {name: value for name, value in os.environ.items()
               if not name.lower().endswith('_proxy') and not name.startswith(('GIO_', 'LD_', 'G_TLS_'))}
        env.update(G_DEBUG='fatal-criticals', GIO_USE_TLS='gnutls',
                   GIO_MODULE_DIR=str(root / 'usr/lib/gio/modules'))
        command = ['qemu-riscv64', '-cpu', 'rv64,v=false', '-L', str(root), '-E',
            'LD_LIBRARY_PATH=' + ':'.join(str(p) for p in (media / 'usr/lib', root / 'usr/lib', root / 'lib')),
            str(args.consumer), f'https://localhost:{server.server_port}/tls']
        try:
            accepted = subprocess.run(command + [str(temporary / 'server.pem')], env=env,
                                      capture_output=True, text=True, timeout=30)
            assert accepted.returncode == 0, accepted.stdout + accepted.stderr
            rejected = subprocess.run(command + [str(temporary / 'unrelated.pem')], env=env,
                                      capture_output=True, text=True, timeout=30)
            assert rejected.returncode == 3, rejected.stdout + rejected.stderr
            wrong_host = command.copy()
            wrong_host[-1] = f'https://127.0.0.1:{server.server_port}/tls'
            mismatched = subprocess.run(wrong_host + [str(temporary / 'server.pem')], env=env,
                                        capture_output=True, text=True, timeout=30)
            assert mismatched.returncode == 3, mismatched.stdout + mismatched.stderr
            assert requests == [('/tls', 'TDVP-TLS-Acceptance')], requests
            print(accepted.stdout.strip())
        finally:
            server.shutdown()
            worker.join()
print('libsoup TLS loopback: PASS glib-networking/GnuTLS load, HTTPS, unrelated CA and hostname mismatch rejection')
