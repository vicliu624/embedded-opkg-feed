"""Check target HTTP/2 over TLS against an independent h2 server."""
import argparse
import os
from pathlib import Path
import socketserver
import ssl
import subprocess
import tempfile
import threading
from h2.config import H2Configuration
from h2.connection import H2Connection
from h2.events import RequestReceived

parser = argparse.ArgumentParser()
for name in ('root', 'consumer'):
    parser.add_argument('--' + name, type=Path, required=True)
args = parser.parse_args()
requests, failures = [], []

class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        handshake_complete = False
        try:
            with context.wrap_socket(self.request, server_side=True) as stream:
                handshake_complete = True
                stream.settimeout(10)
                assert stream.selected_alpn_protocol() == 'h2', 'server did not negotiate HTTP/2'
                connection = H2Connection(config=H2Configuration(client_side=False, header_encoding='utf-8'))
                connection.initiate_connection()
                stream.sendall(connection.data_to_send())
                while True:
                    data = stream.recv(65536)
                    if not data:
                        break
                    events = connection.receive_data(data)
                    complete = False
                    for event in events:
                        if isinstance(event, RequestReceived):
                            headers = dict(event.headers)
                            requests.append((headers[':path'], headers['user-agent']))
                            body = b'tdvp-libsoup-http2\n'
                            connection.send_headers(event.stream_id, [(':status', '200'), ('content-length', str(len(body)))])
                            connection.send_data(event.stream_id, body, end_stream=True)
                            complete = True
                    stream.sendall(connection.data_to_send())
                    if complete:
                        break
        except (ssl.SSLError, ConnectionResetError) as error:
            # The unrelated-CA and hostname cases deliberately abort TLS.
            if handshake_complete:
                failures.append(repr(error))
        except Exception as error:
            failures.append(repr(error))

with tempfile.TemporaryDirectory(prefix='tdvp-libsoup-h2-') as directory:
    temporary = Path(directory)
    for name in ('server', 'unrelated'):
        result = subprocess.run(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
            '-keyout', str(temporary / (name + '.key')), '-out', str(temporary / (name + '.pem')),
            '-days', '2', '-subj', '/CN=localhost', '-addext', 'subjectAltName=DNS:localhost',
            '-addext', 'basicConstraints=critical,CA:TRUE'], capture_output=True, timeout=30)
        assert result.returncode == 0, result.stderr.decode()
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(temporary / 'server.pem', temporary / 'server.key')
    context.set_alpn_protocols(['h2'])
    with socketserver.ThreadingTCPServer(('127.0.0.1', 0), Handler) as server:
        server.daemon_threads = True
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        root = args.root.resolve(strict=True)
        environment = {name: value for name, value in os.environ.items()
                       if not name.lower().endswith('_proxy') and not name.startswith(('GIO_', 'LD_', 'G_TLS_'))}
        environment.update(G_DEBUG='fatal-criticals', GIO_USE_TLS='gnutls', GIO_MODULE_DIR=str(root / 'usr/lib/gio/modules'))
        command = ['qemu-riscv64', '-cpu', 'rv64,v=false', '-L', str(root), '-E',
                   'LD_LIBRARY_PATH=' + str(root / 'usr/lib') + ':' + str(root / 'lib'),
                   str(args.consumer), f'https://localhost:{server.server_address[1]}/h2']
        try:
            accepted = subprocess.run(command + [str(temporary / 'server.pem')], env=environment, capture_output=True, text=True, timeout=30)
            assert accepted.returncode == 0, accepted.stdout + accepted.stderr + repr(failures)
            rejected = subprocess.run(command + [str(temporary / 'unrelated.pem')], env=environment, capture_output=True, text=True, timeout=30)
            assert rejected.returncode == 3, rejected.stdout + rejected.stderr
            mismatched = command.copy()
            mismatched[-1] = f'https://127.0.0.1:{server.server_address[1]}/h2'
            result = subprocess.run(mismatched + [str(temporary / 'server.pem')], env=environment, capture_output=True, text=True, timeout=30)
            assert result.returncode == 3, result.stdout + result.stderr
            assert requests == [('/h2', 'TDVP-H2-Acceptance')] and not failures, (requests, failures)
            print(accepted.stdout.strip())
        finally:
            server.shutdown()
            worker.join()
print('libsoup HTTP/2 loopback: PASS independent protocol server, unrelated CA and hostname rejection')
