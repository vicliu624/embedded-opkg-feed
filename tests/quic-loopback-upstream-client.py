"""Exercise the unmodified upstream GnuTLS C client against an owned QUIC fixture.

This is QUIC/TLS interoperability, not HTTP/3 or certificate-authentication acceptance.
The upstream example uses hq-interop and does not enable peer verification.
Run with an isolated host venv containing aioquic 1.3.0.
"""
import argparse
import asyncio
import os
from pathlib import Path
import socket
import subprocess
import tempfile
from aioquic.asyncio import QuicConnectionProtocol, serve
from aioquic.quic.configuration import QuicConfiguration
from aioquic.quic.events import HandshakeCompleted, StreamDataReceived

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("sdk", type=Path)
parser.add_argument("client", type=Path)
parser.add_argument("quic_libraries", type=Path)
parser.add_argument("event_libraries", type=Path)
args = parser.parse_args()
sdk, client, quic, event = (p.resolve(strict=True) for p in (args.sdk, args.client, args.quic_libraries, args.event_libraries))
evidence = {"handshake": False, "request": False}

class FixtureProtocol(QuicConnectionProtocol):
    def quic_event_received(self, received):
        if isinstance(received, HandshakeCompleted):
            assert received.alpn_protocol == "hq-interop"
            evidence["handshake"] = True
        elif isinstance(received, StreamDataReceived):
            if received.data == b"GET /\r\n":
                evidence["request"] = True
                self._quic.send_stream_data(received.stream_id, b"TDVP fixture\n", end_stream=True)
                self.transmit()
                asyncio.get_running_loop().call_later(0.2, self.close)

async def run_fixture():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
        reservation.bind(("127.0.0.1", 4433))
    with tempfile.TemporaryDirectory(prefix="tdvp-quic-fixture-") as temporary:
        root = Path(temporary)
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1", "-keyout", str(root / "key.pem"), "-out", str(root / "cert.pem")], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
        configuration = QuicConfiguration(is_client=False, alpn_protocols=["hq-interop"])
        configuration.load_cert_chain(root / "cert.pem", root / "key.pem")
        server = await serve("127.0.0.1", 4433, configuration=configuration, create_protocol=FixtureProtocol)
        try:
            environment = dict(os.environ)
            environment.pop("LD_LIBRARY_PATH", None)
            environment.pop("QEMU_LD_PREFIX", None)
            command = ["qemu-riscv64", "-L", str(sdk / "sysroot"), "-E", "LD_LIBRARY_PATH=" + str(quic) + ":" + str(event), str(client)]
            result = await asyncio.to_thread(subprocess.run, command, env=environment, capture_output=True, text=True, timeout=15)
            assert result.returncode == 0, result.stderr[-3000:]
            assert evidence == {"handshake": True, "request": True}, evidence
            print("Target ngtcp2/GnuTLS QUIC TLS handshake and decrypted request: PASS")
            print("HTTP/3 framing, response content and certificate verification remain separate gates")
        finally:
            server.close()
            await asyncio.sleep(0)

asyncio.run(run_fixture())
