"""Validate exact installed versions and run prepared target interface tests."""
import argparse
import os
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("validation_root", type=Path)
parser.add_argument("installed_root", type=Path)
parser.add_argument("feed", type=Path)
args = parser.parse_args()
base = args.validation_root.resolve(strict=True)
root = args.installed_root.resolve(strict=True)
feed = args.feed.resolve(strict=True)
versions = {
    "libdeflate": "1.26-1", "libsnappy": "1.3.1-1", "libmpfr": "4.2.2-1",
    "libmpc": "1.3.1-1", "libcap-ng": "0.9.6-1", "libattr": "2.6.0-1",
    "libacl": "2.4.0-1", "liburing": "2.15-1", "libaio": "0.3.113-1",
    "libssh2": "1.11.1-2", "libnghttp3": "1.18.0-1", "libngtcp2": "1.25.0-1",
}
candidate, installed = {}, {}
for file, target in ((feed / "Packages", candidate), (root / "var/lib/opkg/status", installed)):
    for block in file.read_text().split("\n\n"):
        fields = dict(line.split(": ", 1) for line in block.splitlines() if ": " in line and not line.startswith((" ", "\t")))
        if "Package" in fields and (target is candidate or fields.get("Status", "").endswith(" installed")):
            assert fields["Package"] not in target
            target[fields["Package"]] = fields["Version"]
for name, version in versions.items():
    delivered = candidate[name]
    assert delivered == version or delivered.startswith(version + "+tdvpimg."), (name, delivered, version)
    assert installed.get(name) == delivered, (name, installed.get(name), delivered)
for soname in ("libdeflate.so.0", "libsnappy.so.1", "libmpfr.so.6", "libmpc.so.3", "libcap-ng.so.0", "libattr.so.1", "libacl.so.1", "liburing.so.2", "liburing-ffi.so.2", "libaio.so.1", "libssh2.so.1", "libnghttp3.so.9", "libngtcp2.so.16", "libngtcp2_crypto_gnutls.so.8"):
    assert (root / "usr/lib" / soname).exists(), soname
executables = (
    "libdeflate-source-build.xKseqlli/libdeflate-runtime-smoke",
    "snappy-source-build.ZJrgG9dE/snappy-runtime-smoke",
    "mpfr-source-build.38KPrtiB/mpfr-runtime-smoke",
    "mpc-source-build.KDydARot/mpc-runtime-smoke",
    "capng-source-build.YopDCecF/cap-ng-runtime-smoke",
    "attr-acl-source-build.LbOE05fp/attr-acl-runtime-smoke",
    "liburing-source-build.RO0potwm/liburing-userspace-smoke",
    "libaio-source-build.Nuz9pPFO/libaio-userspace-smoke",
    "libssh2-reproducible.3qzNo3vv/first/libssh2-runtime-smoke",
    "http3-quic-source-build.n3BpdabI/http3-quic-runtime-smoke",
)
environment = dict(os.environ)
environment.pop("LD_LIBRARY_PATH", None)
environment.pop("QEMU_LD_PREFIX", None)
for relative in executables:
    executable = base / relative
    assert executable.is_file(), relative
    subprocess.run(["qemu-riscv64", "-L", str(root), "-E", "LD_LIBRARY_PATH=" + str(root / "usr/lib"), str(executable)], cwd=root, env=environment, check=True, timeout=120)
print("Installed second-pass common library interfaces: PASS 12 exact versions and 10 RISC-V test programs")
print("Kernel asynchronous I/O and real SSH/HTTP3 handshakes remain separate device/network gates")
