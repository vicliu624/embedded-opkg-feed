"""Check real HTTP3 download with target upstream examples and installed libraries.

Upstream GnuTLS examples do not enable peer verification; this gate only
establishes HTTP3/QUIC transfer and content integrity, not certificate trust.
"""
import argparse
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("installed_root", type=Path)
parser.add_argument("examples", type=Path)
args = parser.parse_args()
root, examples = (p.resolve(strict=True) for p in (args.installed_root, args.examples))
for program in ("gtlsclient", "gtlsserver"):
    dynamic = subprocess.check_output(["readelf", "-d", str(examples / program)], text=True)
    assert "(RPATH)" not in dynamic and "(RUNPATH)" not in dynamic, "Test executable can bypass installed libraries: " + program
environment = dict(os.environ)
environment.pop("LD_LIBRARY_PATH", None)
environment.pop("QEMU_LD_PREFIX", None)
prefix = ["qemu-riscv64", "-L", str(root), "-E", "LD_LIBRARY_PATH=" + str(root / "usr/lib")]
with tempfile.TemporaryDirectory(prefix="tdvp-http3-download-") as temporary:
    fixture = Path(temporary)
    content = (b"TDVP HTTP3 target library content integrity fixture\n" * 400)
    htdocs, downloads = fixture / "htdocs", fixture / "downloads"
    htdocs.mkdir()
    downloads.mkdir()
    (htdocs / "fixture.txt").write_bytes(content)
    key, certificate = fixture / "key.pem", fixture / "certificate.pem"
    subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost,IP:127.0.0.1", "-keyout", str(key), "-out", str(certificate)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    with (fixture / "server.log").open("w+") as log:
        server = subprocess.Popen(prefix + [str(examples / "gtlsserver"), "--quiet", "--htdocs=" + str(htdocs), "127.0.0.1", str(port), str(key), str(certificate)], env=environment, stdout=log, stderr=log)
        try:
            time.sleep(0.5)
            assert server.poll() is None, "Owned HTTP3 server exited"
            command = prefix + [str(examples / "gtlsclient"), "--quiet", "--handshake-timeout=5s", "--timeout=5s", "--exit-on-all-streams-close", "--download=" + str(downloads), "127.0.0.1", str(port), "https://localhost:" + str(port) + "/fixture.txt"]
            result = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=20)
            assert result.returncode == 0, (result.stdout + result.stderr)[-3000:]
            files = [p for p in downloads.rglob("*") if p.is_file()]
            assert len(files) == 1 and files[0].read_bytes() == content, [(p.name, p.stat().st_size) for p in files]
            print("Target upstream HTTP3/QUIC download: PASS", len(content), "bytes match exactly")
            print("Upstream example peer certificate verification is disabled; trust acceptance remains separate")
        finally:
            if server.poll() is None:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait(timeout=5)
