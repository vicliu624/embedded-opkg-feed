#!/usr/bin/env python3
"""Compose an unsigned image-bound candidate from already verified IPKs.

Input signature verification, platform SDK validation and release promotion
remain separate gates. Existing input packages are never modified.
"""
import argparse
import gzip
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import tarfile
import tempfile

from image_backed_payload import plan_image_payload
from image_candidate_history import load_previous_candidate, projected_version, compare_versions

DEPENDENCY_FIELDS = ("Depends", "Pre-Depends", "Recommends", "Suggests")
NAME = r"[a-z0-9][a-z0-9+.-]*"
ATOM = re.compile(r"^\s*(" + NAME + r")(?:\s*\((=|>=|<=|>>|<<|>|<)\s*([^()\s]+)\))?\s*$")


def control_fields(text, allow_projected=False):
    fields, previous = {}, None
    for line in text.splitlines():
        if line.startswith((" ", "\t")) and previous:
            fields[previous] += "\n" + line
            continue
        if not line:
            continue
        if ": " not in line:
            raise ValueError("invalid control line")
        name, value = line.split(": ", 1)
        if name in fields:
            raise ValueError("duplicate control field: " + name)
        fields[name], previous = value, name
    if not re.fullmatch(NAME, fields.get("Package", "")):
        raise ValueError("invalid package name")
    if not re.fullmatch(r"[A-Za-z0-9.+:~_-]+", fields.get("Version", "")):
        raise ValueError("invalid package version")
    if fields.get("Architecture") != "riscv64":
        raise ValueError("image-bound packages must use riscv64")
    if "X-TDVP-Image-Manifest-SHA256" in fields and not allow_projected:
        raise ValueError("already projected package; use its original build input")
    return fields


def dependency_atoms(value):
    if not value:
        return []
    atoms = []
    for group in value.split(","):
        for alternative in group.split("|"):
            match = ATOM.fullmatch(alternative)
            if not match:
                raise ValueError("unsupported dependency expression: " + alternative)
            atoms.append(match.groups())
    return atoms


def extract_archive(data, destination):
    destination.mkdir()
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        members, paths = archive.getmembers(), set()
        for member in members:
            name = PurePosixPath(member.name)
            if name.is_absolute() or ".." in name.parts or str(name) in paths:
                raise ValueError("unsafe or duplicate tar path: " + member.name)
            paths.add(str(name))
            if not (member.isfile() or member.isdir() or member.issym()):
                raise ValueError("unsupported tar object: " + member.name)
        archive.extractall(destination, filter="data")
        # data_filter intentionally strips special/read-only modes. The files
        # are never executed here; restore metadata for exact inventory checks.
        for member in reversed(members):
            if member.isfile() or member.isdir():
                target = (destination / member.name).resolve()
                if not target.is_relative_to(destination.resolve()):
                    raise ValueError("archive file escapes extraction root")
                target.chmod(member.mode & 0o7777)


def archive_directory(root):
    raw = subprocess.check_output(["tar", "--format=gnu", "--sort=name", "--mtime=@0",
                                   "--owner=0", "--group=0", "--numeric-owner", "-C", str(root), "-cf", "-", "."])
    return gzip.compress(raw, compresslevel=9, mtime=0)


def rewrite_dependencies(value, packages, versions, image_packages):
    groups = []
    for group in value.split(",") if value else []:
        alternatives = []
        for alternative in group.split("|"):
            name, operator, version = ATOM.fullmatch(alternative).groups()
            if name in versions and operator:
                if operator != "=" or version != packages[name]["fields"]["Version"]:
                    raise ValueError("cannot rewrite non-matching dependency: " + alternative)
                version = versions[name]
            if name.startswith("tdvp-image-"):
                if name not in image_packages:
                    raise ValueError("unknown image dependency: " + name)
                locked = image_packages[name]["Version"]
                if operator and (operator != "=" or version != locked):
                    raise ValueError("image dependency differs from locked version: " + name)
                operator, version = "=", locked
            alternatives.append(name + (" (" + operator + " " + version + ")" if operator else ""))
        groups.append(" | ".join(alternatives))
    return ", ".join(groups)


