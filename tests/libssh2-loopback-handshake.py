"""Run a target SSH handshake against an owned, unauthenticated loopback fixture."""
import argparse
import base64
import hashlib
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("sdk", type=Path)
parser.add_argument("client", type=Path)
parser.add_argument("libraries", type=Path)
args = parser.parse_args()
sdk, client, libraries = (p.resolve(strict=True) for p in (args.sdk, args.client, args.libraries))
with tempfile.TemporaryDirectory(prefix="tdvp-ssh-handshake-") as temporary:
    root = Path(temporary)
    key = root / "hostkey"
    subprocess.run(["ssh-keygen", "-q", "-t", "ed25519", "-N", "", "-f", str(key)], check=True, timeout=15)
    digest = hashlib.sha256(base64.b64decode(key.with_suffix(".pub").read_text().split()[1], validate=True)).hexdigest()
    with socket.socket() as reservation:
        reservation.bind(("127.0.0.1", 0))
        port = reservation.getsockname()[1]
    config = root / "sshd_config"
    config.write_text(f"Port {port}\nListenAddress 127.0.0.1\nHostKey {key}\nPidFile {root / 'pid'}\nUsePAM no\nPermitRootLogin no\nPasswordAuthentication no\nKbdInteractiveAuthentication no\nAuthorizedKeysFile none\nAllowTcpForwarding no\nX11Forwarding no\nPermitTunnel no\n")
    subprocess.run(["/usr/sbin/sshd", "-t", "-f", str(config)], check=True, timeout=10)
    with (root / "server.log").open("w+") as log:
        server = subprocess.Popen(["/usr/sbin/sshd", "-D", "-e", "-f", str(config)], stdout=log, stderr=log)
        try:
            ready = False
            for attempt in range(50):
                if server.poll() is not None:
                    log.seek(0)
                    raise RuntimeError("Owned SSH fixture exited: " + log.read())
                try:
                    with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                        ready = True
                        break
                except OSError:
                    time.sleep(0.1)
            assert ready, "Owned SSH fixture did not listen within five seconds"
            environment = dict(os.environ)
            environment.pop("LD_LIBRARY_PATH", None)
            environment.pop("QEMU_LD_PREFIX", None)
            command = ["qemu-riscv64", "-L", str(sdk / "sysroot"), "-E", "LD_LIBRARY_PATH=" + str(libraries), str(client), str(port)]
            subprocess.run(command + [digest], env=environment, check=True, timeout=20)
            wrong = ("0" if digest[0] != "0" else "1") + digest[1:]
            mismatch = subprocess.run(command + [wrong], env=environment, timeout=20)
            assert mismatch.returncode == 7, ("Incorrect host key was not rejected", mismatch.returncode)
            print("Target libssh2 host-key mismatch rejection: PASS; no authentication attempted")
        finally:
            if server.poll() is None:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait(timeout=5)
