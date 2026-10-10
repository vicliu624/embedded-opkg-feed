"""Upgrade cJSON through actual image opkg in a copy of a previously installed candidate."""
import argparse
import hashlib
import io
import os
from pathlib import Path
import shutil
import subprocess
import tarfile

parser = argparse.ArgumentParser(description=__doc__)
for name in ("image", "old_root", "feed", "work", "signature", "keyring", "tests"):
    parser.add_argument(name, type=Path)
args = parser.parse_args()
image, previous, feed, signature, keyring, tests = (p.resolve(strict=True) for p in (args.image, args.old_root, args.feed, args.signature, args.keyring, args.tests))
work = args.work.resolve()
assert not work.exists() and not work.is_symlink()
assert not any((keyring / "private-keys-v1.d").glob("*"))
work.mkdir()
root = work / "root"
shutil.copytree(previous, root, symlinks=True)
shutil.copytree(keyring, root / "upgrade-fixture-keyring")
protected = {}
for relative in ("lib/libc.so.6", "usr/bin/opkg", "usr/bin/labwc", "usr/share/tdvp/opkg/image-base.json"):
    file = root / relative
    assert file.resolve().is_relative_to(root)
    protected[relative] = hashlib.file_digest(file.open("rb"), "sha256").hexdigest()
assert (root / "usr/lib/libcjson.so.1.7.18").is_file()
lists = root / "var/lib/opkg/lists"
assert lists.resolve().is_relative_to(root)
shutil.copy2(feed / "Packages", lists / "upgrade-fixture")
for suffix in (".asc", ".sig"):
    shutil.copy2(signature, lists / ("upgrade-fixture" + suffix))
config = work / "opkg.conf"
config.write_text("dest root /\noption lists_dir /var/lib/opkg/lists\noption info_dir /var/lib/opkg/info\noption status_file /var/lib/opkg/status\noption check_signature 1\noption signature_type gpg-asc\noption gpg_trust_level TrustAny\noption gpg_dir /upgrade-fixture-keyring\narch all 1\narch riscv64 100\nsrc upgrade-fixture " + feed.as_uri() + "\n")
for name in ("cache", "tmp"):
    (work / name).mkdir()
command = ["qemu-riscv64", "-L", str(image), str(image / "usr/bin/opkg"), "-f", str(config), "-o", str(root), "--cache-dir", str(work / "cache"), "--host-cache-dir", "-t", str(work / "tmp"), "install", "libcjson"]
environment = dict(os.environ, IPKG_INSTROOT=str(root), PKG_ROOT=str(root))
result = subprocess.run(command, env=environment, capture_output=True, text=True, timeout=120)
(work / "upgrade.log").write_text(result.stdout + result.stderr)
assert result.returncode == 0, (result.stdout + result.stderr)[-4000:]
ipk = next(feed.glob("libcjson_1.7.19-2_*.ipk"))
control = tarfile.open(fileobj=io.BytesIO(subprocess.check_output(["ar", "p", str(ipk), "control.tar.gz"])), mode="r:gz")
assert not any(Path(member.name).name in ("preinst", "postinst", "prerm", "postrm") for member in control.getmembers())
configuration = subprocess.run(command[:-2] + ["--force-postinstall", "configure", "libcjson"], env=environment, capture_output=True, text=True, timeout=60)
(work / "configure.log").write_text(configuration.stdout + configuration.stderr)
assert configuration.returncode == 0, configuration.stdout + configuration.stderr
blocks = (root / "var/lib/opkg/status").read_text().split("\n\n")
entry = next(block for block in blocks if block.startswith("Package: libcjson\n"))
assert "Version: 1.7.19-2\n" in entry and next(line for line in entry.splitlines() if line.startswith("Status: ")).endswith(" installed"), entry
for family in ("libcjson", "libcjson_utils"):
    assert not (root / "usr/lib" / (family + ".so.1.7.18")).exists()
    assert (root / "usr/lib" / (family + ".so.1.7.19")).is_file()
    assert (root / "usr/lib" / (family + ".so.1")).resolve() == (root / "usr/lib" / (family + ".so.1.7.19"))
for relative, digest in protected.items():
    assert hashlib.file_digest((root / relative).open("rb"), "sha256").hexdigest() == digest
for name in ("cjson-input-boundary-smoke", "cjson-atomic-wrapper-contract"):
    subprocess.run(["qemu-riscv64", "-L", str(root), "-E", "LD_LIBRARY_PATH=" + str(root / "usr/lib"), str(tests / name)], check=True, timeout=15)
print("Actual signed cJSON upgrade: PASS 1.7.18 to 1.7.19-2, old payload cleanup, public links, protected base and runtime regression")