def compose_image_backed_feed(source, image, manifest_digest, output, previous=None):
    source, image = Path(source).resolve(), Path(image).resolve()
    output = Path(output).parent.resolve() / Path(output).name
    if os.path.lexists(output):
        raise ValueError("refusing to overwrite candidate: " + str(output))
    if not output.parent.is_dir():
        raise ValueError("candidate parent directory must exist")
    if output.is_relative_to(source) or output.is_relative_to(image):
        raise ValueError("candidate must be outside input trees")
    history = load_previous_candidate(previous, control_fields)
    with tempfile.TemporaryDirectory(prefix="tdvp-image-compose-", dir=output.parent) as temporary:
        work = Path(temporary)
        candidate = work / "candidate"
        candidate.mkdir()
        packages = {}
        for number, ipk in enumerate(sorted(source.glob("*.ipk"))):
            staging = work / str(number)
            staging.mkdir()
            control_data = subprocess.check_output(["ar", "p", str(ipk), "control.tar.gz"])
            payload_data = subprocess.check_output(["ar", "p", str(ipk), "data.tar.gz"])
            extract_archive(control_data, staging / "control")
            extract_archive(payload_data, staging / "payload")
            fields = control_fields((staging / "control/control").read_text())
            name = fields["Package"]
            if name in packages:
                raise ValueError("multiple candidates for package: " + name)
            plan = plan_image_payload(staging / "payload", image, manifest_digest)
            atoms = [atom for key in DEPENDENCY_FIELDS for atom in dependency_atoms(fields.get(key, ""))]
            packages[name] = {"fields": fields, "plan": plan, "staging": staging, "source": ipk,
                              "sha256": hashlib.sha256(ipk.read_bytes()).hexdigest(),
                              "data": payload_data, "atoms": atoms}
        if not packages:
            raise ValueError("no input IPKs")
        if history.keys() - packages.keys():
            raise ValueError("previous packages missing from candidate: " + ", ".join(sorted(history.keys() - packages.keys())))
        image_packages = json.loads((image / "usr/share/tdvp/opkg/image-base.json").read_text())["installed_packages"]
        changed = {name for name, package in packages.items() if package["plan"]["image_files"]
                   or any(atom[0].startswith("tdvp-image-") for atom in package["atoms"])}
        while True:
            expanded = changed | {name for name, package in packages.items()
                                  if any(atom[0] in changed for atom in package["atoms"])}
            if expanded == changed:
                break
            changed = expanded
        versions, composition = {}, {}
        for name in sorted(changed):
            reachable, pending = set(), [name]
            while pending:
                dependency = pending.pop()
                if dependency in reachable or dependency not in packages:
                    continue
                reachable.add(dependency)
                pending.extend(atom[0] for atom in packages[dependency]["atoms"])
            identity = {"format": 3, "image": manifest_digest,
                        "inputs": {item: packages[item]["sha256"] for item in sorted(reachable)}}
            digest = hashlib.sha256(json.dumps(identity, sort_keys=True).encode()).hexdigest()
            version, revision, reused = projected_version(packages[name]["fields"]["Version"], digest, history.get(name))
            versions[name] = version
            composition[name] = (digest, revision, reused)
        report = {"schema": 1, "image_manifest_sha256": manifest_digest, "packages": {}}
        for name, package in sorted(packages.items()):
            fields, plan, staging = dict(package["fields"]), package["plan"], package["staging"]
            if name not in changed:
                old = history.get(name)
                if old and old['sha256'] != package['sha256'] and not compare_versions(fields['Version'], 'gt', old['fields']['Version']):
                    raise ValueError('changed raw package requires a higher version: ' + name)
                shutil.copyfile(package["source"], candidate / package["source"].name)
                report["packages"][name] = {"version": fields["Version"], "reused": True, "source_sha256": package["sha256"]}
                continue
            for key in ("Provides", "Replaces", "Conflicts", "Breaks"):
                if fields.get(key):
                    raise ValueError("relationship requires explicit migration review: " + name + " " + key)
            for key in DEPENDENCY_FIELDS:
                if fields.get(key):
                    fields[key] = rewrite_dependencies(fields[key], packages, versions, image_packages)
            fields["Version"] = versions[name]
            identity, revision, reuse_previous = composition[name]
            fields["X-TDVP-Source-Version"] = package["fields"]["Version"]
            fields["X-TDVP-Composition-Identity"] = identity
            fields["X-TDVP-Composition-Revision"] = str(revision)
            fields["X-TDVP-Image-Manifest-SHA256"] = manifest_digest
            fields["X-TDVP-Image-Plan-SHA256"] = hashlib.sha256(json.dumps(plan, sort_keys=True).encode()).hexdigest()
            if plan["image_files"]:
                # Only recognized generated cache hooks can be regenerated.
                # An arbitrary maintainer script may have payload side effects.
                hook_spec = importlib.util.spec_from_file_location("cache_hooks", Path(__file__).with_name("write-desktop-cache-hooks.py"))
                hooks = importlib.util.module_from_spec(hook_spec)
                hook_spec.loader.exec_module(hooks)
                expected = staging / "expected-hooks"
                expected.mkdir()
                hooks.write_hooks(staging / "payload", expected)
                for entry in (staging / "control").iterdir():
                    if entry.name == "control":
                        continue
                    if entry.name not in ("postinst", "postrm") or not (expected / entry.name).is_file() or entry.read_bytes() != (expected / entry.name).read_bytes():
                        raise ValueError("unsupported image-backed control member: " + name + "/" + entry.name)
                    entry.unlink()
                projected = staging / "projected"
                projected.mkdir()
                # Preserve directories, including intentional empty ones. They
                # may be shared by packages; file ownership remains exclusive.
                for directory, dirs, files in os.walk(staging / "payload", followlinks=False):
                    relative = Path(directory).relative_to(staging / "payload")
                    if not (image / relative).is_dir():
                        (projected / relative).mkdir(parents=True, exist_ok=True)
                for path in plan["new_files"]:
                    relative = path.lstrip("/")
                    target = projected / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(staging / "payload" / relative, target, follow_symlinks=False)
                for directory, dirs, files in os.walk(projected, topdown=False, followlinks=False):
                    relative = Path(directory).relative_to(projected)
                    Path(directory).chmod(stat.S_IMODE((staging / "payload" / relative).stat().st_mode))
                hooks.write_hooks(projected, staging / "control")
                package["data"] = archive_directory(projected)
                fields["Depends"] = ", ".join(filter(None, [fields.get("Depends", ""), *plan["depends"]]))
            control = "".join(key + ": " + value + "\n" for key, value in fields.items())
            (staging / "control/control").write_text(control, encoding="utf-8", newline="\n")
            (staging / "control.tar.gz").write_bytes(archive_directory(staging / "control"))
            (staging / "data.tar.gz").write_bytes(package["data"])
            (staging / "debian-binary").write_bytes(b"2.0\n")
            filename = name + "_" + fields["Version"] + "_riscv64.ipk"
            if reuse_previous:
                shutil.copyfile(history[name]['ipk'], candidate / filename)
            else:
                subprocess.run(["ar", "rD", str(candidate / filename), "debian-binary", "control.tar.gz", "data.tar.gz"],
                               cwd=staging, check=True, capture_output=True)
            report["packages"][name] = {"version": fields["Version"], "reused": False,
                                        "source_sha256": package["sha256"], "plan": plan}
        (candidate / "image-backed-report.json").write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
        subprocess.run(["bash", str(Path(__file__).with_name("make-index.sh")), str(candidate)], check=True)
        candidate.rename(output)
    return report


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True)
    parser.add_argument("--image-root", required=True)
    parser.add_argument("--image-manifest-sha256", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--previous", help="previous verified candidate, required after the first publication")
    args = parser.parse_args()
    try:
        result = compose_image_backed_feed(args.source, args.image_root, args.image_manifest_sha256, args.output, args.previous)
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        parser.exit(1, str(error) + "\n")
    print(json.dumps({"packages": len(result["packages"]),
                      "reused": sum(row["reused"] for row in result["packages"].values())}))
