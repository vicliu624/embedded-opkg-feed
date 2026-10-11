"""Validate target TLS trust and hostname rejection with an owned localhost server."""
import argparse
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("target_root", type=Path)
parser.add_argument("client", type=Path)
args = parser.parse_args()
target, client = (p.resolve(strict=True) for p in (args.target_root, args.client))
with tempfile.TemporaryDirectory(prefix="tdvp-tls-certificate-") as temporary:
    root = Path(temporary)
    for name in ("trusted", "unrelated"):
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost", "-keyout", str(root / (name + ".key")), "-out", str(root / (name + ".pem"))], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    with (root / "server.log").open("w+") as log:
        server = subprocess.Popen(["openssl", "s_server", "-accept", "127.0.0.1:" + str(port), "-cert", str(root / "trusted.pem"), "-key", str(root / "trusted.key"), "-www", "-quiet"], stdout=log, stderr=log)
        try:
            ready = False
            for attempt in range(50):
                assert server.poll() is None, "Owned TLS fixture exited"
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                        ready = True
                        break
                except OSError:
                    time.sleep(0.1)
            assert ready, "Owned TLS fixture did not start"
            environment = dict(os.environ)
            environment.pop("LD_LIBRARY_PATH", None)
            environment.pop("QEMU_LD_PREFIX", None)
            command = ["qemu-riscv64", "-L", str(target), "-E", "LD_LIBRARY_PATH=" + str(target / "usr/lib"), str(client), str(port)]
            subprocess.run(command + [str(root / "trusted.pem"), "localhost"], env=environment, check=True, timeout=15)
            for certificate, hostname in (("trusted", "wrong.invalid"), ("unrelated", "localhost")):
                result = subprocess.run(command + [str(root / (certificate + ".pem")), hostname], env=environment, timeout=15)
                assert result.returncode == 7, (certificate, hostname, result.returncode)
            print("Target GnuTLS rejects wrong hostname and unrelated CA: PASS")
        finally:
            if server.poll() is None:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait(timeout=5)
