"""Check HTTP3 download and certificate rejection with strictly configured target examples."""
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
for name in ("gtlsclient", "gtlsserver"):
    dynamic = subprocess.check_output(["readelf", "-d", str(examples / name)], text=True)
    assert "(RPATH)" not in dynamic and "(RUNPATH)" not in dynamic
environment = dict(os.environ)
for name in ("LD_LIBRARY_PATH", "QEMU_LD_PREFIX", "TDVP_HTTP3_TEST_CA_FILE", "TDVP_HTTP3_TEST_PEER_NAME"):
    environment.pop(name, None)
prefix = ["qemu-riscv64", "-L", str(root), "-E", "LD_LIBRARY_PATH=" + str(root / "usr/lib")]
with tempfile.TemporaryDirectory(prefix="tdvp-http3-strict-trust-") as temporary:
    fixture = Path(temporary)
    htdocs = fixture / "htdocs"
    htdocs.mkdir()
    content = b"TDVP certificate-verified HTTP3 fixture\n" * 400
    (htdocs / "fixture.txt").write_bytes(content)
    for name in ("trusted", "unrelated"):
        subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-days", "1", "-subj", "/CN=localhost", "-addext", "subjectAltName=DNS:localhost", "-keyout", str(fixture / (name + ".key")), "-out", str(fixture / (name + ".pem"))], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=15)
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    with (fixture / "server.log").open("w+") as log:
        server = subprocess.Popen(prefix + [str(examples / "gtlsserver"), "--quiet", "--htdocs=" + str(htdocs), "127.0.0.1", str(port), str(fixture / "trusted.key"), str(fixture / "trusted.pem")], env=environment, stdout=log, stderr=log)
        try:
            time.sleep(0.5)
            assert server.poll() is None, "Owned HTTP3 fixture exited"
            for label, ca, peer in (("valid", "trusted", "localhost"), ("wrong-host", "trusted", "wrong.invalid"), ("wrong-ca", "unrelated", "localhost")):
                downloads = fixture / label
                downloads.mkdir()
                command = prefix + ["-E", "TDVP_HTTP3_TEST_CA_FILE=" + str(fixture / (ca + ".pem")), "-E", "TDVP_HTTP3_TEST_PEER_NAME=" + peer, str(examples / "gtlsclient"), "--quiet", "--handshake-timeout=5s", "--timeout=5s", "--exit-on-all-streams-close", "--download=" + str(downloads), "127.0.0.1", str(port), "https://localhost:" + str(port) + "/fixture.txt"]
                result = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=20)
                output = result.stdout + result.stderr
                files = [p for p in downloads.rglob("*") if p.is_file()]
                if label == "valid":
                    assert result.returncode == 0 and len(files) == 1 and files[0].read_bytes() == content, output[-3000:]
                    print("Certificate-verified target HTTP3 download: PASS", len(content), "bytes")
                else:
                    assert not files and ("ERR_CRYPTO" in output or "certificate" in output.lower()), (label, result.returncode, output[-3000:])
                    print("Target HTTP3", label, "certificate rejection: PASS; no content downloaded")
            missing = fixture / "missing-trust-inputs"
            missing.mkdir()
            result = subprocess.run(prefix + [str(examples / "gtlsclient"), "--quiet", "--handshake-timeout=5s", "--timeout=5s", "--exit-on-all-streams-close", "--download=" + str(missing), "127.0.0.1", str(port), "https://localhost:" + str(port) + "/fixture.txt"], env=environment, capture_output=True, text=True, timeout=20)
            assert result.returncode != 0 and not any(p.is_file() for p in missing.rglob("*")), (result.returncode, (result.stdout + result.stderr)[-3000:])
            print("Target HTTP3 missing explicit trust inputs: PASS fail closed")
        finally:
            if server.poll() is None:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait(timeout=5)
