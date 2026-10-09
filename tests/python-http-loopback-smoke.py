import threading
from http.server import BaseHTTPRequestHandler, HTTPServer
import requests


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = b'{"tdvp": true}'
        self.send_response(200 if self.path == "/ok" else 404)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        pass


server = HTTPServer(("127.0.0.1", 0), Handler)
worker = threading.Thread(target=server.serve_forever, daemon=True)
worker.start()
session = requests.Session()
session.trust_env = False
try:
    url = "http://127.0.0.1:" + str(server.server_address[1])
    response = session.get(url + "/ok", timeout=5)
    response.raise_for_status()
    assert response.json() == {"tdvp": True}
    try:
        session.get(url + "/missing", timeout=5).raise_for_status()
    except requests.HTTPError:
        pass
    else:
        raise AssertionError("HTTP error status was accepted")
finally:
    session.close()
    server.shutdown()
    server.server_close()
    worker.join(timeout=5)
print("RISC-V Requests actual loopback HTTP, JSON and error-status handling: PASS")
