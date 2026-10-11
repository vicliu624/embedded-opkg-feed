"""Exercise real target opkg install/upgrade/remove in an isolated image copy.

Uses local IPKs and fixture-key-signed lists. Production-key repository
verification and real-device acceptance remain separate gates.
"""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("image", type=Path)
parser.add_argument("old_feed", type=Path)
parser.add_argument("new_feed", type=Path)
parser.add_argument("work", type=Path)
parser.add_argument("--signatures", type=Path, required=True)
parser.add_argument("--keyring", type=Path, required=True)
args = parser.parse_args()
image, old_feed, new_feed = (p.resolve(strict=True) for p in (args.image, args.old_feed, args.new_feed))
work = args.work.resolve()
assert not work.exists(), "transaction directory must be fresh"
work.mkdir(parents=True)
root = work / "root"
shutil.copytree(image, root, symlinks=True)
keyring = args.keyring.resolve(strict=True)
private_keys = keyring / "private-keys-v1.d"
assert not private_keys.exists() or not any(private_keys.iterdir()), "fixture verifier must receive public keys only"
offline_keyring = root / keyring.as_posix().lstrip("/")
assert offline_keyring.resolve().is_relative_to(root)
shutil.copytree(keyring, offline_keyring)
for relative in ("usr", "usr/bin", "usr/lib", "usr/share", "var/lib/opkg", "var/lib/opkg/info", "var/lib/opkg/lists"):
    target = root / relative
    assert target.resolve().is_relative_to(root), "offline write directory escapes fixture: " + relative
    target.mkdir(parents=True, exist_ok=True)
protected = {}
for relative in ("lib/libc.so.6", "usr/bin/opkg", "usr/bin/labwc", "usr/share/tdvp/opkg/image-base.json"):
    target = root / relative
    assert target.is_file() and target.resolve().is_relative_to(root), "missing protected base file: " + relative
    protected[relative] = hashlib.sha256(target.read_bytes()).hexdigest()
config = work / "opkg.conf"
command = ["qemu-riscv64", "-L", str(image), str(image / "usr/bin/opkg"), "-f", str(config),
           "-o", str(root), "--cache-dir", str(work / "cache"), "--host-cache-dir", "-t", str(work / "tmp")]
for directory in ("cache", "tmp"):
    (work / directory).mkdir()
phases = (("install-old", old_feed, ["install", "python3-onnxruntime"],
           {"libonnx": "1.17.0-1", "python3-onnx": "1.17.0-2", "python3-onnxruntime": "1.21.0-2"}),
          ("upgrade-new", new_feed, ["--combine", "upgrade", "python3-onnxruntime", "python3-onnx", "libonnx"],
           {"libonnx": "1.17.0-2", "python3-onnx": "1.17.0-3", "python3-onnxruntime": "1.21.0-3"}),
          ("remove-consumer", new_feed, ["remove", "python3-onnxruntime"],
           {"libonnx": "1.17.0-2", "python3-onnx": "1.17.0-3"}),
          ("reinstall-consumer", new_feed, ["install", "python3-onnxruntime"],
           {"libonnx": "1.17.0-2", "python3-onnx": "1.17.0-3", "python3-onnxruntime": "1.21.0-3"}))
for phase, feed, operation, expected in phases:
    config.write_text("dest root /\noption lists_dir /var/lib/opkg/lists\n"
                      "option info_dir /var/lib/opkg/info\noption status_file /var/lib/opkg/status\n"
                      "option check_signature 1\noption signature_type gpg-asc\noption gpg_trust_level TrustAny\n"
                      "option gpg_dir " + str(keyring) + "\n"
                      "arch all 1\narch riscv64 100\nsrc fixture " + feed.as_uri() + "\n")
    shutil.copyfile(feed / "Packages", root / "var/lib/opkg/lists/fixture")
    signature = args.signatures / ("old.asc" if feed == old_feed else "new.asc")
    assert signature.is_file()
    for suffix in (".sig", ".asc"):
        shutil.copyfile(signature, root / ("var/lib/opkg/lists/fixture" + suffix))
    if phase == "upgrade-new":
        before_status = (root / "var/lib/opkg/status").read_bytes()
        rejected = subprocess.run(command + ["install", "python3-onnxruntime"], capture_output=True, text=True, timeout=240)
        (work / "single-package-upgrade-rejection.log").write_text(rejected.stdout + rejected.stderr)
        assert rejected.returncode != 0 and "break existing dependencies" in rejected.stdout + rejected.stderr
        assert (root / "var/lib/opkg/status").read_bytes() == before_status, "rejected upgrade modified database"
    result = subprocess.run(command + operation, capture_output=True, text=True, timeout=240)
    (work / (phase + ".log")).write_text(result.stdout + result.stderr)
    assert result.returncode == 0, phase + ": " + result.stdout + result.stderr
    # Offline opkg deliberately defers configuration. Only configure after
    # proving every pending package has no maintainer scripts to execute.
    pending = []
    for block in (root / "var/lib/opkg/status").read_text().split("\n\n"):
        fields = dict(line.split(": ", 1) for line in block.splitlines() if ": " in line and not line.startswith((" ", "\t")))
        if fields.get("Status", "").endswith(" unpacked"):
            pending.append(fields["Package"])
    for name in pending:
        for script in ("preinst", "postinst", "prerm", "postrm"):
            assert not (root / ("var/lib/opkg/info/" + name + "." + script)).exists(), "unexpected pending maintainer script: " + name
    if pending:
        configuration_log = ""
        for name in pending:
            configured = subprocess.run(command + ["--force-postinstall", "configure", name], capture_output=True, text=True, timeout=240)
            configuration_log += configured.stdout + configured.stderr
            (work / (phase + "-configure.log")).write_text(configuration_log)
            assert configured.returncode == 0, configured.stdout + configured.stderr
    index_versions = {}
    for block in (feed / "Packages").read_text().split("\n\n"):
        fields = dict(line.split(": ", 1) for line in block.splitlines() if ": " in line and not line.startswith((" ", "\t")))
        if "Package" in fields:
            index_versions[fields["Package"]] = fields["Version"]
    installed = {}
    for block in (root / "var/lib/opkg/status").read_text().split("\n\n"):
        fields = dict(line.split(": ", 1) for line in block.splitlines() if ": " in line and not line.startswith((" ", "\t")))
        if fields.get("Status", "").endswith(" installed"):
            installed[fields["Package"]] = fields["Version"]
    for name, version in expected.items():
        exact = index_versions[name]
        assert exact == version or exact.startswith(version + "+tdvpimg."), (phase, name, exact, version)
        assert installed.get(name) == exact, (phase, name, installed.get(name), exact)
    if phase == "remove-consumer":
        assert "python3-onnxruntime" not in installed
        assert not (root / "usr/lib/python3.13/site-packages/onnxruntime/capi/onnxruntime_pybind11_state.so").exists()
    else:
        assert (root / "usr/lib/python3.13/site-packages/onnxruntime/capi/onnxruntime_pybind11_state.so").is_file()
    for relative, digest in protected.items():
        assert hashlib.sha256((root / relative).read_bytes()).hexdigest() == digest, "protected image file changed: " + relative
    print("Actual target opkg transaction: PASS", phase, flush=True)
print("ONNX install/upgrade/remove/reinstall: PASS versions, actual payload and protected image files")
