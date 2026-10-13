"""Serve pinned upstream DAP fixtures and run the target NetCDF client.

Fixture bytes come from the source-locked netcdf-c 4.10.1 archive; this test
does not copy or redistribute them into runtime packages.
"""
import argparse
import hashlib
import http.server
import os
from pathlib import Path
import subprocess
import threading
from urllib.parse import urlsplit

parser = argparse.ArgumentParser()
for name in ('root', 'library-root', 'consumer', 'source'):
    parser.add_argument('--' + name, required=True)
args = parser.parse_args()
client_environment = dict(os.environ)
for name in ('http_proxy', 'https_proxy', 'all_proxy', 'HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY'):
    client_environment.pop(name, None)
client_environment['NO_PROXY'] = client_environment['no_proxy'] = '127.0.0.1,localhost'
fixtures = {
    '/dap2/test.dds': ('ncdap_test/testdata3/test.01.dds', 'b63d68b6651a15e4b8ff7d979784d994e76c1fa03581870344076b8dd7e5b6e6'),
    '/dap2/test.das': ('ncdap_test/testdata3/test.01.das', '0973dc195e11486ab2fcee60358c52c3f6fb8cca331f580326eb5fe8c1f7c985'),
    '/dap2/test.dods': ('ncdap_test/testdata3/test.01.dods', 'aab46d596659fe6821aa71477bc48cd9abfdbb0bcc37a1cfdfd4e4ee3eb46a2c'),
    '/dap4/test.dmr': ('dap4_test/rawtestfiles/test_atomic_types.nc.dmr', '54b8cd7eb80082bf902e1e65469c91c9d053f124a427532b0bff7fc6ba7b27b3'),
    '/dap4/test.dap': ('dap4_test/rawtestfiles/test_atomic_types.nc.dap', 'b5811f4aede97d201c9e6ea0371917d8d9dce9b89e862ee422f160e8797393bb'),
}
payloads = {}
for route, (name, digest) in fixtures.items():
    payload = (Path(args.source) / name).read_bytes()
    assert hashlib.sha256(payload).hexdigest() == digest, 'upstream fixture bytes changed'
    payloads[route] = payload
requests = []
truncated_protocol = None

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        route = urlsplit(self.path).path
        requests.append(self.path)
        if route == '/dap4/test.dmr.xml':
            route = '/dap4/test.dmr'
        if route not in payloads:
            self.send_error(404)
            return
        payload = payloads[route]
        if truncated_protocol and route == f'/{truncated_protocol}/test.' + ('dods' if truncated_protocol == 'dap2' else 'dap'):
            payload = payload[:len(payload) // 2]
        self.send_response(200)
        self.send_header('Content-Type', 'application/octet-stream')
        self.send_header('Content-Length', str(len(payload)))
        self.send_header('XDODS-Server', 'dods/3.7')
        self.end_headers()
        self.wfile.write(payload)

    def log_message(self, *unused):
        pass

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    for protocol, suffix in (('dap2', '#dap2'), ('dap4', '?dap4.checksum=false#dap4')):
        url = f'http://127.0.0.1:{server.server_port}/{protocol}/test' + suffix
        result = subprocess.run(['qemu-riscv64', '-cpu', 'rv64,v=false', '-L', args.root,
                                '-E', f'LD_LIBRARY_PATH={args.library_root}/usr/lib:{args.root}/usr/lib',
                                args.consumer, protocol, url], env=client_environment, capture_output=True, text=True, timeout=30)
        assert result.returncode == 0, result.stdout + result.stderr + repr(requests)
        print(result.stdout.strip())
    routes = {urlsplit(request).path for request in requests}
    assert '/dap2/test.dods' in routes and '/dap4/test.dap' in routes, requests
    print('NetCDF DAP HTTP: PASS target decoded pinned DAP2/DAP4 responses; requests=' + repr(requests))
    for protocol, suffix in (('dap2', '#dap2'), ('dap4', '?dap4.checksum=false#dap4')):
        truncated_protocol = protocol
        url = f'http://127.0.0.1:{server.server_port}/{protocol}/test' + suffix
        result = subprocess.run(['qemu-riscv64', '-cpu', 'rv64,v=false', '-L', args.root,
                                '-E', f'LD_LIBRARY_PATH={args.library_root}/usr/lib:{args.root}/usr/lib',
                                args.consumer, protocol, url], env=client_environment, capture_output=True, text=True, timeout=30)
        assert result.returncode == 1 and 'nc_' in result.stderr, 'truncated DAP data accepted, crashed or failed for an unrelated reason: ' + result.stdout + result.stderr
        print('NetCDF ' + protocol + ': PASS truncated response rejected with API error')
finally:
    server.shutdown()
    server.server_close()
    thread.join()
